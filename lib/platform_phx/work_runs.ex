defmodule PlatformPhx.WorkRuns do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.Repo
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.Orchestration.ChildRunFanout
  alias PlatformPhx.WorkRuns.ApprovalRequest
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhx.Workers.StartWorkRunJob
  alias Oban

  def create_run(attrs) do
    %WorkRun{}
    |> WorkRun.changeset(attrs)
    |> Repo.insert()
  end

  def get_run(company_id, run_id) do
    WorkRun
    |> where([run], run.company_id == ^company_id and run.id == ^run_id)
    |> Repo.one()
  end

  def get_run(run_id), do: Repo.get(WorkRun, run_id)

  def get_owned_run(human_id, run_id) do
    WorkRun
    |> join(:inner, [run], company in Company, on: company.id == run.company_id)
    |> where([run, company], company.owner_human_id == ^human_id and run.id == ^run_id)
    |> preload([
      :company,
      :work_item,
      :worker,
      :runtime_profile,
      :parent_run,
      :root_run,
      :delegated_by_run
    ])
    |> Repo.one()
  end

  def list_runs_for_work_items(work_item_ids) when is_list(work_item_ids) do
    WorkRun
    |> where([run], run.work_item_id in ^work_item_ids)
    |> order_by([run], desc: run.updated_at, desc: run.id)
    |> preload([:worker, :runtime_profile])
    |> Repo.all()
  end

  def list_child_runs(run_id) do
    WorkRun
    |> where([run], run.parent_run_id == ^run_id)
    |> order_by([run], asc: run.created_at, asc: run.id)
    |> preload([:worker, :runtime_profile])
    |> Repo.all()
  end

  def enqueue_start(%WorkRun{} = run, opts \\ []) do
    oban_module = Keyword.get(opts, :oban_module, Oban)

    %{run_id: run.id}
    |> StartWorkRunJob.new()
    |> oban_module.insert()
  end

  def mark_running(%WorkRun{status: "completed"} = run), do: {:ok, run}
  def mark_running(%WorkRun{status: "running"} = run), do: {:ok, run}

  def mark_running(%WorkRun{} = run) do
    run
    |> WorkRun.changeset(%{
      status: "running",
      started_at: run.started_at || now(),
      completed_at: nil,
      failure_reason: nil
    })
    |> Repo.update()
  end

  def complete_run(%WorkRun{} = run, attrs \\ %{}) do
    with {:ok, run} <-
           run
           |> WorkRun.changeset(
             Map.merge(
               %{
                 status: "completed",
                 completed_at: now(),
                 failure_reason: nil
               },
               attrs
             )
           )
           |> Repo.update(),
         {:ok, run} <- ChildRunFanout.maybe_append(run) do
      {:ok, run}
    end
  end

  def request_human_review(%WorkRun{} = run, attrs \\ %{}) do
    run
    |> WorkRun.changeset(
      Map.merge(
        %{
          status: "waiting_for_approval",
          completed_at: now(),
          failure_reason: nil
        },
        attrs
      )
    )
    |> Repo.update()
  end

  def cancel_run(%WorkRun{} = run) do
    run
    |> WorkRun.changeset(%{
      status: "canceled",
      completed_at: now()
    })
    |> Repo.update()
  end

  def fail_run(%WorkRun{} = run, reason, attrs \\ %{}) do
    with {:ok, run} <-
           run
           |> WorkRun.changeset(
             Map.merge(
               %{
                 status: "failed",
                 completed_at: now(),
                 failure_reason: reason
               },
               attrs
             )
           )
           |> Repo.update(),
         {:ok, run} <- ChildRunFanout.maybe_append(run) do
      {:ok, run}
    end
  end

  def create_artifact(attrs) do
    %WorkArtifact{}
    |> WorkArtifact.changeset(attrs)
    |> Repo.insert()
  end

  def list_artifacts(company_id, run_id) do
    WorkArtifact
    |> where([artifact], artifact.company_id == ^company_id and artifact.run_id == ^run_id)
    |> order_by([artifact], desc: artifact.updated_at, desc: artifact.id)
    |> Repo.all()
  end

  def get_artifact_by_run_and_kind(run_id, kind) do
    Repo.get_by(WorkArtifact, run_id: run_id, kind: kind)
  end

  def publish_artifact(%WorkArtifact{visibility: "public"} = artifact), do: {:ok, artifact}

  def publish_artifact(%WorkArtifact{} = artifact) do
    artifact
    |> WorkArtifact.changeset(%{visibility: "public"})
    |> Repo.update()
  end

  def create_approval_request(attrs) do
    %ApprovalRequest{}
    |> ApprovalRequest.changeset(attrs)
    |> Repo.insert()
  end

  def resolve_approval_request(%ApprovalRequest{} = approval, attrs) do
    approval
    |> ApprovalRequest.changeset(attrs)
    |> Repo.update()
  end

  def list_approval_requests(company_id, run_id) do
    ApprovalRequest
    |> where([request], request.company_id == ^company_id and request.work_run_id == ^run_id)
    |> order_by([request], desc: request.updated_at, desc: request.id)
    |> Repo.all()
  end

  defp now, do: PlatformPhx.Clock.now()
end
