defmodule PlatformPhxWeb.DiscoveryControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.Repo
  alias PlatformPhxWeb.Discovery

  test "robots.txt publishes crawl rules, AI rules, and the sitemap location", %{conn: conn} do
    conn = get(conn, "/robots.txt")
    body = response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
    assert body =~ "User-agent: *"
    assert body =~ "User-agent: GPTBot"
    assert body =~ "User-agent: OAI-SearchBot"
    assert body =~ "User-agent: Claude-Web"
    assert body =~ "User-agent: Google-Extended"
    assert body =~ "Content-Signal: search=yes, ai-input=yes, ai-train=yes"
    assert body =~ "Sitemap: http://localhost:4000/sitemap.xml"
  end

  test "sitemap.xml includes the public entry pages and live company home pages", %{conn: conn} do
    human = insert_human!("0x0000000000000000000000000000000000000001")
    _agent = insert_public_agent!(human, "discovery-test")

    conn = get(conn, "/sitemap.xml")
    body = response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["application/xml; charset=utf-8"]
    assert body =~ "<loc>http://localhost:4000/</loc>"
    assert body =~ "<loc>http://localhost:4000/app</loc>"
    assert body =~ "<loc>http://localhost:4000/cli</loc>"
    assert body =~ "<loc>http://localhost:4000/techtree</loc>"
    assert body =~ "<loc>http://localhost:4000/autolaunch</loc>"
    assert body =~ "<loc>http://discovery-test.regents.sh:4000/</loc>"
  end

  test "api catalog is published as linkset json", %{conn: conn} do
    conn = get(conn, "/.well-known/api-catalog")
    body = response(conn, 200) |> Jason.decode!()

    assert get_resp_header(conn, "content-type") == ["application/linkset+json; charset=utf-8"]
    assert is_list(body["linkset"])
    assert Enum.at(body["linkset"], 0)["anchor"] == "http://localhost:4000/api"

    assert Enum.at(body["linkset"], 0)["item"]
           |> Enum.any?(&(&1["href"] == "http://localhost:4000/docs"))
  end

  test "agent card, skills index, and mcp server card are published", %{conn: conn} do
    agent_card =
      conn
      |> recycle()
      |> get("/.well-known/agent-card.json")
      |> response(200)
      |> Jason.decode!()

    assert agent_card["name"] == "Regents Site Agent"
    assert agent_card["documentationUrl"] == "http://localhost:4000/docs"

    assert Enum.at(agent_card["skills"], 0)["url"] ==
             "http://localhost:4000/agent-skills/regents-cli.md"

    skill_index_conn =
      conn
      |> recycle()
      |> get("/.well-known/agent-skills/index.json")

    skill_index = response(skill_index_conn, 200) |> Jason.decode!()
    skill = Enum.at(skill_index["skills"], 0)

    assert skill["name"] == "Regents CLI"
    assert skill["sha256"] == Discovery.sha256_hex(Discovery.regents_cli_skill())

    mcp_card =
      conn
      |> recycle()
      |> get("/.well-known/mcp/server-card.json")
      |> response(200)
      |> Jason.decode!()

    assert mcp_card["serverInfo"]["name"] == "Regents Discovery"
    assert mcp_card["documentationUrl"] == "http://localhost:4000/docs"
    assert mcp_card["transports"] == []
  end

  test "health, contracts, and published skill are served from the app", %{conn: conn} do
    previous_dragonfly_enabled = Application.get_env(:platform_phx, :dragonfly_enabled)
    Application.put_env(:platform_phx, :dragonfly_enabled, false)

    on_exit(fn ->
      restore_app_env(:platform_phx, :dragonfly_enabled, previous_dragonfly_enabled)
    end)

    health_conn = get(conn, "/healthz")
    assert response(health_conn, 200) == "ok"
    assert get_resp_header(health_conn, "content-type") == ["text/plain; charset=utf-8"]

    ready_conn =
      conn
      |> recycle()
      |> get("/readyz")

    ready = json_response(ready_conn, 200)
    assert ready["status"] == "ready"
    assert ready["checks"]["database"] == "ready"
    assert ready["checks"]["cache"] in ["ready", "disabled"]
    refute Map.has_key?(ready, "launch")

    api_contract_conn =
      conn
      |> recycle()
      |> get("/api-contract.openapiv3.yaml")

    assert response(api_contract_conn, 200) =~ "openapi: 3.1.0"

    assert get_resp_header(api_contract_conn, "content-type") == [
             "application/yaml; charset=utf-8"
           ]

    cli_contract_conn =
      conn
      |> recycle()
      |> get("/cli-contract.yaml")

    assert response(cli_contract_conn, 200) =~ "title: Regents CLI Contract"

    assert get_resp_header(cli_contract_conn, "content-type") == [
             "application/yaml; charset=utf-8"
           ]

    skill_conn =
      conn
      |> recycle()
      |> get("/agent-skills/regents-cli.md")

    assert response(skill_conn, 200) =~ "# Regents CLI skill"
    assert get_resp_header(skill_conn, "content-type") == ["text/markdown; charset=utf-8"]
  end

  test "public entry pages publish discovery link headers", %{conn: conn} do
    conn = get(conn, "/")
    [link_header] = get_resp_header(conn, "link")

    assert link_header =~ ~s(</.well-known/api-catalog>; rel="api-catalog")
    assert link_header =~ ~s(</api-contract.openapiv3.yaml>; rel="service-desc")
    assert link_header =~ ~s(<http://localhost:4000/docs>; rel="service-doc")
  end

  test "public entry pages return markdown when requested", %{conn: conn} do
    home_conn =
      conn
      |> put_req_header("accept", "text/markdown")
      |> get("/")

    assert response(home_conn, 200) =~ "# Regents Labs"
    assert get_resp_header(home_conn, "content-type") == ["text/markdown; charset=utf-8"]

    cli_conn =
      conn
      |> recycle()
      |> put_req_header("accept", "text/markdown")
      |> get("/cli")

    assert response(cli_conn, 200) =~ "# Regents CLI"

    techtree_conn =
      conn
      |> recycle()
      |> put_req_header("accept", "text/markdown")
      |> get("/techtree")

    assert response(techtree_conn, 200) =~ "# Techtree"

    autolaunch_conn =
      conn
      |> recycle()
      |> put_req_header("accept", "text/markdown")
      |> get("/autolaunch")

    assert response(autolaunch_conn, 200) =~ "# Autolaunch"
  end

  test "public entry pages still return html by default", %{conn: conn} do
    conn = get(conn, "/")

    assert html_response(conn, 200) =~ "Regents Labs"
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
  end

  defp insert_human!(wallet_address) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: wallet_address,
      wallet_addresses: [wallet_address],
      display_name: "discovery@regents.sh"
    })
    |> Repo.insert!()
  end

  defp insert_public_agent!(human, slug) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        template_key: "start",
        name: "Discovery Regent",
        slug: slug,
        claimed_label: slug,
        basename_fqdn: "#{slug}.agent.base.eth",
        ens_fqdn: "#{slug}.regent.eth",
        status: "published",
        public_summary: "Public discovery test company.",
        hero_statement: "Discovery should publish the company home page.",
        runtime_status: "ready",
        checkpoint_status: "ready",
        stripe_llm_billing_status: "active",
        sprite_metering_status: "paid",
        wallet_address: human.wallet_address,
        published_at: now,
        desired_runtime_state: "active",
        observed_runtime_state: "active"
      })
      |> Repo.insert!()

    %Subdomain{}
    |> Subdomain.changeset(%{
      agent_id: agent.id,
      slug: slug,
      hostname: "#{slug}.regents.sh",
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: "#{slug}.regent.eth",
      active: true
    })
    |> Repo.insert!()

    agent
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)
end
