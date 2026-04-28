defmodule PlatformPhxWeb.RouteSecurityTest do
  use PlatformPhxWeb.ConnCase, async: false

  @signed_agent_routes [
    {:get, "/v1/agent/regent/staking", nil},
    {:post, "/v1/agent/regent/staking/stake", %{"amount" => "1"}},
    {:post, "/v1/agent/bug-report", %{"summary" => "bug", "details" => "details"}},
    {:post, "/api/agentbook/sessions", %{}},
    {:post, "/api/agent-platform/ens/prepare-primary", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/workers", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/workers/worker-id/heartbeat", %{}},
    {:get, "/api/agent-platform/companies/company-id/rwr/workers/worker-id/assignments", nil},
    {:post, "/api/agent-platform/companies/company-id/rwr/assignments/assignment-id/claim", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/assignments/assignment-id/release",
     %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/assignments/assignment-id/complete",
     %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/runs/run-id/events", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/runs/run-id/artifacts", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/runs/run-id/delegations", %{}}
  ]

  @csrf_write_routes [
    {:post, "/api/auth/privy/session", %{}},
    {:put, "/api/auth/privy/profile/avatar", %{}},
    {:post, "/api/agentbook/sessions/session-id/submit", %{}},
    {:post, "/api/agent-platform/billing/setup/checkout", %{}},
    {:post, "/api/agent-platform/billing/topups/checkout", %{}},
    {:post, "/api/agent-platform/formation/companies", %{}},
    {:post, "/api/agent-platform/sprites/company/pause", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/work-items", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/work-items/work-item-id/runs", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/runtimes", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/runtimes/runtime-id/checkpoint", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/runtimes/runtime-id/restore", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/runtimes/runtime-id/pause", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/runtimes/runtime-id/resume", %{}},
    {:post, "/api/agent-platform/companies/company-id/rwr/agents/agent-profile-id/relationships",
     %{}},
    {:delete, "/api/agent-platform/companies/company-id/rwr/agent-relationships/relationship-id",
     %{}}
  ]

  setup do
    previous_client = Application.get_env(:platform_phx, :siwa_client)
    Application.put_env(:platform_phx, :siwa_client, PlatformPhx.TestSiwaClient)

    on_exit(fn ->
      Application.put_env(:platform_phx, :siwa_client, previous_client)
    end)

    :ok
  end

  test "signed-agent routes reject unsigned requests", %{conn: conn} do
    Enum.each(@signed_agent_routes, fn {method, path, body} ->
      response =
        conn
        |> recycle()
        |> call_route(method, path, body)
        |> json_response(401)

      assert response["statusMessage"] == "Signed agent authentication failed"
    end)
  end

  test "session-backed write routes require csrf", %{conn: conn} do
    Enum.each(@csrf_write_routes, fn {method, path, body} ->
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn
        |> recycle()
        |> init_test_session(%{})
        |> call_route(method, path, body)
      end
    end)
  end

  test "public report write remains rate limited", %{conn: conn} do
    Enum.each(1..12, fn index ->
      conn
      |> recycle()
      |> post("/api/bug-report", %{"summary" => "report #{index}", "details" => "details"})
      |> json_response(200)
    end)

    response =
      conn
      |> recycle()
      |> post("/api/bug-report", %{"summary" => "report 13", "details" => "details"})
      |> json_response(429)

    assert response["statusMessage"] == "Too many requests. Try again shortly."
  end

  defp call_route(conn, :get, path, _body), do: get(conn, path)
  defp call_route(conn, :post, path, body), do: post(conn, path, body)
  defp call_route(conn, :put, path, body), do: put(conn, path, body)
  defp call_route(conn, :delete, path, body), do: delete(conn, path, body)
end
