defmodule PlatformPhx.AgentPlatform.StripeBillingTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias PlatformPhx.AgentPlatform.StripeBilling

  setup do
    previous_client = Application.get_env(:platform_phx, :external_http_client)
    previous_pid = Application.get_env(:platform_phx, :stripe_billing_test_pid)

    Application.put_env(:platform_phx, :external_http_client, __MODULE__.Client)
    Application.put_env(:platform_phx, :stripe_billing_test_pid, self())

    on_exit(fn ->
      restore_env(:external_http_client, previous_client)
      restore_env(:stripe_billing_test_pid, previous_pid)
    end)

    :ok
  end

  test "Stripe response logs keep customer and secret values out" do
    log =
      capture_log(fn ->
        assert {:error, {:external, :stripe, _message}} =
                 StripeBilling.HttpClient.create_topup_checkout_session(%{
                   secret_key: "sk_test_local_secret",
                   success_url: "https://platform.example/success",
                   cancel_url: "https://platform.example/cancel",
                   customer_id: "cus_sensitive",
                   amount_usd_cents: 1_000,
                   metadata: %{"billing_account_id" => "1"},
                   idempotency_key: "topup-test"
                 })
      end)

    assert log =~ "stripe top-up failed"
    assert log =~ "card_declined"
    refute log =~ "cus_sensitive"
    refute log =~ "sk_test_local_secret"
    refute log =~ "private failure"
  end

  defmodule Client do
    @behaviour PlatformPhx.ExternalHttpClient

    @impl true
    def request(_opts) do
      {:ok,
       %{
         status: 402,
         body: %{
           "customer" => "cus_sensitive",
           "error" => %{
             "type" => "card_error",
             "code" => "card_declined",
             "message" => "private failure for cus_sensitive using sk_test_local_secret"
           }
         }
       }}
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:platform_phx, key)
  defp restore_env(key, value), do: Application.put_env(:platform_phx, key, value)
end
