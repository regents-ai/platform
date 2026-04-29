defmodule PlatformPhx.Privy do
  @moduledoc false

  alias PlatformPhx.RuntimeConfig
  @wallet_address_pattern ~r/\A0x[0-9a-fA-F]{40}\z/u

  @spec verify_token(String.t()) ::
          {:ok,
           %{
             claims: map(),
             privy_user_id: String.t(),
             wallet_address: String.t() | nil,
             wallet_addresses: [String.t()]
           }}
          | {:error, term()}
  def verify_token(token) when is_binary(token) do
    with {:ok, app_id, verification_key} <- fetch_config(),
         {:ok, claims} <- verify_claims(token, verification_key),
         :ok <- validate_issuer(claims),
         :ok <- validate_audience(claims, app_id),
         :ok <- validate_time_claims(claims),
         {:ok, privy_user_id} <- fetch_subject(claims),
         {:ok, wallet_addresses} <- fetch_wallet_addresses(claims) do
      {:ok,
       %{
         claims: claims,
         privy_user_id: privy_user_id,
         wallet_address: List.first(wallet_addresses),
         wallet_addresses: wallet_addresses
       }}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_token}
    end
  rescue
    _ -> {:error, :invalid_token}
  end

  def describe_verify_error(:missing_privy_config),
    do: "Privy settings are missing from this environment."

  def describe_verify_error(:invalid_verification_key),
    do: "The Privy verification key could not be used."

  def describe_verify_error(:token_verification_failed),
    do: "The Privy identity token could not be verified."

  def describe_verify_error(:invalid_issuer),
    do: "The Privy identity token issuer was not accepted."

  def describe_verify_error(:invalid_audience),
    do: "The Privy identity token was issued for a different Privy app."

  def describe_verify_error(:token_expired),
    do: "The Privy identity token has expired."

  def describe_verify_error(:token_not_yet_valid),
    do: "The Privy identity token is not valid yet."

  def describe_verify_error(:token_issued_in_future),
    do: "The Privy identity token issue time is in the future."

  def describe_verify_error(:invalid_subject),
    do: "The Privy identity token did not include a valid person identifier."

  def describe_verify_error(:invalid_linked_accounts),
    do: "The Privy identity token linked wallet data was invalid."

  def describe_verify_error(:invalid_token),
    do: "The Privy identity token was malformed or unreadable."

  def describe_verify_error(reason),
    do: "Unexpected Privy verification failure: #{inspect(reason)}"

  def fetch_config do
    app_id = RuntimeConfig.privy_app_id()
    verification_key = RuntimeConfig.privy_verification_key()

    if is_binary(app_id) and app_id != "" and is_binary(verification_key) and
         verification_key != "" do
      {:ok, app_id, verification_key}
    else
      {:error, :missing_privy_config}
    end
  end

  defp verify_claims(token, verification_key) do
    signer = Joken.Signer.create("ES256", %{"pem" => verification_key})

    case Joken.verify(token, signer) do
      {:ok, claims} when is_map(claims) -> {:ok, claims}
      {:error, _reason} -> {:error, :token_verification_failed}
      _ -> {:error, :invalid_token}
    end
  rescue
    _ -> {:error, :invalid_verification_key}
  end

  defp validate_issuer(%{"iss" => "privy.io"}), do: :ok
  defp validate_issuer(_claims), do: {:error, :invalid_issuer}

  defp validate_audience(%{"aud" => audience}, app_id) when is_binary(audience) do
    if audience == app_id, do: :ok, else: {:error, :invalid_audience}
  end

  defp validate_audience(%{"aud" => audiences}, app_id) when is_list(audiences) do
    if app_id in audiences, do: :ok, else: {:error, :invalid_audience}
  end

  defp validate_audience(_claims, _app_id), do: {:error, :invalid_audience}

  defp validate_time_claims(claims) do
    now = PlatformPhx.Clock.unix_seconds()

    with {:ok, exp} <- fetch_integer_claim(claims, "exp"),
         :ok <- ensure_future(exp, now),
         :ok <- validate_not_before(claims, now),
         :ok <- validate_issued_at(claims, now) do
      :ok
    end
  end

  defp validate_not_before(claims, now) do
    case Map.fetch(claims, "nbf") do
      :error -> :ok
      {:ok, nbf} when is_integer(nbf) and nbf <= now -> :ok
      _ -> {:error, :token_not_yet_valid}
    end
  end

  defp validate_issued_at(claims, now) do
    case Map.fetch(claims, "iat") do
      :error -> :ok
      {:ok, iat} when is_integer(iat) and iat <= now + 60 -> :ok
      _ -> {:error, :token_issued_in_future}
    end
  end

  defp fetch_integer_claim(claims, claim_name) do
    case Map.fetch(claims, claim_name) do
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, :invalid_token}
    end
  end

  defp ensure_future(exp, now) when exp > now, do: :ok
  defp ensure_future(_exp, _now), do: {:error, :token_expired}

  defp fetch_subject(%{"sub" => privy_user_id})
       when is_binary(privy_user_id) and privy_user_id != "" do
    {:ok, privy_user_id}
  end

  defp fetch_subject(_claims), do: {:error, :invalid_subject}

  defp fetch_wallet_addresses(%{"linked_accounts" => linked_accounts})
       when is_binary(linked_accounts) do
    with {:ok, decoded} <- Jason.decode(linked_accounts),
         true <- is_list(decoded) do
      {:ok,
       decoded
       |> Enum.flat_map(&linked_account_addresses/1)
       |> Enum.uniq()}
    else
      _ -> {:error, :invalid_linked_accounts}
    end
  end

  defp fetch_wallet_addresses(_claims), do: {:ok, []}

  defp linked_account_addresses(%{"address" => address}) when is_binary(address) do
    case normalize_wallet_address(address) do
      nil -> []
      normalized -> [normalized]
    end
  end

  defp linked_account_addresses(_linked_account), do: []

  defp normalize_wallet_address(value) when is_binary(value) do
    trimmed = String.trim(value)

    if String.match?(trimmed, @wallet_address_pattern) do
      String.downcase(trimmed)
    else
      nil
    end
  end
end
