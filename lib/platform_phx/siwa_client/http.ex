defmodule PlatformPhx.SiwaClient.Http do
  @moduledoc false
  @behaviour PlatformPhx.SiwaClient

  alias PlatformPhx.ExternalHttpClient
  alias PlatformPhx.RuntimeConfig

  @impl true
  def verify_http_request(payload, opts) when is_map(payload) do
    with {:ok, base_url} <- base_url(),
         {:ok, response} <-
           ExternalHttpClient.post(
             "#{base_url}/v1/agent/siwa/http-verify",
             json: Map.take(payload, ["method", "path", "headers", "body"]),
             headers: audience_headers(opts)
           ) do
      case response.status do
        200 ->
          {:ok, response.body}

        status ->
          {:error, decode_error(status, response.body)}
      end
    else
      {:error, {_, _, _} = error} ->
        {:error, error}

      {:error, error} ->
        {:error, {502, "siwa_service_unreachable", ExternalHttpClient.format_error(error)}}
    end
  end

  defp base_url do
    case RuntimeConfig.siwa_server_base_url() do
      value when is_binary(value) ->
        {:ok, String.trim_trailing(value, "/")}

      _ ->
        {:error, {500, "siwa_service_not_configured", "SIWA server base URL is not configured"}}
    end
  end

  defp audience_headers(opts) do
    case Keyword.get(opts, :audience) do
      nil -> []
      audience -> [{"x-siwa-audience", audience}]
    end
  end

  defp decode_error(status, %{"error" => %{"code" => code, "message" => message}}),
    do: {status, code, message}

  defp decode_error(status, body),
    do:
      {status, "siwa_service_error",
       "SIWA server returned an unexpected response: #{inspect(body)}"}
end
