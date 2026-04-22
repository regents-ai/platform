defmodule PlatformPhx.RuntimeConfig do
  @moduledoc false

  def database_url, do: fetch("DATABASE_URL")
  def base_rpc_url, do: fetch("BASE_RPC_URL") || "https://mainnet.base.org"
  def ethereum_rpc_url, do: fetch("ETHEREUM_RPC_URL")
  def privy_app_id, do: fetch("VITE_PRIVY_APP_ID")
  def privy_client_id, do: fetch("VITE_PRIVY_APP_CLIENT_ID")
  def privy_verification_key, do: fetch("PRIVY_VERIFICATION_KEY")
  def redeemer_address, do: fetch("VITE_NEXT_PUBLIC_REDEEMER_ADDRESS")
  def opensea_api_key, do: fetch("OPENSEA_API_KEY")
  def stripe_secret_key, do: fetch("STRIPE_SECRET_KEY")
  def stripe_webhook_secret, do: fetch("STRIPE_WEBHOOK_SECRET")
  def stripe_webhook_tolerance_seconds, do: fetch_integer("STRIPE_WEBHOOK_TOLERANCE_SECONDS", 300)

  def siwa_http_signature_tolerance_seconds,
    do: fetch_integer("SIWA_HTTP_SIGNATURE_TOLERANCE_SECONDS", 300)

  def siwa_server_base_url, do: fetch("SIWA_SERVER_BASE_URL")

  def stripe_billing_pricing_plan_id, do: fetch("STRIPE_BILLING_PRICING_PLAN_ID")
  def stripe_billing_topup_success_url, do: fetch("STRIPE_BILLING_TOPUP_SUCCESS_URL")
  def stripe_billing_topup_cancel_url, do: fetch("STRIPE_BILLING_TOPUP_CANCEL_URL")
  def stripe_runtime_meter_event_name, do: fetch("STRIPE_RUNTIME_METER_EVENT_NAME")
  def welcome_credit_enabled?, do: fetch_bool("WELCOME_CREDIT_ENABLED", true)
  def welcome_credit_limit, do: fetch_integer("WELCOME_CREDIT_LIMIT", 100)
  def welcome_credit_amount_usd_cents, do: fetch_integer("WELCOME_CREDIT_AMOUNT_USD_CENTS", 500)
  def welcome_credit_expiry_days, do: fetch_integer("WELCOME_CREDIT_EXPIRY_DAYS", 60)
  def sprites_api_token, do: fetch("SPRITES_API_TOKEN")
  def sprite_cli_path, do: fetch("SPRITE_CLI_PATH") || "sprite"
  def workspace_http_port, do: fetch("WORKSPACE_HTTP_PORT") || "3000"
  def regent_staking_rpc_url, do: fetch("REGENT_STAKING_RPC_URL") || base_rpc_url()
  def regent_staking_contract_address, do: fetch("REGENT_STAKING_CONTRACT_ADDRESS")
  def regent_staking_chain_id, do: fetch_integer("REGENT_STAKING_CHAIN_ID", 8453)
  def regent_staking_chain_label, do: fetch("REGENT_STAKING_CHAIN_LABEL") || "Base"
  def basename_parent_name, do: fetch("AGENT_BASENAME_PARENT_NAME") || "agent.base.eth"
  def ens_parent_name, do: fetch("AGENT_PROTOCOL_ENS_PARENT_NAME") || "regent.eth"

  def basenames_registry_address,
    do: fetch("BASENAMES_REGISTRY_ADDRESS") || "0xb94704422c2a1e396835a571837aa5ae53285a95"

  def basenames_l2_resolver_address,
    do: fetch("BASENAMES_L2_RESOLVER_ADDRESS") || "0xC6d566A56A1aFf6508b41f6c90ff131615583BCD"

  def ens_registry_address,
    do: fetch("ENS_REGISTRY_ADDRESS") || "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"

  def ens_public_resolver_address,
    do: fetch("ENS_PUBLIC_RESOLVER_ADDRESS") || "0x226159d592E2b063810a10Ebf6dcbAda94Ed68b8"

  def regent_ens_registrar_address, do: fetch("REGENT_ENS_REGISTRAR_ADDRESS")
  def regent_ens_owner_address, do: fetch("REGENT_ENS_OWNER_ADDRESS")

  def base_identity_registry_address,
    do: fetch("BASE_IDENTITY_REGISTRY_ADDRESS") || "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432"

  def basenames_payment_recipient, do: fetch("AGENT_BASENAME_PAYMENT_RECIPIENT")
  def basenames_price_wei, do: fetch("AGENT_BASENAME_PRICE_WEI") || "2500000000000000"

  defp fetch(name) do
    System.get_env(name)
    |> case do
      nil ->
        nil

      value ->
        trimmed = String.trim(value)
        if trimmed == "", do: nil, else: trimmed
    end
  end

  defp fetch_integer(name, default) do
    case fetch(name) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {parsed, ""} -> parsed
          _ -> default
        end
    end
  end

  defp fetch_bool(name, default) do
    case fetch(name) do
      nil -> default
      "1" -> true
      "true" -> true
      "TRUE" -> true
      "yes" -> true
      "YES" -> true
      "0" -> false
      "false" -> false
      "FALSE" -> false
      "no" -> false
      "NO" -> false
      _ -> default
    end
  end
end
