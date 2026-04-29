defmodule PlatformPhx.Contracts do
  @moduledoc false

  @contract_files ~w(api-contract.openapiv3.yaml cli-contract.yaml)

  def contract_files, do: @contract_files

  def contents!(filename) when filename in @contract_files do
    filename
    |> release_path()
    |> File.read!()
  end

  def validate_release_artifacts! do
    Enum.each(@contract_files, fn filename ->
      path = release_path(filename)

      unless File.regular?(path) do
        raise "missing Platform contract release artifact: #{path}"
      end

      if File.read!(path) |> String.trim() == "" do
        raise "empty Platform contract release artifact: #{path}"
      end
    end)

    :ok
  end

  def validate_source_artifacts_match! do
    Enum.each(@contract_files, fn filename ->
      source = source_path(filename)
      release = release_path(filename)

      unless File.regular?(source) do
        raise "missing Platform source contract: #{source}"
      end

      unless File.read!(source) == File.read!(release) do
        raise "Platform contract release artifact is out of sync: #{filename}"
      end
    end)

    :ok
  end

  def release_path(filename) when filename in @contract_files do
    Application.app_dir(:platform_phx, Path.join(["priv", "contracts", filename]))
  end

  def source_path(filename) when filename in @contract_files do
    "../.."
    |> Path.expand(__DIR__)
    |> Path.join(filename)
  end
end
