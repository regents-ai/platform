defmodule PlatformPhx.Runners.FakeTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.RunEvents
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhx.Workers.FakeRunJob
  alias PlatformPhx.Workers.StartWorkRunJob

  test "start job dispatches fake run and fake run records ordered lifecycle events" do
    %{company: company, run: run} = run_fixture("fake")

    assert :ok = perform_job(StartWorkRunJob, %{run_id: run.id})
    assert_enqueued(worker: FakeRunJob, args: %{run_id: run.id})

    assert :ok = perform_job(FakeRunJob, %{run_id: run.id})

    events = RunEvents.list_events(company.id, run.id)

    assert Enum.map(events, & &1.sequence) == [1, 2, 3, 4]

    assert Enum.map(events, & &1.kind) == [
             "run.started",
             "run.message",
             "artifact.created",
             "run.completed"
           ]
  end

  test "fake run creates operator-only proof artifact and marks the run complete" do
    %{run: run} = run_fixture("fake")

    assert :ok = perform_job(FakeRunJob, %{run_id: run.id})

    completed_run = Repo.get!(WorkRun, run.id)
    assert completed_run.status == "completed"
    assert completed_run.completed_at
    assert completed_run.summary == "Fake run completed with a local proof artifact."

    artifact = Repo.get_by!(WorkArtifact, run_id: run.id, kind: "proof_packet")
    assert artifact.visibility == "operator"
    assert artifact.attestation_level == "platform_observed"
    assert artifact.metadata["proof_source"] == "fake_runner"
    assert artifact.metadata["runner_kind"] == "fake"
  end

  test "starting an unsupported run records unsupported runner and fails the run" do
    %{company: company, run: run} = run_fixture("custom_worker")

    assert :ok = perform_job(StartWorkRunJob, %{run_id: run.id})

    failed_run = Repo.get!(WorkRun, run.id)
    assert failed_run.status == "failed"
    assert failed_run.failure_reason == "unsupported runner kind: custom_worker"

    assert [%{kind: "run.unsupported_runner", payload: payload}] =
             RunEvents.list_events(company.id, run.id)

    assert payload == %{"runner_kind" => "custom_worker"}
  end

  test "retrying a completed fake run does not duplicate events or artifacts" do
    %{company: company, run: run} = run_fixture("fake")

    assert :ok = perform_job(FakeRunJob, %{run_id: run.id})
    assert :ok = perform_job(FakeRunJob, %{run_id: run.id})

    assert RunEvents.list_events(company.id, run.id) |> Enum.map(& &1.kind) == [
             "run.started",
             "run.message",
             "artifact.created",
             "run.completed"
           ]

    artifact_count =
      WorkArtifact
      |> where([artifact], artifact.run_id == ^run.id and artifact.kind == "proof_packet")
      |> Repo.aggregate(:count)

    assert artifact_count == 1
  end

  defp run_fixture(runner_kind) do
    key = System.unique_integer([:positive])
    human = insert_human!(key)
    company = insert_company!(human, "fake-runner-#{key}")

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
        title: "Check run lifecycle"
      })

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        goal_id: goal.id,
        budget_policy_id: budget.id,
        title: "Record proof",
        desired_runner_kind: runner_kind
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        runner_kind: runner_kind
      })

    %{company: company, run: run}
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-fake-runner-#{key}",
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
end
