defmodule PlatformPhx.TestEthereumRpcClient do
  @moduledoc false

  def json_rpc(_url, method, params) do
    case :persistent_term.get({__MODULE__, method, params}, :undefined) do
      :undefined -> {:error, "rpc result not configured"}
      {:ok, result} -> {:ok, result}
      {:error, message} -> {:error, message}
    end
  end

  def put_result(method, params, result) do
    :persistent_term.put({__MODULE__, method, params}, {:ok, result})
  end

  def put_error(method, params, message) do
    :persistent_term.put({__MODULE__, method, params}, {:error, message})
  end

  def clear(method, params) do
    :persistent_term.erase({__MODULE__, method, params})
  end
end
