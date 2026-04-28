defmodule PlatformPhx.Runners.CodexExecTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.RunEvents
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhx.Workflows
  alias PlatformPhx.Workspaces
  alias PlatformPhx.Workers.CodexExecRunJob
  alias PlatformPhx.Workers.FakeRunJob
  alias PlatformPhx.Workers.StartWorkRunJob

  setup do
    previous_client = Application.get_env(:platform_phx, :codex_exec_client)
    previous_sprites_client = Application.get_env(:platform_phx, :runtime_registry_sprites_client)
    Application.put_env(:platform_phx, :codex_exec_client, __MODULE__.Client)

    on_exit(fn ->
      restore_app_env(:platform_phx, :codex_exec_client, previous_client)
      restore_app_env(:platform_phx, :runtime_registry_sprites_client, previous_sprites_client)
      Application.delete_env(:platform_phx, :codex_exec_client_result)
    end)

    :ok
  end

  test "codex_exec runner records mapped events and completes the run" do
    %{company: company, run: run} = run_fixture("codex_exec")
    configure_client_success()

    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})

    completed_run = Repo.get!(WorkRun, run.id)
    assert completed_run.status == "waiting_for_approval"
    assert completed_run.summary == "Codex finished the assigned work."

    events = RunEvents.list_events(company.id, run.id)
    assert Enum.map(events, & &1.sequence) == [1, 2, 3, 4, 5]

    assert Enum.map(events, & &1.kind) == [
             "run.started",
             "codex.message",
             "codex.step.completed",
             "artifact.created",
             "run.human_review"
           ]

    assert Enum.at(events, 1).payload == %{
             "message" => "Read the work request.",
             "secret_note" => "[redacted]"
           }

    assert File.read!(Path.join(run.workspace_path, Workspaces.prompt_file())) =~
             "Record Codex proof"
  end

  test "successful Codex run creates an operator-only proof artifact" do
    %{run: run} = run_fixture("codex_exec")
    configure_client_success()

    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})

    artifact = Repo.get_by!(WorkArtifact, run_id: run.id, kind: "proof_packet")
    assert artifact.visibility == "operator"
    assert artifact.attestation_level == "platform_observed"
    assert artifact.title == "Codex proof"
    assert artifact.content_inline =~ "Codex completed the work and reported proof."
    assert artifact.content_inline =~ "Changed files:"
    assert artifact.content_inline =~ "proof.txt"
    assert artifact.metadata["proof_source"] == "codex_exec"
    assert artifact.metadata["runner_kind"] == "codex_exec"
  end

  test "codex_app_server uses the hosted Codex runner path" do
    %{run: run} = run_fixture("codex_app_server")
    configure_client_success()

    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})

    completed_run = Repo.get!(WorkRun, run.id)
    assert completed_run.status == "waiting_for_approval"

    artifact = Repo.get_by!(WorkArtifact, run_id: run.id, kind: "proof_packet")
    assert artifact.metadata["runner_kind"] == "codex_app_server"
  end

  test "Codex client failure appends a failure event and marks the run failed" do
    %{company: company, run: run} = run_fixture("codex_exec")

    Application.put_env(
      :platform_phx,
      :codex_exec_client_result,
      {:error, "Codex client unavailable"}
    )

    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})

    failed_run = Repo.get!(WorkRun, run.id)
    assert failed_run.status == "failed"
    assert failed_run.failure_reason == "Codex client unavailable"

    assert Enum.map(RunEvents.list_events(company.id, run.id), & &1.kind) == [
             "run.started",
             "run.failed"
           ]
  end

  test "retrying a failed codex_exec run does not duplicate the failure event" do
    %{company: company, run: run} = run_fixture("codex_exec")

    Application.put_env(
      :platform_phx,
      :codex_exec_client_result,
      {:error, "Codex client unavailable"}
    )

    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})
    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})

    assert Enum.map(RunEvents.list_events(company.id, run.id), & &1.kind) == [
             "run.started",
             "run.failed"
           ]
  end

  test "retrying a reviewed codex_exec run does not duplicate events or artifacts" do
    %{company: company, run: run} = run_fixture("codex_exec")
    configure_client_success()

    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})
    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})

    assert RunEvents.list_events(company.id, run.id) |> Enum.map(& &1.kind) == [
             "run.started",
             "codex.message",
             "codex.step.completed",
             "artifact.created",
             "run.human_review"
           ]

    artifact_count =
      WorkArtifact
      |> where([artifact], artifact.run_id == ^run.id and artifact.kind == "proof_packet")
      |> Repo.aggregate(:count)

    assert artifact_count == 1
  end

  test "prompt rendering uses REGENT_WORKFLOW.md frontmatter and context" do
    workflow = """
    ---
    name: codex-proof
    review_required: false
    labels:
      - proof
    ---
    Finish {{ work_item.title }} in {{ workspace.path }} for run {{ run.id }}.
    """

    assert {:ok, loaded} = Workflows.parse(workflow)
    assert loaded.config["name"] == "codex-proof"
    assert loaded.config["review_required"] == false
    assert loaded.config["labels"] == ["proof"]

    assert {:ok, prompt} =
             Workflows.symphony_prompt(loaded, %{
               "work_item" => %{"title" => "Collect proof"},
               "workspace" => %{"path" => "/tmp/regent"},
               "run" => %{"id" => 42}
             })

    assert prompt =~ "Finish Collect proof in /tmp/regent for run 42."
    assert prompt =~ "# Regent Workflow"
  end

  test "local workspace collection records changed files, patch, and test output" do
    path = unique_workspace_path("workspace-collection")
    File.mkdir_p!(path)
    System.cmd("git", ["init"], cd: path)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: path)
    System.cmd("git", ["config", "user.name", "Regent Test"], cd: path)
    File.write!(Path.join(path, "tracked.txt"), "before\n")
    System.cmd("git", ["add", "tracked.txt"], cd: path)
    System.cmd("git", ["commit", "-m", "seed"], cd: path)

    File.write!(Path.join(path, "tracked.txt"), "after\n")
    File.write!(Path.join(path, "new.txt"), "new\n")
    File.write!(Path.join(path, Workspaces.test_output_file()), "mix test passed\n")

    assert {:ok, collected} = Workspaces.Local.collect(%{path: path})
    assert "tracked.txt" in collected.changed_files
    assert "new.txt" in collected.changed_files
    assert collected.patch =~ "-before"
    assert collected.patch =~ "+after"
    assert collected.test_output == "mix test passed\n"
  end

  test "sprite workspace uses the Runtime Registry Sprites client" do
    %{run: run, company: company} = run_fixture("codex_exec")

    {:ok, runtime} =
      RuntimeRegistry.create_runtime_profile(%{
        company_id: company.id,
        name: "Hosted Sprite",
        runner_kind: "codex_exec",
        execution_surface: "hosted_sprite",
        billing_mode: "platform_hosted",
        provider_runtime_id: "sprite-workspace-test"
      })

    run =
      run
      |> WorkRun.changeset(%{runtime_profile_id: runtime.id, workspace_path: nil})
      |> Repo.update!()

    Application.put_env(
      :platform_phx,
      :runtime_registry_sprites_client,
      __MODULE__.SpritesClient
    )

    assert {:ok, workspace} = Workspaces.prepare(run)
    assert workspace.kind == :sprite
    assert workspace.provider_runtime_id == "sprite-workspace-test"

    assert {:ok, workflow} = Workspaces.load_workflow(workspace)
    assert workflow.config["review_required"] == true

    assert {:ok, prompted} = Workspaces.write_prompt(workspace, "hello sprite")
    assert prompted.prompt_path =~ Workspaces.prompt_file()

    assert {:ok, collected} = Workspaces.collect(workspace)
    assert collected.changed_files == ["remote.txt", "new.txt"]
    assert collected.patch =~ "diff --git"
    assert collected.test_output == "mix test passed\n"
  end

  test "Codex success without human review marks the run succeeded" do
    %{company: company, run: run} = run_fixture("codex_exec", review_required: false)
    configure_client_success()

    assert :ok = perform_job(CodexExecRunJob, %{run_id: run.id})

    completed_run = Repo.get!(WorkRun, run.id)
    assert completed_run.status == "completed"
    assert completed_run.metadata["codex_exec_outcome"] == "succeeded"

    assert Enum.map(RunEvents.list_events(company.id, run.id), & &1.kind) == [
             "run.started",
             "codex.message",
             "codex.step.completed",
             "artifact.created",
             "run.succeeded"
           ]
  end

  test "dispatcher routes hosted Codex kinds and still routes fake" do
    %{run: codex_run} = run_fixture("codex_exec")
    %{run: codex_app_server_run} = run_fixture("codex_app_server")
    %{run: fake_run} = run_fixture("fake")

    assert :ok = perform_job(StartWorkRunJob, %{run_id: codex_run.id})
    assert_enqueued(worker: CodexExecRunJob, args: %{run_id: codex_run.id})

    assert :ok = perform_job(StartWorkRunJob, %{run_id: codex_app_server_run.id})
    assert_enqueued(worker: CodexExecRunJob, args: %{run_id: codex_app_server_run.id})

    assert :ok = perform_job(StartWorkRunJob, %{run_id: fake_run.id})
    assert_enqueued(worker: FakeRunJob, args: %{run_id: fake_run.id})
  end

  defmodule Client do
    def run(%{workspace: workspace}) do
      File.write!(Path.join(workspace.path, "proof.txt"), "proof\n")

      File.write!(
        Path.join(workspace.path, PlatformPhx.Workspaces.test_output_file()),
        "mix test passed\n"
      )

      Application.fetch_env!(:platform_phx, :codex_exec_client_result)
    end
  end

  defmodule SpritesClient do
    @behaviour PlatformPhx.RuntimeRegistry.SpritesClient

    def list_services(_runtime_id), do: {:ok, []}
    def get_service(_runtime_id, service_name), do: {:ok, %{"name" => service_name}}
    def create_service(_runtime_id, attrs), do: {:ok, attrs}
    def start_service(_runtime_id, service_name), do: {:ok, %{"name" => service_name}}
    def stop_service(_runtime_id, service_name), do: {:ok, %{"name" => service_name}}
    def service_status(_runtime_id, service_name), do: {:ok, %{"name" => service_name}}
    def service_logs(_runtime_id, _service_name, _opts), do: {:ok, %{}}
    def create_runtime(attrs), do: {:ok, attrs}
    def get_runtime(runtime_id), do: {:ok, %{"id" => runtime_id}}
    def create_checkpoint(_runtime_id, attrs), do: {:ok, attrs}

    def restore_checkpoint(_runtime_id, checkpoint_ref),
      do: {:ok, %{"checkpoint_ref" => checkpoint_ref}}

    def observe_capacity(_runtime_id), do: {:ok, %{}}

    def exec(_runtime_id, %{"command" => command}) do
      cond do
        String.contains?(command, Workspaces.test_output_file()) ->
          {:ok, %{"stdout" => "mix test passed\n"}}

        String.starts_with?(command, "cat ") ->
          {:ok,
           %{
             "stdout" => """
             ---
             name: sprite-workspace-test
             review_required: true
             ---
             Complete {{ work_item.title }}.
             """
           }}

        String.contains?(command, "git status") ->
          {:ok, %{"stdout" => " M remote.txt\n?? new.txt\n"}}

        String.contains?(command, "git diff") ->
          {:ok, %{"stdout" => "diff --git a/remote.txt b/remote.txt\n"}}

        true ->
          {:ok, %{"stdout" => ""}}
      end
    end
  end

  defp configure_client_success do
    Application.put_env(:platform_phx, :codex_exec_client_result, {
      :ok,
      %{
        events: [
          %{
            kind: "codex.message",
            payload: %{
              message: "Read the work request.",
              secret_note: "sk-test-secret"
            }
          },
          %{
            kind: "codex.step.completed",
            payload: %{step: "implementation"}
          }
        ],
        proof_title: "Codex proof",
        proof: "Codex completed the work and reported proof.",
        summary: "Codex finished the assigned work."
      }
    })
  end

  defp run_fixture(runner_kind, opts \\ []) do
    key = System.unique_integer([:positive])
    human = insert_human!(key)
    company = insert_company!(human, "codex-runner-#{runner_kind}-#{key}")
    workspace_path = unique_workspace_path("codex-runner-#{runner_kind}-#{key}")
    File.mkdir_p!(workspace_path)
    File.write!(Path.join(workspace_path, Workflows.workflow_file()), workflow_file(opts))
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
        title: "Check Codex run lifecycle"
      })

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        goal_id: goal.id,
        budget_policy_id: budget.id,
        title: "Record Codex proof",
        desired_runner_kind: runner_kind
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        runner_kind: runner_kind,
        workspace_path: workspace_path
      })

    %{company: company, run: run}
  end

  defp workflow_file(opts) do
    review_required = Keyword.get(opts, :review_required, true)

    """
    ---
    name: codex-runner-test
    review_required: #{review_required}
    ---
    Complete {{ work_item.title }}.

    {{ work_item.body }}
    """
  end

  defp unique_workspace_path(prefix) do
    Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-codex-runner-#{key}",
      wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      wallet_addresses: ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"]
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, slug) do
    {:ok, company} =
      AgentPlatform.create_company(human, %{
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
