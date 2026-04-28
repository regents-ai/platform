defmodule PlatformPhx.Budgets do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentRegistry.AgentWorker
  alias PlatformPhx.Approvals
  alias PlatformPhx.Repo
  alias PlatformPhx.Work
  alias PlatformPhx.Work.BudgetPolicy
  alias PlatformPhx.Work.WorkItem
  alias PlatformPhx.WorkRuns.WorkRun

  def create_policy(attrs), do: Work.create_budget_policy(attrs)

  def check_run_request(attrs), do: evaluate_request(attrs, "run")

  def check_delegation_request(attrs), do: evaluate_request(attrs, "delegation")

  def authorize_delegation(parent_run, payload, actor_context) do
    check_delegation(parent_run, payload, actor_context)
  end

  def check_delegation(parent_run, payload, actor_context) do
    parent_run
    |> delegation_attrs(payload, actor_context)
    |> check_delegation_request()
    |> normalize_check_result()
  end

  def hosted_compute?(attrs) do
    case billing_mode(attrs) do
      "platform_hosted" -> true
      _mode -> false
    end
  end

  defp evaluate_request(attrs, request_kind) do
    attrs = Map.new(attrs)

    with :ok <- protected_work_result(attrs) do
      if hosted_compute?(attrs) do
        evaluate_hosted_budget(attrs, request_kind)
      else
        {:ok,
         %{
           decision: "allowed",
           request_kind: request_kind,
           billing_mode: billing_mode(attrs),
           hosted_compute: false,
           usage_accounting: "self_reported"
         }}
      end
    end
  end

  defp protected_work_result(attrs) do
    case protected_action(attrs) do
      nil ->
        :ok

      action ->
        approval_required(
          attrs,
          "protected_work",
          "This work needs approval before it can continue.",
          %{
            "protected_action" => action
          }
        )
    end
  end

  defp evaluate_hosted_budget(attrs, request_kind) do
    policy = budget_policy(attrs)

    cond do
      is_nil(policy) ->
        {:ok,
         %{
           decision: "allowed",
           request_kind: request_kind,
           billing_mode: "platform_hosted",
           hosted_compute: true,
           policy_id: nil
         }}

      policy.status != "active" ->
        {:rejected,
         %{
           reason: "budget_policy_not_active",
           policy_id: policy.id
         }}

      exceeds_hard_budget?(attrs, policy) ->
        {:rejected,
         %{
           reason: "budget_limit_exceeded",
           policy_id: policy.id
         }}

      approval_over_budget?(attrs, policy) ->
        approval_required(
          attrs,
          "budget_over_limit",
          "This hosted work is above the approval limit.",
          %{
            "policy_id" => policy.id,
            "estimated_cost_usd" => decimal_string(estimated_cost(attrs))
          }
        )

      exceeds_child_run_limit?(attrs, policy) ->
        approval_required(
          attrs,
          "budget_child_run_limit",
          "This delegation would add more child runs than the budget allows.",
          %{"policy_id" => policy.id}
        )

      true ->
        {:ok,
         %{
           decision: "allowed",
           request_kind: request_kind,
           billing_mode: "platform_hosted",
           hosted_compute: true,
           usage_accounting: "platform_metered",
           policy_id: policy.id
         }}
    end
  end

  defp approval_required(attrs, kind, risk_summary, payload) do
    case Approvals.request(%{
           company_id: attr(attrs, :company_id),
           work_run_id: attr(attrs, :work_run_id),
           kind: kind,
           requested_by_actor_kind: attr(attrs, :requested_by_actor_kind) || "worker",
           requested_by_actor_id: attr(attrs, :requested_by_actor_id),
           risk_summary: risk_summary,
           payload: payload
         }) do
      {:ok, approval} ->
        {:approval_required,
         %{
           reason: kind,
           approval_request: approval,
           risk_summary: risk_summary
         }}

      {:error, :work_run_required} ->
        {:approval_required,
         %{
           reason: kind,
           approval_request: nil,
           risk_summary: risk_summary,
           payload: payload
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp exceeds_hard_budget?(attrs, policy) do
    exceeds_decimal?(estimated_cost(attrs), policy.max_cost_usd_per_run) or
      exceeds_integer?(estimated_runtime_minutes(attrs), policy.max_runtime_minutes_per_run)
  end

  defp approval_over_budget?(attrs, policy) do
    exceeds_decimal?(estimated_cost(attrs), policy.requires_approval_over_usd)
  end

  defp exceeds_child_run_limit?(_attrs, %BudgetPolicy{max_child_runs_per_root_run: nil}),
    do: false

  defp exceeds_child_run_limit?(attrs, %BudgetPolicy{max_child_runs_per_root_run: limit}) do
    case attr(attrs, :root_run_id) do
      nil ->
        false

      root_run_id ->
        existing_count =
          WorkRun
          |> where([run], run.root_run_id == ^root_run_id or run.parent_run_id == ^root_run_id)
          |> Repo.aggregate(:count)

        existing_count + requested_child_run_count(attrs) > limit
    end
  end

  defp requested_child_run_count(attrs) do
    cond do
      is_integer(attr(attrs, :requested_child_run_count)) ->
        max(attr(attrs, :requested_child_run_count), 1)

      is_list(attr(attrs, :tasks)) ->
        max(length(attr(attrs, :tasks)), 1)

      true ->
        1
    end
  end

  defp budget_policy(attrs) do
    cond do
      policy_id = attr(attrs, :budget_policy_id) ->
        Repo.get(BudgetPolicy, policy_id)

      work_item_id = attr(attrs, :work_item_id) ->
        case Repo.get(WorkItem, work_item_id) do
          %WorkItem{budget_policy_id: policy_id} when not is_nil(policy_id) ->
            Repo.get(BudgetPolicy, policy_id)

          _item ->
            active_company_policy(attr(attrs, :company_id))
        end

      true ->
        active_company_policy(attr(attrs, :company_id))
    end
  end

  defp active_company_policy(nil), do: nil

  defp active_company_policy(company_id) do
    BudgetPolicy
    |> where(
      [policy],
      policy.company_id == ^company_id and policy.scope_kind == "company" and
        policy.status == "active"
    )
    |> order_by([policy], desc: policy.updated_at, desc: policy.id)
    |> limit(1)
    |> Repo.one()
  end

  defp delegation_attrs(parent_run, payload, actor_context) do
    payload = Map.new(payload || %{})
    actor_context = Map.new(actor_context || %{})
    worker = Map.get(parent_run, :worker)

    %{
      company_id: parent_run.company_id,
      work_run_id: parent_run.id,
      work_item_id: parent_run.work_item_id,
      root_run_id: parent_run.root_run_id || parent_run.id,
      worker_id: worker && worker.id,
      billing_mode: worker && worker.billing_mode,
      requested_by_actor_kind: attr(actor_context, :actor_kind) || "worker",
      requested_by_actor_id: attr(actor_context, :worker_id),
      requested_runner_kind: attr(payload, :requested_runner_kind),
      requested_child_run_count: requested_child_run_count(%{tasks: attr(payload, :tasks)}),
      tasks: attr(payload, :tasks),
      estimated_cost_usd: estimated_cost_from_payload(payload),
      action: attr(payload, :action)
    }
  end

  defp estimated_cost_from_payload(payload) do
    case attr(payload, :budget_limit_usd_cents) do
      cents when is_integer(cents) -> Decimal.div(Decimal.new(cents), Decimal.new(100))
      _other -> attr(payload, :estimated_cost_usd) || Decimal.new("0")
    end
  end

  defp normalize_check_result(:ok), do: :ok
  defp normalize_check_result({:ok, _details}), do: :ok

  defp normalize_check_result({:approval_required, details}),
    do: {:error, {:approval_required, details}}

  defp normalize_check_result({:rejected, details}), do: {:error, {:delegation_rejected, details}}
  defp normalize_check_result({:error, reason}), do: {:error, reason}

  defp billing_mode(attrs) do
    cond do
      mode = attr(attrs, :billing_mode) ->
        mode

      worker_id = attr(attrs, :worker_id) ->
        case Repo.get(AgentWorker, worker_id) do
          %AgentWorker{billing_mode: mode} -> mode
          nil -> nil
        end

      true ->
        nil
    end
  end

  defp protected_action(attrs) do
    actions = protected_actions(attrs)

    attrs
    |> requested_actions()
    |> Enum.find(&(&1 in actions))
  end

  defp requested_actions(attrs) do
    direct_requested_actions(attrs) ++ task_requested_actions(attr(attrs, :tasks))
  end

  defp direct_requested_actions(attrs) when is_map(attrs) do
    [
      attr(attrs, :action),
      attr(attrs, :requested_action),
      attr(attrs, :protected_action)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp direct_requested_actions(_attrs), do: []

  defp task_requested_actions(tasks) when is_list(tasks) do
    Enum.flat_map(tasks, fn
      task when is_map(task) ->
        direct_requested_actions(task) ++ direct_requested_actions(attr(task, :metadata) || %{})

      _task ->
        []
    end)
  end

  defp task_requested_actions(_tasks), do: []

  defp protected_actions(attrs) do
    policy_actions =
      case budget_policy(attrs) do
        %BudgetPolicy{protected_actions: actions} -> actions
        nil -> []
      end

    Enum.uniq(policy_actions ++ default_protected_actions())
  end

  defp default_protected_actions do
    [
      "deploy",
      "billing_change",
      "contract_deploy",
      "money_movement",
      "auth_boundary_change",
      "secret_grant"
    ]
  end

  defp estimated_cost(attrs), do: decimal(attr(attrs, :estimated_cost_usd) || "0")
  defp estimated_runtime_minutes(attrs), do: attr(attrs, :estimated_runtime_minutes)

  defp exceeds_decimal?(_value, nil), do: false
  defp exceeds_decimal?(value, limit), do: Decimal.compare(value, decimal(limit)) == :gt

  defp exceeds_integer?(nil, _limit), do: false
  defp exceeds_integer?(_value, nil), do: false
  defp exceeds_integer?(value, limit), do: value > limit

  defp decimal(%Decimal{} = value), do: value
  defp decimal(value) when is_integer(value), do: Decimal.new(value)
  defp decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp decimal(value) when is_binary(value), do: Decimal.new(value)

  defp decimal_string(%Decimal{} = value), do: Decimal.to_string(value, :normal)

  defp attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end
end
