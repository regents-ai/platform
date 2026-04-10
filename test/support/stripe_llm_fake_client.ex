defmodule PlatformPhx.StripeLlmFakeClient do
  @moduledoc false

  def create_checkout_session(_params) do
    {:ok,
     %{
       url: "https://billing.stripe.test/checkout/agent-formation",
       customer_id: "cus_test_agent_formation"
     }}
  end

  def report_usage(_params) do
    {:ok, %{meter_event_id: "mtr_test_usage"}}
  end
end
