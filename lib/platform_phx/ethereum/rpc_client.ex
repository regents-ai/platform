defmodule PlatformPhx.Ethereum.RpcClient do
  @moduledoc false

  alias PlatformPhx.ExternalHttpClient

  @callback json_rpc(String.t(), String.t(), list()) :: {:ok, term()} | {:error, String.t()}

  def json_rpc(url, method, params) do
    client().json_rpc(url, method, params)
  end

  defp client do
    Application.get_env(:platform_phx, :ethereum_rpc_client, __MODULE__.HttpClient)
  end

  defmodule HttpClient do
    @moduledoc false
    @behaviour PlatformPhx.Ethereum.RpcClient

    @impl true
    def json_rpc(url, method, params) do
      case ExternalHttpClient.post(url,
             json: %{
               id: 1,
               jsonrpc: "2.0",
               method: method,
               params: params
             }
           ) do
        {:ok, response} ->
          decode_response(response)

        {:error, error} ->
          {:error, ExternalHttpClient.format_error(error)}
      end
    end

    defp decode_response(%{body: %{"error" => %{"message" => message}}})
         when is_binary(message),
         do: {:error, message}

    defp decode_response(%{body: %{"result" => result}}), do: {:ok, result}

    defp decode_response(%{body: body}),
      do: {:error, "Unexpected RPC response: #{inspect(body)}"}
  end
end
