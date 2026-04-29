defmodule PlatformPhx.ExternalHttpClientTest do
  use ExUnit.Case, async: false

  alias PlatformPhx.ExternalHttpClient

  setup do
    previous_client = Application.get_env(:platform_phx, :external_http_client)
    previous_pid = Application.get_env(:platform_phx, :external_http_client_test_pid)

    Application.put_env(:platform_phx, :external_http_client, __MODULE__.Client)
    Application.put_env(:platform_phx, :external_http_client_test_pid, self())

    on_exit(fn ->
      restore_env(:external_http_client, previous_client)
      restore_env(:external_http_client_test_pid, previous_pid)
    end)
  end

  test "adds request timeouts to external calls" do
    assert {:ok, %{status: 200, body: %{}}} = ExternalHttpClient.get("https://example.test")

    assert_receive {:external_http_request, opts}
    assert opts[:receive_timeout] == 15_000
    assert opts[:connect_options] == [timeout: 5_000]
  end

  test "keeps sensitive request values out of formatted errors" do
    message =
      ExternalHttpClient.format_error(
        RuntimeError.exception(
          "failed with Bearer sprite-secret and sk_test_123456789 and authorization: token"
        )
      )

    assert message =~ "Bearer [redacted]"
    assert message =~ "sk_test_[redacted]"
    assert message =~ "authorization: [redacted]"
    refute message =~ "sprite-secret"
    refute message =~ "123456789"
  end

  defmodule Client do
    @behaviour PlatformPhx.ExternalHttpClient

    @impl true
    def request(opts) do
      send(Application.fetch_env!(:platform_phx, :external_http_client_test_pid), {
        :external_http_request,
        opts
      })

      {:ok, %{status: 200, body: %{}}}
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:platform_phx, key)
  defp restore_env(key, value), do: Application.put_env(:platform_phx, key, value)
end
