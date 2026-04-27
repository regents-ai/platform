defmodule PlatformPhxWeb.ContractValidationTest do
  use PlatformPhxWeb.ConnCase, async: false

  @api_contract_path Path.expand("../../../api-contract.openapiv3.yaml", __DIR__)
  @detach_path "/api/agent-platform/agents/{slug}/ens/detach"
  @readyz_path "/readyz"

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

  test "api contract publishes the readiness route" do
    contract = api_contract()

    assert get_in(contract, ["paths", @readyz_path, "get", "operationId"]) == "readyz"

    assert get_in(contract, [
             "paths",
             @readyz_path,
             "get",
             "responses",
             "200",
             "content",
             "application/json",
             "schema",
             "$ref"
           ]) == "#/components/schemas/ReadyzSnapshot"

    assert get_in(contract, [
             "paths",
             @readyz_path,
             "get",
             "responses",
             "503",
             "content",
             "application/json",
             "schema",
             "$ref"
           ]) == "#/components/schemas/ReadyzSnapshot"
  end

  test "api contract matches the product HTTP route surface" do
    contract_routes =
      api_contract()
      |> Map.fetch!("paths")
      |> Enum.flat_map(fn {path, operations} ->
        operations
        |> Map.keys()
        |> Enum.map(&{String.upcase(&1), path})
      end)
      |> MapSet.new()

    router_routes =
      PlatformPhxWeb.Router.__routes__()
      |> Enum.filter(&contract_backed_route?/1)
      |> Enum.map(
        &{&1.verb |> Atom.to_string() |> String.upcase(), normalize_route_path(&1.path)}
      )
      |> MapSet.new()

    assert MapSet.difference(router_routes, contract_routes) == MapSet.new()
    assert MapSet.difference(contract_routes, router_routes) == MapSet.new()
  end

  test "api contract keeps beta response envelopes explicit" do
    contract = api_contract()
    schemas = Map.fetch!(contract, "components") |> Map.fetch!("schemas")

    assert_required(schemas, "StatusMessage", ["statusMessage"])
    assert_required(schemas, "AgentSessionResponse", ["ok", "session"])
    assert_required(schemas, "AgentbookSessionResponse", ["ok", "session"])
    assert_required(schemas, "AgentFormationResponse", ["ok", "authenticated", "readiness"])
    assert_required(schemas, "BillingAccount", ["status", "connected"])
    assert_required(schemas, "BillingUsageSummary", ["runtime_credit_balance_usd_cents"])
    assert_required(schemas, "BasenamesAvailability", ["label", "available", "reserved"])
    assert_required(schemas, "BugReportResponse", ["ok", "message", "report"])
    assert_required(schemas, "RegentStakingWalletActionResponse", ["ok", "staking", "tx_request"])
    assert_required(schemas, "RegentStakingTxRequest", ["chain_id", "to", "value", "data"])
  end

  test "public staking promises only use the canonical signed-agent route" do
    paths = api_contract() |> Map.fetch!("paths") |> Map.keys() |> MapSet.new()

    assert MapSet.member?(paths, "/v1/agent/regent/staking")
    refute MapSet.member?(paths, "/api/regent/staking")
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

  defp required_fields(%{"required" => required}) when is_binary(required),
    do: MapSet.new([required])

  defp required_fields(_schema), do: MapSet.new()

  defp assert_required(schemas, schema_name, fields) do
    schema = Map.fetch!(schemas, schema_name)

    assert MapSet.subset?(MapSet.new(fields), required_fields(schema)),
           "#{schema_name} must require #{Enum.join(fields, ", ")}"
  end

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

  defp contract_backed_route?(route) do
    path = route.path

    String.starts_with?(path, "/api") or
      String.starts_with?(path, "/v1") or
      path in [
        "/healthz",
        "/readyz",
        "/robots.txt",
        "/sitemap.xml",
        "/.well-known/api-catalog",
        "/.well-known/agent-card.json",
        "/.well-known/agent-skills/index.json",
        "/.well-known/mcp/server-card.json",
        "/api-contract.openapiv3.yaml",
        "/cli-contract.yaml",
        "/agent-skills/regents-cli.md",
        "/metadata/:token_id"
      ]
  end

  defp normalize_route_path(path) do
    Regex.replace(~r/:([A-Za-z0-9_]+)/, path, "{\\1}")
  end
end
