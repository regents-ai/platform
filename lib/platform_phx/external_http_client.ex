defmodule PlatformPhx.ExternalHttpClient do
  @moduledoc false

  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, term()}

  @default_receive_timeout 15_000
  @default_connect_options [timeout: 5_000]

  def request(opts) when is_list(opts) do
    started_at = System.monotonic_time()
    normalized_opts = normalize_opts(opts)

    result = client().request(normalized_opts)

    :telemetry.execute(
      [:platform_phx, :external_http_client, :request],
      %{duration: System.monotonic_time() - started_at},
      %{
        method: normalized_opts[:method],
        host: request_host(normalized_opts[:url]),
        result: result_status(result)
      }
    )

    result
  end

  def get(url, opts \\ []), do: request([method: :get, url: url] ++ opts)

  def post(url, opts \\ []), do: request([method: :post, url: url] ++ opts)

  def format_error(%{__exception__: true} = error), do: error |> Exception.message() |> redact()
  def format_error({_kind, message}) when is_binary(message), do: redact(message)
  def format_error(error), do: error |> inspect() |> redact()

  def redact(value) when is_binary(value) do
    value
    |> String.replace(~r/Bearer\s+[A-Za-z0-9._~+\/=-]+/i, "Bearer [redacted]")
    |> String.replace(~r/(sk|pk|rk)_(live|test)_[A-Za-z0-9_]+/, "\\1_\\2_[redacted]")
    |> String.replace(~r/(x-api-key["':\s=>]+)[^,\]\}\s]+/i, "\\1[redacted]")
    |> String.replace(~r/(authorization["':\s=>]+)[^,\]\}]+/i, "\\1[redacted]")
  end

  def redact(value), do: value

  defp client do
    Application.get_env(:platform_phx, :external_http_client, __MODULE__.ReqClient)
  end

  defp normalize_opts(opts) do
    opts
    |> Keyword.put_new(:receive_timeout, @default_receive_timeout)
    |> Keyword.put_new(:connect_options, @default_connect_options)
  end

  defp request_host(%URI{host: host}), do: host

  defp request_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _uri -> "unknown"
    end
  end

  defp request_host(_url), do: "unknown"

  defp result_status({:ok, %{status: status}}), do: status
  defp result_status({:error, _reason}), do: :error
  defp result_status(_result), do: :unknown

  defmodule ReqClient do
    @moduledoc false
    @behaviour PlatformPhx.ExternalHttpClient

    @impl true
    def request(opts) when is_list(opts), do: Req.request(opts)
  end
end
