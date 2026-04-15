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
         signer <- Joken.Signer.create("ES256", %{"pem" => verification_key}),
         {:ok, claims} <- Joken.verify(token, signer),
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

  defp validate_issuer(%{"iss" => "privy.io"}), do: :ok
  defp validate_issuer(_claims), do: {:error, :invalid_claims}

  defp validate_audience(%{"aud" => audience}, app_id) when is_binary(audience) do
    if audience == app_id, do: :ok, else: {:error, :invalid_claims}
  end

  defp validate_audience(%{"aud" => audiences}, app_id) when is_list(audiences) do
    if app_id in audiences, do: :ok, else: {:error, :invalid_claims}
  end

  defp validate_audience(_claims, _app_id), do: {:error, :invalid_claims}

  defp validate_time_claims(claims) do
    now = System.system_time(:second)

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
      _ -> {:error, :invalid_claims}
    end
  end

  defp validate_issued_at(claims, now) do
    case Map.fetch(claims, "iat") do
      :error -> :ok
      {:ok, iat} when is_integer(iat) and iat <= now + 60 -> :ok
      _ -> {:error, :invalid_claims}
    end
  end

  defp fetch_integer_claim(claims, claim_name) do
    case Map.fetch(claims, claim_name) do
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, :invalid_claims}
    end
  end

  defp ensure_future(exp, now) when exp > now, do: :ok
  defp ensure_future(_exp, _now), do: {:error, :invalid_claims}

  defp fetch_subject(%{"sub" => privy_user_id})
       when is_binary(privy_user_id) and privy_user_id != "" do
    {:ok, privy_user_id}
  end

  defp fetch_subject(_claims), do: {:error, :invalid_claims}

  defp fetch_wallet_addresses(%{"linked_accounts" => linked_accounts})
       when is_binary(linked_accounts) do
    with {:ok, decoded} <- Jason.decode(linked_accounts),
         true <- is_list(decoded) do
      {:ok,
       decoded
       |> Enum.flat_map(&linked_account_addresses/1)
       |> Enum.uniq()}
    else
      _ -> {:error, :invalid_claims}
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
