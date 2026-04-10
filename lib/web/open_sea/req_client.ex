defmodule Web.OpenSea.ReqClient do
  @moduledoc false
  @behaviour Web.OpenSea.HttpClient

  @impl true
  @spec get(URI.t() | String.t(), keyword()) ::
          {:ok, %{status: integer(), body: map()}} | {:error, term()}
  def get(url, options) do
    case Req.get(url, options) do
      {:ok, response} ->
        {:ok, %{status: response.status, body: response.body}}

      {:error, error} ->
        {:error, error}
    end
  end
end
