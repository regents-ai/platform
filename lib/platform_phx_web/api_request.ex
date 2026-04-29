defmodule PlatformPhxWeb.ApiRequest do
  @moduledoc false

  @type field_spec :: {String.t(), atom(), keyword()}

  @spec cast(map(), [field_spec()]) :: {:ok, map()} | {:error, {:bad_request, String.t()}}
  def cast(params, fields) when is_map(params) and is_list(fields) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {field, type, opts}, {:ok, acc} ->
      value = Map.get(params, field)

      case cast_value(field, value, type, opts) do
        {:ok, :omit} -> {:cont, {:ok, acc}}
        {:ok, casted} -> {:cont, {:ok, Map.put(acc, field, casted)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def cast(_params, _fields), do: {:error, {:bad_request, "Request body must be a JSON object"}}

  defp cast_value(field, nil, _type, opts) do
    cond do
      Keyword.has_key?(opts, :default) -> {:ok, Keyword.fetch!(opts, :default)}
      Keyword.get(opts, :required, false) -> {:error, {:bad_request, "#{field} is required"}}
      true -> {:ok, :omit}
    end
  end

  defp cast_value(_field, value, :string, _opts) when is_binary(value), do: {:ok, value}
  defp cast_value(_field, value, :integer, _opts) when is_integer(value), do: {:ok, value}
  defp cast_value(_field, value, :map, _opts) when is_map(value), do: {:ok, value}
  defp cast_value(_field, value, :list, _opts) when is_list(value), do: {:ok, value}
  defp cast_value(_field, value, :boolean, _opts) when is_boolean(value), do: {:ok, value}

  defp cast_value(field, value, :integer, _opts) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _other -> {:error, {:bad_request, "#{field} must be an integer"}}
    end
  end

  defp cast_value(_field, value, :positive_integer, _opts)
       when is_integer(value) and value > 0,
       do: {:ok, value}

  defp cast_value(field, value, :positive_integer, opts) do
    with {:ok, integer} <- cast_value(field, value, :integer, opts),
         true <- integer > 0 do
      {:ok, integer}
    else
      false -> {:error, {:bad_request, "#{field} must be a positive integer"}}
      {:error, _reason} = error -> error
    end
  end

  defp cast_value(field, value, :enum, opts) when is_binary(value) do
    allowed = Keyword.fetch!(opts, :values)

    if value in allowed do
      {:ok, value}
    else
      {:error, {:bad_request, "#{field} is not supported"}}
    end
  end

  defp cast_value(field, _value, type, _opts),
    do: {:error, {:bad_request, "#{field} must be #{type_name(type)}"}}

  defp type_name(:positive_integer), do: "a positive integer"
  defp type_name(:enum), do: "a supported value"
  defp type_name(type), do: "a #{type}"
end
