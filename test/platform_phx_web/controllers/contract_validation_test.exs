defmodule PlatformPhxWeb.ContractValidationTest do
  use PlatformPhxWeb.ConnCase, async: false

  @api_contract_path Path.expand("../../../api-contract.openapiv3.yaml", __DIR__)
  @detach_path "/api/agent-platform/agents/{slug}/ens/detach"

  test "api contract is served from the app", %{conn: conn} do
    api_contract_conn =
      conn
      |> get("/api-contract.openapiv3.yaml")

    assert response(api_contract_conn, 200) =~ "openapi: 3.1.0"

    assert get_resp_header(api_contract_conn, "content-type") == [
             "application/yaml; charset=utf-8"
           ]
  end

  test "cli contract is served from the app", %{conn: conn} do
    cli_contract_conn =
      conn
      |> get("/cli-contract.yaml")

    assert response(cli_contract_conn, 200) =~ "title: Regents CLI Contract"

    assert get_resp_header(cli_contract_conn, "content-type") == [
             "application/yaml; charset=utf-8"
           ]
  end

  test "api contract locks the ENS request and response shape" do
    contract = api_contract()
    schemas = get_in(contract, ["components", "schemas"])

    assert get_in(contract, ["paths", @detach_path, "post", "requestBody", "required"]) == true

    assert get_in(contract, [
             "paths",
             @detach_path,
             "post",
             "requestBody",
             "content",
             "application/json",
             "schema",
             "$ref"
           ]) == "#/components/schemas/DetachEnsNameRequest"

    attach_schema = Map.fetch!(schemas, "AttachEnsNameRequest")

    assert MapSet.subset?(
             MapSet.new(["agent_id", "include_reverse", "registry_address", "current_agent_uri"]),
             property_names(attach_schema)
           )

    link_plan_schema = Map.fetch!(schemas, "EnsLinkPlan")

    assert MapSet.subset?(
             MapSet.new([
               "ensip25_verified",
               "forward_resolution_verified",
               "reverse_resolution_verified",
               "primary_name_verified",
               "fully_synced"
             ]),
             required_fields(link_plan_schema)
           )

    ens_assignment_schema = Map.fetch!(schemas, "AgentEnsAssignment")

    assert property_names(ens_assignment_schema) ==
             MapSet.new(["attached", "claim_id", "name", "claim_status"])
  end

  defp api_contract do
    @api_contract_path
    |> File.read!()
    |> :yamerl_constr.string()
    |> normalize_yaml()
  end

  defp property_names(%{"properties" => properties}) when is_map(properties) do
    properties
    |> Map.keys()
    |> MapSet.new()
  end

  defp property_names(_schema), do: MapSet.new()

  defp required_fields(%{"required" => required}) when is_list(required), do: MapSet.new(required)
  defp required_fields(_schema), do: MapSet.new()

  defp normalize_yaml([document]), do: normalize_yaml(document)

  defp normalize_yaml(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {normalize_yaml(key), normalize_yaml(value)} end)
  end

  defp normalize_yaml(list) when is_list(list) do
    cond do
      List.ascii_printable?(list) ->
        list
        |> List.to_string()
        |> normalize_string_scalar()

      tuple_entries?(list) ->
        Map.new(list, fn {key, value} -> {normalize_yaml(key), normalize_yaml(value)} end)

      true ->
        Enum.map(list, &normalize_yaml/1)
    end
  end

  defp normalize_yaml({key, value}), do: %{normalize_yaml(key) => normalize_yaml(value)}
  defp normalize_yaml(value) when is_binary(value), do: value

  defp normalize_yaml(value) when is_number(value) or is_boolean(value) or is_nil(value),
    do: value

  defp normalize_yaml(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_yaml(value), do: to_string(value)

  defp tuple_entries?(list) do
    Enum.all?(list, fn
      {_, _} -> true
      _ -> false
    end)
  end

  defp normalize_string_scalar("true"), do: true
  defp normalize_string_scalar("false"), do: false
  defp normalize_string_scalar(value), do: value
end
