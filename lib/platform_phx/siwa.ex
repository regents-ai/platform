defmodule PlatformPhx.Siwa do
  @moduledoc false

  alias PlatformPhx.Ethereum
  alias PlatformPhx.RuntimeConfig

  @nonce_table :platform_siwa_nonces
  @replay_table :platform_siwa_replays
  @address_regex ~r/^0x[a-fA-F0-9]{40}$/
  @positive_int_regex ~r/^[1-9][0-9]*$/
  @signature_input_regex ~r/^sig1=\((?<components>.+)\)(?<params>(?:;.+)*)$/
  @signature_regex ~r/^sig1=:(?<payload>[A-Za-z0-9+\/=]+):$/
  @content_digest_regex ~r/^sha-256=:(?<payload>[A-Za-z0-9+\/=]+):$/
  @required_headers ~w(
    x-siwa-receipt
    signature
    signature-input
    x-key-id
    x-timestamp
    x-agent-wallet-address
    x-agent-chain-id
  )
  @base_components ~w(
    @method
    @path
    x-siwa-receipt
    x-key-id
    x-timestamp
    x-agent-wallet-address
    x-agent-chain-id
  )

  def issue_nonce(params) when is_map(params) do
    with {:ok, wallet_address} <- required_address(params, "wallet_address"),
         {:ok, chain_id} <- required_positive_integer(params, "chain_id"),
         {:ok, registry_address} <- required_address(params, "registry_address"),
         {:ok, token_id} <- required_positive_integer(params, "token_id"),
         {:ok, audience} <- required_string(params, "audience") do
      nonce = "siwa-" <> Ecto.UUID.generate()
      expires_at_unix = now_unix_seconds() + nonce_ttl_seconds()

      ensure_tables!()

      :ets.insert(@nonce_table, {
        {wallet_address, chain_id, nonce},
        %{
          audience: audience,
          registry_address: registry_address,
          token_id: Integer.to_string(token_id),
          expires_at_unix: expires_at_unix,
          consumed_at_unix: nil
        }
      })

      {:ok,
       %{
         "ok" => true,
         "code" => "nonce_issued",
         "data" => %{
           "nonce" => nonce,
           "walletAddress" => wallet_address,
           "chainId" => chain_id,
           "registryAddress" => registry_address,
           "tokenId" => Integer.to_string(token_id),
           "audience" => audience,
           "expiresAt" => unix_to_iso8601(expires_at_unix)
         }
       }}
    else
      {:error, {code, message}} -> {:error, {400, code, message}}
    end
  end

  def verify_session(params) when is_map(params) do
    with {:ok, wallet_address} <- required_address(params, "wallet_address"),
         {:ok, chain_id} <- required_positive_integer(params, "chain_id"),
         {:ok, registry_address} <- required_address(params, "registry_address"),
         {:ok, token_id} <- required_positive_integer(params, "token_id"),
         {:ok, nonce} <- required_string(params, "nonce"),
         {:ok, message} <- required_string(params, "message"),
         {:ok, signature} <- required_string(params, "signature"),
         :ok <- validate_siwa_message(message, wallet_address, chain_id, nonce),
         :ok <- verify_wallet_signature(wallet_address, message, signature),
         {:ok, nonce_record} <- consume_nonce(wallet_address, chain_id, nonce),
         :ok <- ensure_nonce_identity(nonce_record, registry_address, token_id) do
      key_id = wallet_address
      issued_at_unix = now_unix_seconds()
      receipt_expires_at_unix = now_unix_seconds() + receipt_ttl_seconds()

      claims =
        %{
          "typ" => "siwa_receipt",
          "jti" => Ecto.UUID.generate(),
          "sub" => wallet_address,
          "aud" => nonce_record.audience,
          "iat" => issued_at_unix,
          "exp" => receipt_expires_at_unix,
          "chain_id" => chain_id,
          "nonce" => nonce,
          "key_id" => key_id,
          "registry_address" => nonce_record.registry_address,
          "token_id" => nonce_record.token_id
        }

      receipt = issue_receipt(claims)

      {:ok,
       %{
         "ok" => true,
         "code" => "siwa_verified",
         "data" => %{
           "verified" => true,
           "walletAddress" => wallet_address,
           "chainId" => chain_id,
           "registryAddress" => nonce_record.registry_address,
           "tokenId" => nonce_record.token_id,
           "audience" => nonce_record.audience,
           "nonce" => nonce,
           "keyId" => key_id,
           "signatureScheme" => "evm_personal_sign",
           "receipt" => receipt,
           "receiptIssuedAt" => unix_to_iso8601(issued_at_unix),
           "receiptExpiresAt" => unix_to_iso8601(receipt_expires_at_unix)
         }
       }}
    else
      {:error, {status, code, message}} -> {:error, {status, code, message}}
    end
  end

  def verify_http_request(params, opts \\ []) when is_map(params) do
    with {:ok, method} <- required_string(params, "method"),
         {:ok, request_path} <- required_path(params, "path"),
         {:ok, request_body} <- optional_body(params, "body"),
         {:ok, normalized_headers} <- required_header_map(params, "headers"),
         body_digest = request_body_digest(request_body),
         :ok <- ensure_required_headers(normalized_headers, body_digest),
         {:ok, parsed_signature_input} <-
           parse_signature_input(Map.fetch!(normalized_headers, "signature-input")),
         :ok <- ensure_signature_window(parsed_signature_input, normalized_headers),
         :ok <-
           ensure_required_components(
             parsed_signature_input.components,
             normalized_headers,
             body_digest
           ),
         {:ok, receipt_claims} <-
           verify_receipt(Map.fetch!(normalized_headers, "x-siwa-receipt"), opts),
         :ok <- ensure_body_binding(normalized_headers, body_digest),
         :ok <- ensure_header_binding(normalized_headers, receipt_claims),
         :ok <-
           ensure_replay_fresh(
             receipt_claims["sub"],
             parsed_signature_input.nonce,
             method,
             request_path,
             body_digest,
             parsed_signature_input.expires
           ),
         {:ok, signature} <- decode_signature(Map.fetch!(normalized_headers, "signature")),
         signing_message <-
           build_http_signing_message(
             method,
             request_path,
             normalized_headers,
             parsed_signature_input
           ),
         :ok <- verify_wallet_signature(receipt_claims["sub"], signing_message, signature) do
      {:ok,
       %{
         "ok" => true,
         "code" => "http_envelope_valid",
         "data" => %{
           "verified" => true,
           "walletAddress" => receipt_claims["sub"],
           "chainId" => receipt_claims["chain_id"],
           "keyId" => receipt_claims["key_id"],
           "agent_claims" => verified_agent_claims(receipt_claims),
           "receiptExpiresAt" => unix_to_iso8601(receipt_claims["exp"]),
           "requiredHeaders" => required_headers(body_digest),
           "requiredCoveredComponents" =>
             required_components_for_headers(normalized_headers, body_digest),
           "coveredComponents" => parsed_signature_input.components
         }
       }}
    else
      {:error, {status, code, message}} -> {:error, {status, code, message}}
    end
  end

  def current_agent_claims(%{"sub" => _sub, "chain_id" => _chain_id} = receipt_claims) do
    {:ok, verified_agent_claims(receipt_claims)}
  end

  def current_agent_claims(_claims),
    do: {:error, {401, "receipt_invalid", "invalid SIWA receipt"}}

  def content_digest_for_body(body) when is_binary(body) do
    digest =
      :crypto.hash(:sha256, body)
      |> Base.encode64()

    "sha-256=:#{digest}:"
  end

  def content_digest_for_body(_body), do: nil

  defp validate_siwa_message(message, wallet_address, chain_id, nonce) do
    normalized_message = String.trim(message)

    cond do
      not String.contains?(
        normalized_message,
        "regent.cx wants you to sign in with your Ethereum account:\n#{wallet_address}"
      ) ->
        {:error, {401, "signature_invalid", "message wallet address does not match request"}}

      not String.contains?(normalized_message, "\nChain ID: #{chain_id}\n") ->
        {:error, {401, "signature_invalid", "message chain id does not match request"}}

      not String.contains?(normalized_message, "\nNonce: #{nonce}\n") ->
        {:error, {401, "signature_invalid", "message nonce does not match request"}}

      true ->
        :ok
    end
  end

  defp verify_wallet_signature(wallet_address, message, signature) do
    case Ethereum.verify_signature(wallet_address, message, signature) do
      :ok -> :ok
      {:error, _reason} -> {:error, {401, "signature_invalid", "signature does not match wallet"}}
    end
  end

  defp consume_nonce(wallet_address, chain_id, nonce) do
    ensure_tables!()

    case :ets.lookup(@nonce_table, {wallet_address, chain_id, nonce}) do
      [] ->
        {:error, {404, "nonce_not_found", "nonce not found"}}

      [{_key, %{expires_at_unix: expires_at_unix} = record}] ->
        cond do
          expires_at_unix <= now_unix_seconds() ->
            {:error, {401, "nonce_expired", "nonce expired"}}

          is_integer(record.consumed_at_unix) ->
            {:error, {401, "nonce_already_used", "nonce already used"}}

          true ->
            consumed = Map.put(record, :consumed_at_unix, now_unix_seconds())
            :ets.insert(@nonce_table, {{wallet_address, chain_id, nonce}, consumed})
            {:ok, record}
        end
    end
  end

  defp ensure_required_headers(headers, body_digest) do
    missing =
      required_headers(body_digest)
      |> Enum.reject(&Map.has_key?(headers, &1))

    if missing == [] do
      :ok
    else
      {:error, {401, "http_headers_missing", "missing required signed agent headers"}}
    end
  end

  defp ensure_nonce_identity(nonce_record, registry_address, token_id) do
    cond do
      nonce_record.registry_address != registry_address ->
        {:error,
         {401, "nonce_identity_mismatch", "registry_address does not match the issued nonce"}}

      nonce_record.token_id != Integer.to_string(token_id) ->
        {:error, {401, "nonce_identity_mismatch", "token_id does not match the issued nonce"}}

      true ->
        :ok
    end
  end

  defp parse_signature_input(signature_input) when is_binary(signature_input) do
    with %{"components" => components_blob, "params" => params_blob} <-
           Regex.named_captures(@signature_input_regex, String.trim(signature_input)),
         {:ok, components} <- parse_components(components_blob),
         {:ok, params} <- parse_signature_params(params_blob) do
      {:ok,
       %{
         components: components,
         created: params.created,
         expires: params.expires,
         nonce: params.nonce,
         key_id: params.key_id,
         signature_params:
           "(#{Enum.map_join(components, " ", &~s("#{&1}"))})" <>
             ";created=#{params.created}" <>
             ";expires=#{params.expires}" <>
             ~s(;nonce="#{params.nonce}") <>
             if(params.key_id, do: ~s(;keyid="#{params.key_id}"), else: "")
       }}
    else
      _ -> {:error, {401, "http_signature_input_invalid", "invalid signature-input header"}}
    end
  end

  defp parse_signature_input(_value),
    do: {:error, {401, "http_signature_input_invalid", "invalid signature-input header"}}

  defp parse_components(blob) when is_binary(blob) do
    components =
      blob
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&String.trim(&1, "\""))

    if components == [] do
      {:error, :invalid}
    else
      {:ok, components}
    end
  end

  defp parse_signature_params(blob) do
    entries =
      blob
      |> String.split(";", trim: true)
      |> Enum.reduce(%{}, fn entry, acc ->
        case String.split(entry, "=", parts: 2) do
          [key, value] -> Map.put(acc, key, String.trim(value, "\""))
          _ -> acc
        end
      end)

    with {:ok, created} <- parse_positive_integer(entries["created"]),
         {:ok, expires} <- parse_positive_integer(entries["expires"]),
         {:ok, nonce} <- required_value(entries["nonce"]),
         true <- expires > created do
      {:ok,
       %{
         created: created,
         expires: expires,
         nonce: nonce,
         key_id: normalize_optional_text(entries["keyid"])
       }}
    else
      _ -> {:error, :invalid}
    end
  end

  defp ensure_required_components(components, headers, body_digest) do
    required = required_components_for_headers(headers, body_digest)
    missing = Enum.reject(required, &(&1 in components))

    if missing == [] do
      :ok
    else
      {:error, {401, "http_required_components_missing", "missing required covered components"}}
    end
  end

  defp required_components_for_headers(headers, body_digest) do
    @base_components
    |> maybe_append_content_digest(body_digest)
    |> maybe_append_component(headers, "x-agent-registry-address")
    |> maybe_append_component(headers, "x-agent-token-id")
  end

  defp required_headers(body_digest) do
    if is_binary(body_digest),
      do: @required_headers ++ ["content-digest"],
      else: @required_headers
  end

  defp maybe_append_content_digest(components, body_digest) do
    if is_binary(body_digest), do: components ++ ["content-digest"], else: components
  end

  defp maybe_append_component(components, headers, header_name) do
    if Map.has_key?(headers, header_name), do: components ++ [header_name], else: components
  end

  defp ensure_signature_window(parsed_signature_input, headers) do
    now = now_unix_seconds()
    tolerance = RuntimeConfig.siwa_http_signature_tolerance_seconds()

    case required_positive_integer(headers, "x-timestamp") do
      {:ok, header_timestamp} ->
        cond do
          header_timestamp != parsed_signature_input.created ->
            {:error, {401, "http_signature_invalid", "invalid x-timestamp header"}}

          parsed_signature_input.created > now + tolerance ->
            {:error, {401, "http_signature_invalid", "signed request is not yet valid"}}

          parsed_signature_input.created < now - tolerance ->
            {:error, {401, "http_signature_invalid", "signed request is too old"}}

          parsed_signature_input.expires < now ->
            {:error, {401, "http_signature_invalid", "signed request has expired"}}

          true ->
            :ok
        end

      {:error, _reason} ->
        {:error, {401, "http_signature_invalid", "invalid x-timestamp header"}}
    end
  end

  defp verify_receipt(receipt, opts) when is_binary(receipt) do
    with [header_segment, payload_segment, signature_segment] <-
           String.split(receipt, ".", parts: 3),
         true <- signature_segment == sign_token("#{header_segment}.#{payload_segment}"),
         {:ok, claims} <- decode_claims(payload_segment),
         true <- claims["typ"] == "siwa_receipt",
         true <- claims["exp"] > now_unix_seconds(),
         :ok <- ensure_audience(claims, opts) do
      {:ok, claims}
    else
      _ -> {:error, {401, "receipt_invalid", "invalid SIWA receipt"}}
    end
  end

  defp verify_receipt(_value, _opts),
    do: {:error, {401, "receipt_invalid", "invalid SIWA receipt"}}

  defp ensure_audience(claims, opts) do
    case Keyword.get(opts, :audience) do
      nil ->
        :ok

      expected ->
        if claims["aud"] == expected do
          :ok
        else
          {:error, {401, "receipt_binding_mismatch", "receipt audience does not match this app"}}
        end
    end
  end

  defp ensure_header_binding(headers, claims) do
    cond do
      Map.get(headers, "x-key-id") != claims["key_id"] ->
        {:error, {401, "receipt_binding_mismatch", "x-key-id does not match SIWA receipt"}}

      Map.get(headers, "x-agent-wallet-address") != claims["sub"] ->
        {:error,
         {401, "receipt_binding_mismatch", "x-agent-wallet-address does not match SIWA receipt"}}

      parse_positive_integer!(Map.get(headers, "x-agent-chain-id")) != claims["chain_id"] ->
        {:error,
         {401, "receipt_binding_mismatch", "x-agent-chain-id does not match SIWA receipt"}}

      claims["registry_address"] &&
          Map.get(headers, "x-agent-registry-address") != claims["registry_address"] ->
        {:error,
         {401, "receipt_binding_mismatch", "x-agent-registry-address does not match SIWA receipt"}}

      Map.has_key?(headers, "x-agent-registry-address") && is_nil(claims["registry_address"]) ->
        {:error,
         {401, "receipt_binding_mismatch",
          "x-agent-registry-address is not verified in the SIWA receipt"}}

      claims["token_id"] && Map.get(headers, "x-agent-token-id") != claims["token_id"] ->
        {:error,
         {401, "receipt_binding_mismatch", "x-agent-token-id does not match SIWA receipt"}}

      Map.has_key?(headers, "x-agent-token-id") && is_nil(claims["token_id"]) ->
        {:error,
         {401, "receipt_binding_mismatch", "x-agent-token-id is not verified in the SIWA receipt"}}

      true ->
        :ok
    end
  end

  defp ensure_body_binding(headers, nil) do
    if Map.has_key?(headers, "content-digest") do
      {:error,
       {401, "http_body_binding_missing",
        "request body is required when content-digest is present"}}
    else
      :ok
    end
  end

  defp ensure_body_binding(headers, body_digest) do
    with content_digest when is_binary(content_digest) <- Map.get(headers, "content-digest"),
         true <- content_digest == body_digest,
         %{"payload" => payload} <- Regex.named_captures(@content_digest_regex, content_digest),
         {:ok, _decoded} <- Base.decode64(payload) do
      :ok
    else
      nil ->
        {:error, {401, "http_body_binding_missing", "missing content-digest header"}}

      false ->
        {:error,
         {401, "http_body_binding_invalid", "content-digest does not match the request body"}}

      _ ->
        {:error, {401, "http_body_binding_invalid", "content-digest is invalid"}}
    end
  end

  defp ensure_replay_fresh(
         wallet_address,
         nonce,
         method,
         request_path,
         body_digest,
         expires_at_unix
       ) do
    ensure_tables!()

    replay_key =
      "#{wallet_address}|#{nonce}|#{String.upcase(method)}|#{request_path}|#{body_digest || ""}"

    now = now_unix_seconds()
    replay_expires_at_unix = max(now, expires_at_unix)

    case :ets.lookup(@replay_table, replay_key) do
      [{^replay_key, expires_at_unix}] ->
        if expires_at_unix > now do
          {:error, {409, "request_replayed", "request replay detected"}}
        else
          :ets.insert(@replay_table, {replay_key, replay_expires_at_unix})
          :ok
        end

      _ ->
        :ets.insert(@replay_table, {replay_key, replay_expires_at_unix})
        :ok
    end
  end

  defp decode_signature(signature_header) when is_binary(signature_header) do
    with %{"payload" => payload} <-
           Regex.named_captures(@signature_regex, String.trim(signature_header)),
         {:ok, bytes} <- Base.decode64(payload) do
      case bytes do
        <<_::binary-size(65)>> ->
          {:ok, "0x" <> Base.encode16(bytes, case: :lower)}

        printable ->
          if String.printable?(printable) do
            {:ok, printable}
          else
            {:error, {401, "http_signature_invalid", "invalid signature header"}}
          end
      end
    else
      _ -> {:error, {401, "http_signature_invalid", "invalid signature header"}}
    end
  end

  defp decode_signature(_value),
    do: {:error, {401, "http_signature_invalid", "invalid signature header"}}

  defp build_http_signing_message(method, request_path, headers, parsed_signature_input) do
    parsed_signature_input.components
    |> Enum.map(fn component ->
      value =
        case component do
          "@method" -> String.downcase(method)
          "@path" -> request_path
          header_name -> Map.get(headers, header_name, "")
        end

      ~s("#{component}": #{value})
    end)
    |> Kernel.++([~s("@signature-params": #{parsed_signature_input.signature_params})])
    |> Enum.join("\n")
  end

  defp issue_receipt(claims) do
    header = base64url(%{"alg" => "HS256", "typ" => "JWT"})
    payload = base64url(claims)
    signature = sign_token("#{header}.#{payload}")
    "#{header}.#{payload}.#{signature}"
  end

  defp sign_token(signing_input) do
    :crypto.mac(:hmac, :sha256, receipt_secret(), signing_input)
    |> Base.url_encode64(padding: false)
  end

  defp decode_claims(payload_segment) do
    case Base.url_decode64(payload_segment, padding: false) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, %{} = claims} -> {:ok, claims}
          _ -> {:error, :invalid}
        end

      :error ->
        {:error, :invalid}
    end
  end

  defp base64url(map), do: map |> Jason.encode!() |> Base.url_encode64(padding: false)

  defp required_address(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        normalized = String.downcase(String.trim(value))

        if Regex.match?(@address_regex, normalized),
          do: {:ok, normalized},
          else: {:error, {"invalid_#{key}", "#{key} must be a valid address"}}

      _ ->
        {:error, {"missing_#{key}", "#{key} is required"}}
    end
  end

  defp required_positive_integer(params, key) do
    case parse_positive_integer(Map.get(params, key)) do
      {:ok, value} -> {:ok, value}
      {:error, _reason} -> {:error, {"invalid_#{key}", "#{key} must be a positive integer"}}
    end
  end

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_integer(value) when is_binary(value) do
    if Regex.match?(@positive_int_regex, String.trim(value)) do
      {:ok, String.to_integer(String.trim(value))}
    else
      {:error, :invalid}
    end
  end

  defp parse_positive_integer(_value), do: {:error, :invalid}
  defp parse_positive_integer!(value), do: value |> parse_positive_integer() |> elem(1)

  defp required_string(params, key) do
    case normalize_optional_text(Map.get(params, key)) do
      nil -> {:error, {"missing_#{key}", "#{key} is required"}}
      value -> {:ok, value}
    end
  end

  defp optional_body(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, nil}
      body when is_binary(body) -> {:ok, body}
      _value -> {:error, {"invalid_#{key}", "#{key} must be a string when present"}}
    end
  end

  defp required_path(params, key) do
    with {:ok, value} <- required_string(params, key),
         true <- String.starts_with?(value, "/") do
      {:ok, value}
    else
      _ -> {:error, {"invalid_#{key}", "#{key} must be an absolute path"}}
    end
  end

  defp required_header_map(params, key) do
    case Map.get(params, key) do
      headers when is_map(headers) ->
        normalized =
          headers
          |> Enum.reduce(%{}, fn
            {name, value}, acc when is_binary(name) and is_binary(value) ->
              Map.put(acc, String.downcase(name), String.trim(value))

            _entry, acc ->
              acc
          end)

        {:ok, normalized}

      _ ->
        {:error, {"invalid_#{key}", "#{key} must be an object of string headers"}}
    end
  end

  defp required_value(nil), do: {:error, :missing}
  defp required_value(""), do: {:error, :missing}
  defp required_value(value), do: {:ok, value}

  defp normalize_optional_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_optional_text(_value), do: nil

  defp request_body_digest(nil), do: nil
  defp request_body_digest(body) when is_binary(body), do: content_digest_for_body(body)

  defp verified_agent_claims(receipt_claims) do
    %{
      "wallet_address" => receipt_claims["sub"],
      "chain_id" => receipt_claims["chain_id"],
      "registry_address" => receipt_claims["registry_address"],
      "token_id" => receipt_claims["token_id"]
    }
  end

  defp ensure_tables! do
    if :ets.whereis(@nonce_table) == :undefined do
      :ets.new(@nonce_table, [:named_table, :public, :set])
    end

    if :ets.whereis(@replay_table) == :undefined do
      :ets.new(@replay_table, [:named_table, :public, :set])
    end
  end

  defp receipt_secret do
    :platform_phx
    |> Application.get_env(:siwa, [])
    |> Keyword.get(:receipt_secret, "platform-siwa-test-secret")
  end

  defp nonce_ttl_seconds do
    :platform_phx
    |> Application.get_env(:siwa, [])
    |> Keyword.get(:nonce_ttl_seconds, 300)
  end

  defp receipt_ttl_seconds do
    :platform_phx
    |> Application.get_env(:siwa, [])
    |> Keyword.get(:receipt_ttl_seconds, 3_600)
  end

  defp now_unix_seconds, do: System.os_time(:second)

  defp unix_to_iso8601(unix_seconds),
    do: unix_seconds |> DateTime.from_unix!() |> DateTime.to_iso8601()
end
