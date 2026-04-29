defmodule PlatformPhx.Ethereum.RpcClientTest do
  use ExUnit.Case, async: false

  alias PlatformPhx.Ethereum.RpcClient

  setup do
    previous_client = Application.get_env(:platform_phx, :external_http_client)
    previous_pid = Application.get_env(:platform_phx, :external_http_client_test_pid)
    previous_result = Application.get_env(:platform_phx, :external_http_client_result)

    Application.put_env(:platform_phx, :external_http_client, __MODULE__.HttpClient)
    Application.put_env(:platform_phx, :external_http_client_test_pid, self())

    on_exit(fn ->
      restore_env(:external_http_client, previous_client)
      restore_env(:external_http_client_test_pid, previous_pid)
      restore_env(:external_http_client_result, previous_result)
    end)
  end

  test "posts the JSON-RPC envelope through the shared request layer" do
    Application.put_env(:platform_phx, :external_http_client_result, {
      :ok,
      %{status: 200, body: %{"result" => "0x2a"}}
    })

    assert {:ok, "0x2a"} =
             RpcClient.HttpClient.json_rpc("https://base.example", "eth_blockNumber", [])

    assert_receive {:external_http_request, opts}
    assert opts[:method] == :post
    assert opts[:url] == "https://base.example"
    assert opts[:json] == %{id: 1, jsonrpc: "2.0", method: "eth_blockNumber", params: []}
    assert opts[:receive_timeout] == 15_000
  end

  test "returns a plain error message for RPC error envelopes" do
    Application.put_env(:platform_phx, :external_http_client_result, {
      :ok,
      %{status: 200, body: %{"error" => %{"message" => "execution reverted"}}}
    })

    assert {:error, "execution reverted"} =
             RpcClient.HttpClient.json_rpc("https://base.example", "eth_call", [])
  end

  defmodule HttpClient do
    @behaviour PlatformPhx.ExternalHttpClient

    @impl true
    def request(opts) do
      send(Application.fetch_env!(:platform_phx, :external_http_client_test_pid), {
        :external_http_request,
        opts
      })

      Application.fetch_env!(:platform_phx, :external_http_client_result)
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:platform_phx, key)
  defp restore_env(key, value), do: Application.put_env(:platform_phx, key, value)
end
