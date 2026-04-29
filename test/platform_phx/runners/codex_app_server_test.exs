defmodule PlatformPhx.Runners.CodexAppServerTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.RunEvents
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhx.Workflows
  alias PlatformPhx.Workers.CodexExecRunJob

  setup do
    previous_client = Application.get_env(:platform_phx, :codex_app_server_client)
    Application.put_env(:platform_phx, :codex_app_server_client, __MODULE__.Client)

    on_exit(fn ->
      restore_app_env(:platform_phx, :codex_app_server_client, previous_client)
      Application.delete_env(:platform_phx, :codex_app_server_client_result)
    end)

    :ok
  end

  test "codex_app_server runs through its own client and records app-server proof" do
    %{company: company, run: run} = run_fixture()

    Application.put_env(:platform_phx, :codex_app_server_client_result, {
      :ok,
      %{
        stdout: "App Server streamed stdout.\n",
        stderr: "App Server streamed stderr.\n",
        proof_title: "Codex App Server proof",
        summary: "Codex App Server finished the assigned work."
      }
    })

    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})

    completed_run = Repo.get!(WorkRun, run.id)
    assert completed_run.status == "waiting_for_approval"
    assert completed_run.summary == "Codex App Server finished the assigned work."

    assert Enum.map(RunEvents.list_events(company.id, run.id), & &1.kind) == [
             "run.started",
             "codex.stdout",
             "codex.stderr",
             "artifact.created",
             "run.human_review"
           ]

    artifact = Repo.get_by!(WorkArtifact, run_id: run.id, kind: "proof_packet")
    assert artifact.title == "Codex App Server proof"
    assert artifact.metadata["runner_kind"] == "codex_app_server"
    assert artifact.metadata["proof_source"] == "codex_app_server"
  end

  test "default client opens a Codex app-server protocol session" do
    previous_command = Application.get_env(:platform_phx, :codex_app_server_command)

    on_exit(fn ->
      restore_app_env(:platform_phx, :codex_app_server_command, previous_command)
    end)

    workspace_path =
      Path.join(
        System.tmp_dir!(),
        "codex-app-server-protocol-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(workspace_path)
    script_path = Path.join(workspace_path, "fake-codex-app-server")

    File.write!(script_path, """
    #!/bin/sh
    while IFS= read -r line; do
      case "$line" in
        *'"method":"initialize"'*)
          echo '{"id":1,"result":{}}'
          ;;
        *'"method":"initialized"'*)
          ;;
        *'"method":"thread/start"'*)
          echo '{"id":2,"result":{"thread":{"id":"thread-test"}}}'
          ;;
        *'"method":"turn/start"'*)
          echo '{"id":3,"result":{"turn":{"id":"turn-test"}}}'
          echo '{"method":"agent/message","params":{"text":"Protocol proof from app-server."}}'
          echo '{"method":"turn/completed","params":{"output":"Protocol proof from app-server."}}'
          exit 0
          ;;
      esac
    done
    """)

    File.chmod!(script_path, 0o755)
    Application.put_env(:platform_phx, :codex_app_server_command, script_path)

    assert {:ok, result} =
             PlatformPhx.Runners.CodexAppServer.AppServerClient.run(%{
               workspace: %{path: workspace_path},
               prompt: "Protocol prompt",
               run: %{id: 123, work_item: %{title: "Protocol run"}}
             })

    assert result.stdout == "Protocol proof from app-server."
    assert result.proof == "Protocol proof from app-server."

    assert Enum.any?(
             result.events,
             &(get_in(&1, [:payload, :method]) == "turn/completed")
           )
  end

  defmodule Client do
    def run(%{workspace: workspace}) do
      File.write!(Path.join(workspace.path, "app-server-proof.txt"), "proof\n")
      Application.fetch_env!(:platform_phx, :codex_app_server_client_result)
    end
  end

  defp run_fixture do
    key = System.unique_integer([:positive])
    human = insert_human!(key)
    company = insert_company!(human, "codex-app-server-#{key}")
    workspace_path = Path.join(System.tmp_dir!(), "codex-app-server-#{key}")
    File.mkdir_p!(workspace_path)
    File.write!(Path.join(workspace_path, Workflows.workflow_file()), workflow_file())
    System.cmd("git", ["init"], cd: workspace_path)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: workspace_path)
    System.cmd("git", ["config", "user.name", "Regent Test"], cd: workspace_path)
    System.cmd("git", ["add", Workflows.workflow_file()], cd: workspace_path)
    System.cmd("git", ["commit", "-m", "seed workflow"], cd: workspace_path)

    {:ok, budget} =
      Work.create_budget_policy(%{
        company_id: company.id,
        scope_kind: "company",
        max_child_runs_per_root_run: 3
      })

    {:ok, goal} =
      Work.create_goal(%{
        company_id: company.id,
        budget_policy_id: budget.id,
        title: "Check App Server run"
      })

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        goal_id: goal.id,
        budget_policy_id: budget.id,
        title: "Record App Server proof",
        desired_runner_kind: "codex_app_server"
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        runner_kind: "codex_app_server",
        workspace_path: workspace_path
      })

    %{company: company, run: run}
  end

  defp workflow_file do
    """
    ---
    name: codex-app-server-test
    review_required: true
    ---
    Complete {{ work_item.title }}.
    """
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-codex-app-server-#{key}",
      wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      wallet_addresses: ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"]
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, slug) do
    {:ok, company} =
      PlatformPhx.AgentPlatform.Companies.create_company(human, %{
        name: "#{slug} Regent",
        slug: slug,
        claimed_label: slug,
        status: "forming",
        public_summary: "#{slug} summary"
      })

    company
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)
end
