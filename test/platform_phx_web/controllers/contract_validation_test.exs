defmodule PlatformPhxWeb.ContractValidationTest do
  use PlatformPhxWeb.ConnCase, async: false

  @api_contract_path Path.expand("../../../api-contract.openapiv3.yaml", __DIR__)
  @cli_contract_path Path.expand("../../../cli-contract.yaml", __DIR__)
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

  test "contract release artifacts exist and match the source files" do
    assert :ok = PlatformPhx.Contracts.validate_release_artifacts!()
    assert :ok = PlatformPhx.Contracts.validate_source_artifacts_match!()
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

  test "api contract security matches the mounted route groups" do
    contract = api_contract()

    PlatformPhxWeb.Router.__routes__()
    |> Enum.filter(&contract_backed_route?/1)
    |> Enum.each(fn route ->
      method = route.verb |> Atom.to_string() |> String.downcase()
      path = normalize_route_path(route.path)
      expected = expected_security(path, method)
      actual = security_names(contract, ["paths", path, method, "security"])

      assert actual == expected,
             "#{String.upcase(method)} #{path} expected #{inspect(expected)} got #{inspect(actual)}"
    end)
  end

  test "api contract keeps beta response envelopes explicit" do
    contract = api_contract()
    schemas = Map.fetch!(contract, "components") |> Map.fetch!("schemas")

    assert_required(schemas, "StatusMessage", ["error"])
    assert_required(schemas, "AgentSessionResponse", ["ok", "session"])
    assert_required(schemas, "AgentbookSessionResponse", ["ok", "session"])

    assert_required(schemas, "AgentFormationResponse", [
      "ok",
      "authenticated",
      "access_eligibility",
      "formation_state",
      "billing_state",
      "runtime_cost_state",
      "blockers",
      "readiness"
    ])

    assert_required(schemas, "AgentFormationDoctorResponse", ["ok", "doctor"])
    assert_required(schemas, "AgentFormationDoctor", ["status", "summary", "checks", "blockers"])
    assert_required(schemas, "AgentPlatformProjectionResponse", ["ok", "projection"])

    assert_required(schemas, "AgentPlatformProjection", [
      "formation",
      "billing_account",
      "billing_usage",
      "companies",
      "public_profiles"
    ])

    assert_required(schemas, "PlatformCompanyProjection", [
      "company",
      "runtime",
      "formation",
      "public_profile"
    ])

    assert_required(schemas, "AgentAccessEligibility", [
      "eligible",
      "rule",
      "approved_collection_nft",
      "claimed_name_ready"
    ])

    assert_required(schemas, "PlatformFormationState", ["state", "blockers"])
    assert_required(schemas, "PlatformBillingState", ["state", "runtime_allowed"])

    assert_required(schemas, "PlatformRuntimeCostState", [
      "phase",
      "paused_at_zero",
      "prepaid_drawdown_state",
      "pause_targets"
    ])

    assert_required(schemas, "BillingAccount", [
      "status",
      "connected",
      "prepaid_drawdown_state",
      "pause_targets"
    ])

    assert_required(schemas, "BillingUsageSummary", [
      "runtime_credit_balance_usd_cents",
      "prepaid_drawdown_state",
      "pause_targets"
    ])

    assert_required(schemas, "BasenamesAvailability", ["label", "available", "reserved"])
    assert_required(schemas, "BugReportResponse", ["ok", "message", "report"])

    assert get_in(contract, [
             "paths",
             "/api/basenames/use",
             "post",
             "requestBody",
             "content",
             "application/json",
             "schema",
             "required"
           ]) == ["address", "label", "timestamp", "signature"]

    assert_required(schemas, "RegentStakingWalletActionResponse", [
      "ok",
      "staking",
      "wallet_action"
    ])

    assert_required(schemas, "WalletAction", [
      "action_id",
      "resource",
      "action",
      "chain_id",
      "to",
      "value",
      "data",
      "expected_signer",
      "expires_at",
      "idempotency_key",
      "risk_copy"
    ])
  end

  test "public staking promises only use the canonical signed-agent route" do
    paths = api_contract() |> Map.fetch!("paths") |> Map.keys() |> MapSet.new()

    assert MapSet.member?(paths, "/v1/agent/regent/staking")
    refute MapSet.member?(paths, "/api/regent/staking")
  end

  test "RWR contract locks public ids, signed writes, and canonical enums" do
    contract = api_contract()
    schemas = Map.fetch!(contract, "components") |> Map.fetch!("schemas")

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/workers",
             "get",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/workers",
             "post",
             "security"
           ]) == MapSet.new(["AgentSiwaHeaders"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/events",
             "post",
             "security"
           ]) == MapSet.new(["AgentSiwaHeaders"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/events/batch",
             "post",
             "security"
           ]) == MapSet.new(["AgentSiwaHeaders"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/events/stream",
             "get",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/tree",
             "get",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/cancel",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/retry",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/delegations",
             "post",
             "security"
           ]) == MapSet.new(["AgentSiwaHeaders"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/artifacts/{artifact_id}/publish",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runs/{run_id}/approvals/{approval_id}/resolve",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/agents/{source_id}/relationships",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/workers/{worker_id}/assignments",
             "get",
             "security"
           ]) == MapSet.new(["AgentSiwaHeaders"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes",
             "get",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes/{runtime_id}",
             "get",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes/{runtime_id}/checkpoint",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes/{runtime_id}/restore",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes/{runtime_id}/pause",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes/{runtime_id}/resume",
             "post",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes/{runtime_id}/services",
             "get",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert security_names(contract, [
             "paths",
             "/api/agent-platform/companies/{company_id}/rwr/runtimes/{runtime_id}/health",
             "get",
             "security"
           ]) == MapSet.new(["PrivySessionCookie"])

    assert enum_values(schemas, "AgentKind") ==
             MapSet.new([
               "hermes",
               "openclaw",
               "codex",
               "custom",
               "human_operator",
               "regent_bridge"
             ])

    assert enum_values(schemas, "WorkerRole") == MapSet.new(["manager", "executor", "hybrid"])

    assert enum_values(schemas, "ExecutionSurface") ==
             MapSet.new(["hosted_sprite", "local_bridge", "external_webhook"])

    assert enum_values(schemas, "RunnerKind") ==
             MapSet.new([
               "hermes_local_manager",
               "hermes_hosted_manager",
               "openclaw_local_manager",
               "codex_exec",
               "codex_app_server",
               "openclaw_local_executor",
               "openclaw_code_agent_local",
               "fake",
               "custom_worker"
             ])

    assert enum_values(schemas, "BillingMode") ==
             MapSet.new(["platform_hosted", "user_local", "external_self_reported"])

    assert property_enum_values(schemas, "PlatformFormationState", "state") ==
             MapSet.new(["pending", "blocked", "provisioning", "ready"])

    assert property_enum_values(schemas, "PlatformBillingState", "state") ==
             MapSet.new(["trial", "free_day", "prepaid", "paused", "zero", "failed"])

    assert property_enum_values(schemas, "PlatformRuntimeCostState", "phase") ==
             MapSet.new(["free_day", "prepaid", "paused_at_zero", "unavailable"])

    assert property_enum_values(schemas, "PlatformRuntimeCostState", "prepaid_drawdown_state") ==
             MapSet.new(["free_day", "drawing_down", "paused_at_zero", "unavailable"])

    assert enum_values(schemas, "TrustScope") ==
             MapSet.new(["platform_hosted", "local_user_controlled", "external_user_controlled"])

    assert enum_values(schemas, "ReportedUsagePolicy") ==
             MapSet.new(["platform_metered", "self_reported", "external_reported"])

    assert enum_values(schemas, "RelationshipKind") ==
             MapSet.new(["manager_of", "preferred_executor", "can_delegate_to", "reports_to"])

    assert enum_values(schemas, "RelationshipStatus") ==
             MapSet.new(["active", "paused", "revoked"])

    request_schema = Map.fetch!(schemas, "RwrWorkerRegistrationRequest")
    runtime_schema = Map.fetch!(schemas, "RwrRuntimeCreateRequest")
    checkpoint_schema = Map.fetch!(schemas, "RwrRuntimeCheckpointRequest")
    restore_schema = Map.fetch!(schemas, "RwrRuntimeRestoreRequest")
    delegation_schema = Map.fetch!(schemas, "RwrDelegationRequest")
    event_schema = Map.fetch!(schemas, "RwrRunEventAppendRequest")
    event_batch_schema = Map.fetch!(schemas, "RwrRunEventBatchAppendRequest")
    event_batch_item_schema = Map.fetch!(schemas, "RwrRunEventBatchAppendItem")
    approval_resolve_schema = Map.fetch!(schemas, "RwrApprovalResolveRequest")

    assert MapSet.member?(required_fields(request_schema), "company_id")

    assert required_fields(runtime_schema) ==
             MapSet.new([
               "company_id",
               "name",
               "runner_kind",
               "execution_surface",
               "billing_mode"
             ])

    assert required_fields(checkpoint_schema) ==
             MapSet.new(["company_id", "runtime_id", "checkpoint_ref"])

    assert required_fields(restore_schema) ==
             MapSet.new(["company_id", "runtime_id", "checkpoint_id"])

    assert required_fields(delegation_schema) ==
             MapSet.new(["company_id", "run_id", "requested_runner_kind", "strategy", "tasks"])

    assert MapSet.member?(property_names(delegation_schema), "requested_runner_kind")
    refute MapSet.member?(property_names(delegation_schema), "runner_kind")

    assert required_fields(event_schema) == MapSet.new(["company_id", "run_id", "kind"])
    assert MapSet.member?(property_names(event_schema), "kind")
    refute MapSet.member?(property_names(event_schema), "event_type")

    assert required_fields(event_batch_schema) == MapSet.new(["company_id", "run_id", "events"])
    assert required_fields(event_batch_item_schema) == MapSet.new(["kind"])
    refute MapSet.member?(property_names(event_batch_item_schema), "company_id")
    refute MapSet.member?(property_names(event_batch_item_schema), "run_id")

    assert required_fields(approval_resolve_schema) ==
             MapSet.new(["company_id", "run_id", "decision"])
  end

  test "CLI contract uses canonical RWR command names" do
    commands =
      cli_contract()
      |> Map.fetch!("commands")
      |> Enum.map(&Map.fetch!(&1, "name"))
      |> MapSet.new()

    assert MapSet.subset?(
             MapSet.new([
               "regents work create",
               "regents work list",
               "regents work show",
               "regents work run",
               "regents work watch",
               "regents platform formation doctor",
               "regents platform projection",
               "regents runtime create",
               "regents runtime show",
               "regents runtime checkpoint",
               "regents runtime restore",
               "regents runtime pause",
               "regents runtime resume",
               "regents runtime services",
               "regents runtime health",
               "regents agent connect hermes",
               "regents agent connect openclaw",
               "regents agent link",
               "regents agent execution-pool"
             ]),
             commands
           )

    refute Enum.any?(commands, &String.starts_with?(&1, "regents rwr "))
  end

  defp api_contract do
    @api_contract_path
    |> File.read!()
    |> :yamerl_constr.string()
    |> normalize_yaml()
  end

  defp cli_contract do
    @cli_contract_path
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

  defp enum_values(schemas, schema_name) do
    schemas
    |> Map.fetch!(schema_name)
    |> Map.fetch!("enum")
    |> MapSet.new()
  end

  defp property_enum_values(schemas, schema_name, property_name) do
    schemas
    |> Map.fetch!(schema_name)
    |> Map.fetch!("properties")
    |> Map.fetch!(property_name)
    |> Map.fetch!("enum")
    |> MapSet.new()
  end

  defp security_names(contract, path) do
    contract
    |> get_in(path)
    |> List.wrap()
    |> Enum.flat_map(fn
      value when is_map(value) -> Map.keys(value)
      _value -> []
    end)
    |> MapSet.new()
  end

  defp expected_security(path, method) do
    cond do
      path == "/api/auth/privy/session" and method == "post" ->
        MapSet.new(["PrivyBearerToken"])

      String.starts_with?(path, "/api/auth/privy") and path != "/api/auth/privy/csrf" ->
        MapSet.new(["PrivySessionCookie"])

      String.starts_with?(path, "/api/auth/agent") and method in ["get", "delete"] ->
        MapSet.new(["AgentSessionCookie"])

      path == "/api/auth/agent/session" and method == "post" ->
        MapSet.new(["AgentSiwaHeaders"])

      path == "/api/agentbook/sessions/{id}/submit" ->
        MapSet.new(["AgentSessionCookie"])

      signed_agent_route?(path, method) ->
        MapSet.new(["AgentSiwaHeaders"])

      session_route?(path, method) ->
        MapSet.new(["PrivySessionCookie"])

      true ->
        MapSet.new()
    end
  end

  defp signed_agent_route?(path, method) when is_binary(path) do
    String.starts_with?(path, "/v1/agent") or
      (String.starts_with?(path, "/api/agentbook") and
         path != "/api/agentbook/sessions/{id}/submit") or
      path == "/api/agent-platform/ens/prepare-primary" or
      (path == "/api/agent-platform/companies/{company_id}/rwr/workers" and
         method == "post") or
      String.contains?(path, "/workers/{worker_id}/heartbeat") or
      String.contains?(path, "/assignments") or
      (String.contains?(path, "/events") and String.ends_with?(path, "/events") and
         method == "post") or
      String.ends_with?(path, "/events/batch") or
      (String.ends_with?(path, "/artifacts") and method == "post") or
      String.ends_with?(path, "/delegations")
  end

  defp session_route?(path, method) do
    path == "/api/agentbook/sessions/{id}/submit" or
      (session_agent_platform_route?(path) and
         not signed_agent_route?(path, method))
  end

  defp session_agent_platform_route?(path) do
    Enum.any?(
      [
        "/api/agent-platform/formation",
        "/api/agent-platform/projection",
        "/api/agent-platform/billing",
        "/api/agent-platform/agents/{slug}/runtime",
        "/api/agent-platform/agents/{slug}/ens",
        "/api/agent-platform/ens/claims",
        "/api/agent-platform/sprites",
        "/api/agent-platform/rwr",
        "/api/agent-platform/companies"
      ],
      &String.starts_with?(path, &1)
    )
  end

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
