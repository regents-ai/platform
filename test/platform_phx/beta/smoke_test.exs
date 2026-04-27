defmodule PlatformPhx.Beta.SmokeTest do
  use ExUnit.Case, async: false

  alias PlatformPhx.Beta.Smoke

  test "checks public pages, configured company page, and signed staking" do
    result =
      Smoke.run(
        host: "https://platform.example/",
        company_slug: "hermes",
        env: %{"AGENT_FORMATION_ENABLED" => "false", "PLATFORM_BETA_SIWA_RECEIPT" => "receipt"},
        http_client: __MODULE__.HttpClient,
        mobile?: false
      )

    assert result.status == "pass"
    assert result.host == "https://platform.example"
    assert check_status(result, "home") == "pass"
    assert check_status(result, "disabled_beta_actions") == "pass"
    assert check_status(result, "public_company_page") == "pass"
    assert check_status(result, "staking_api") == "pass"
    assert check_status(result, "mobile_browser") == "not_included"
  end

  test "does not require disabled action copy when company opening is enabled" do
    result =
      Smoke.run(
        host: "https://platform.example",
        env: %{"AGENT_FORMATION_ENABLED" => "true"},
        http_client: __MODULE__.HttpClient,
        mobile?: false
      )

    assert result.status == "pass"
    assert check_status(result, "disabled_beta_actions") == "not_included"
  end

  test "marks mobile smoke blocked when requested without Chromium" do
    result =
      Smoke.run(
        host: "https://platform.example",
        env: %{},
        http_client: __MODULE__.HttpClient,
        mobile?: true
      )

    assert result.status == "blocked"
    assert check_status(result, "mobile_browser") == "blocked"
  end

  defp check_status(result, name) do
    result.checks
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:status)
  end

  defmodule HttpClient do
    def get(url, _opts) do
      uri = URI.parse(url)

      cond do
        uri.path == "/" ->
          {:ok, %{status: 200, body: "<html>Regents</html>"}}

        uri.path == "/cli" ->
          {:ok, %{status: 200, body: "<html>Regents CLI</html>"}}

        uri.path == "/docs" ->
          {:ok, %{status: 200, body: "<html>Docs</html>"}}

        uri.path == "/token-info" ->
          {:ok, %{status: 200, body: "<html>$REGENT staking</html>"}}

        uri.path == "/app/billing" ->
          {:ok,
           %{
             status: 200,
             body: "<html>Hosted company billing is not available right now.</html>"
           }}

        uri.path == "/app/formation" ->
          {:ok,
           %{
             status: 200,
             body: "<html>Hosted company opening is not available right now.</html>"
           }}

        uri.path == "/v1/agent/regent/staking" ->
          {:ok, %{status: 200, body: %{"ok" => true}}}

        String.starts_with?(uri.path, "/agents/") ->
          {:ok, %{status: 200, body: "<html>Company</html>"}}

        true ->
          {:ok, %{status: 200, body: "<html>Page</html>"}}
      end
    end
  end
end
