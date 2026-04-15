defmodule PlatformPhx.StripeLlmFakeClient do
  @moduledoc false

  def create_billing_setup_checkout_session(params) do
    success_url = URI.encode_www_form(params.success_url || "")
    cancel_url = URI.encode_www_form(params.cancel_url || "")

    {:ok,
     %{
       url:
         "https://billing.stripe.test/checkout/agent-formation?success_url=#{success_url}&cancel_url=#{cancel_url}",
       customer_id: "cus_test_agent_formation"
     }}
  end

  def create_topup_checkout_session(_params) do
    {:ok,
     %{
       url: "https://billing.stripe.test/checkout/runtime-topup",
       customer_id: "cus_test_agent_formation"
     }}
  end

  def create_credit_grant(_params) do
    case Application.get_env(:platform_phx, :stripe_fake_credit_grant_result, :ok) do
      :ok ->
        {:ok, %{credit_grant_id: "cg_test_runtime_credit"}}

      {:error, message} when is_binary(message) ->
        {:error, {:external, :stripe, message}}
    end
  end

  def report_runtime_usage(_params) do
    case Application.get_env(:platform_phx, :stripe_fake_runtime_usage_result, :ok) do
      :ok ->
        {:ok, %{meter_event_id: "mtr_test_usage"}}

      {:error, message} when is_binary(message) ->
        {:error, {:external, :stripe, message}}
    end
  end
end
