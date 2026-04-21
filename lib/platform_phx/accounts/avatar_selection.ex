defmodule PlatformPhx.Accounts.AvatarSelection do
  @moduledoc false

  @shader_options [
    %{
      id: "w3dfWN",
      title: "Shard",
      description: "Crystalline shard with a steady glow."
    },
    %{
      id: "wXdfW4",
      title: "Orb",
      description: "Glowing orb with a softer center."
    },
    %{
      id: "w3dBD4",
      title: "Ionize",
      description: "Ionized shell with brighter outer light."
    },
    %{
      id: "t3tfWN",
      title: "Orbital",
      description: "Rings and fold lines with a slow spin feel."
    },
    %{
      id: "wXdfWN",
      title: "Phosphor 3",
      description: "Trailing phosphor bloom with a sharper edge."
    },
    %{
      id: "storm",
      title: "Storm",
      description: "Charged cloud look with a stronger pulse."
    }
  ]

  @collections %{
    "animata1" => %{label: "Collection I", preview_type: "collection_chip", gold_border: false},
    "animata2" => %{label: "Collection II", preview_type: "collection_chip", gold_border: false},
    "animataPass" => %{label: "Regents Club", preview_type: "token_card", gold_border: true}
  }

  def shader_options, do: @shader_options
  def collection_specs, do: @collections

  def collection_token_selection?(attrs) when is_map(attrs) do
    normalize_string(fetch(attrs, "kind")) == "collection_token"
  end

  def collection_token_selection?(_attrs), do: false

  def normalize(attrs, holdings \\ %{})

  def normalize(nil, _holdings), do: {:ok, nil}

  def normalize(attrs, holdings) when is_map(attrs) do
    case normalize_string(fetch(attrs, "kind")) do
      "custom_shader" -> normalize_custom_shader(attrs)
      "collection_token" -> normalize_collection_token(attrs, holdings)
      _ -> {:error, "Choose a valid avatar before saving."}
    end
  end

  def normalize(_attrs, _holdings), do: {:error, "Choose a valid avatar before saving."}

  def serialize(nil), do: nil

  def serialize(%{} = avatar) do
    case normalize_string(fetch(avatar, "kind")) do
      "custom_shader" ->
        shader_id = normalize_string(fetch(avatar, "shader_id"))
        define_values = normalize_define_values(fetch(avatar, "define_values"))

        if shader_id in [nil, ""] or not known_shader_id?(shader_id) or define_values == :error do
          nil
        else
          %{
            "kind" => "custom_shader",
            "shader_id" => shader_id,
            "define_values" => define_values,
            "preview_type" => "shader"
          }
        end

      "collection_token" ->
        collection = normalize_string(fetch(avatar, "collection"))
        token_id = normalize_positive_integer(fetch(avatar, "token_id"))

        if is_nil(token_id) or not Map.has_key?(@collections, collection) do
          nil
        else
          collection_spec = Map.fetch!(@collections, collection)

          %{
            "kind" => "collection_token",
            "collection" => collection,
            "token_id" => token_id,
            "preview_type" => collection_spec.preview_type,
            "gold_border" => collection_spec.gold_border
          }
        end

      _ ->
        nil
    end
  end

  def current_label(%{"kind" => "custom_shader", "shader_id" => shader_id}) do
    shader_title(shader_id)
  end

  def current_label(%{
        "kind" => "collection_token",
        "collection" => collection,
        "token_id" => token_id
      }) do
    "#{collection_label(collection)} ##{token_id}"
  end

  def current_label(_avatar), do: "No saved avatar"

  def gold_border?(%{"kind" => "collection_token", "collection" => "animataPass"}), do: true
  def gold_border?(_avatar), do: false

  def collection_label(collection) when is_binary(collection) do
    @collections
    |> Map.get(collection, %{label: "Collection"})
    |> Map.fetch!(:label)
  end

  def shader_title(shader_id) when is_binary(shader_id) do
    @shader_options
    |> Enum.find(&(&1.id == shader_id))
    |> case do
      nil -> "Saved shader"
      shader -> shader.title
    end
  end

  def shader_description(shader_id) when is_binary(shader_id) do
    @shader_options
    |> Enum.find(&(&1.id == shader_id))
    |> case do
      nil -> "Saved custom look."
      shader -> shader.description
    end
  end

  defp normalize_custom_shader(attrs) do
    shader_id = normalize_string(fetch(attrs, "shader_id"))
    define_values = normalize_define_values(fetch(attrs, "define_values"))

    cond do
      shader_id in [nil, ""] ->
        {:error, "Choose a shader look before saving."}

      not known_shader_id?(shader_id) ->
        {:error, "Choose one of the saved shader looks shown on this page."}

      define_values == :error ->
        {:error, "The shader settings could not be saved."}

      true ->
        {:ok,
         %{
           "kind" => "custom_shader",
           "shader_id" => shader_id,
           "define_values" => define_values,
           "preview_type" => "shader"
         }}
    end
  end

  defp normalize_collection_token(attrs, holdings) do
    collection = normalize_string(fetch(attrs, "collection"))
    token_id = normalize_positive_integer(fetch(attrs, "token_id"))

    cond do
      not Map.has_key?(@collections, collection) ->
        {:error, "Choose a collection avatar you already own."}

      is_nil(token_id) ->
        {:error, "Choose a collection avatar you already own."}

      token_id not in tokens_for_collection(holdings, collection) ->
        {:error, "That collection avatar is not in this wallet right now."}

      true ->
        collection_spec = Map.fetch!(@collections, collection)

        {:ok,
         %{
           "kind" => "collection_token",
           "collection" => collection,
           "token_id" => token_id,
           "preview_type" => collection_spec.preview_type,
           "gold_border" => collection_spec.gold_border
         }}
    end
  end

  defp fetch(attrs, key) when is_map(attrs) do
    Map.get(attrs, key) || Map.get(attrs, existing_atom_key(key))
  end

  defp normalize_define_values(nil), do: %{}

  defp normalize_define_values(values) when is_map(values) do
    Enum.reduce_while(values, %{}, fn
      {key, value}, acc when is_binary(key) and is_binary(value) ->
        {:cont, Map.put(acc, key, String.trim(value))}

      {key, value}, acc when is_atom(key) and is_binary(value) ->
        {:cont, Map.put(acc, Atom.to_string(key), String.trim(value))}

      _entry, _acc ->
        {:halt, :error}
    end)
  end

  defp normalize_define_values(_values), do: :error

  defp normalize_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp normalize_positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _other -> nil
    end
  end

  defp normalize_positive_integer(_value), do: nil

  defp normalize_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_string(_value), do: nil

  defp existing_atom_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp tokens_for_collection(holdings, collection) when is_map(holdings) do
    holdings
    |> Map.get(collection, [])
    |> List.wrap()
    |> Enum.filter(&is_integer/1)
  end

  defp tokens_for_collection(_holdings, _collection), do: []

  defp known_shader_id?(shader_id) do
    Enum.any?(@shader_options, &(&1.id == shader_id))
  end
end
