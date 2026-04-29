defmodule PlatformPhx.Workflows.Context do
  @moduledoc false

  @default_protected_actions [
    "deploy",
    "billing_change",
    "contract_deploy",
    "money_movement",
    "auth_boundary_change",
    "secret_grant"
  ]

  def build(run, workspace) do
    work_item = attr(run, :work_item)
    runtime_profile = attr(run, :runtime_profile)
    input = attr(run, :input) || %{}
    metadata = attr(run, :metadata) || %{}
    work_metadata = attr(work_item, :metadata) || %{}
    runtime_config = attr(runtime_profile, :config) || %{}
    runtime_metadata = attr(runtime_profile, :metadata) || %{}

    %{
      "run" => run_context(run, input, metadata),
      "work_item" => work_item_context(work_item, work_metadata),
      "runtime" => runtime_context(runtime_profile, runtime_config, runtime_metadata),
      "workspace" => workspace_context(workspace),
      "runner_policy" => runner_policy(run, runtime_profile, input, metadata),
      "delegation_policy" => delegation_policy(input, metadata, work_metadata, runtime_config),
      "techtree_publish_policy" => techtree_publish_policy(input, metadata, work_metadata),
      "protected_actions" => protected_actions(input, metadata, work_metadata, runtime_config),
      "visibility" => visibility(run, work_item, runtime_profile),
      "budget_notes" => budget_notes(input, metadata, work_metadata),
      "artifact_expectations" => artifact_expectations(input, metadata, work_metadata)
    }
  end

  defp run_context(run, input, metadata) do
    %{
      "id" => attr(run, :id),
      "runner_kind" => attr(run, :runner_kind),
      "parent_run_id" => attr(run, :parent_run_id),
      "root_run_id" => attr(run, :root_run_id) || attr(run, :id),
      "delegated_by_run_id" => attr(run, :delegated_by_run_id),
      "input" => input,
      "metadata" => metadata
    }
  end

  defp work_item_context(nil, _metadata) do
    %{
      "id" => nil,
      "title" => nil,
      "body" => nil,
      "acceptance_criteria" => [],
      "metadata" => %{}
    }
  end

  defp work_item_context(work_item, metadata) do
    %{
      "id" => attr(work_item, :id),
      "title" => attr(work_item, :title),
      "body" => attr(work_item, :body),
      "acceptance_criteria" => attr(work_item, :acceptance_criteria) || [],
      "desired_runner_kind" => attr(work_item, :desired_runner_kind),
      "metadata" => metadata
    }
  end

  defp runtime_context(runtime_profile, config, metadata) do
    %{
      "id" => attr(runtime_profile, :id),
      "name" => attr(runtime_profile, :name),
      "runner_kind" => attr(runtime_profile, :runner_kind),
      "execution_surface" => attr(runtime_profile, :execution_surface),
      "billing_mode" => attr(runtime_profile, :billing_mode),
      "visibility" => attr(runtime_profile, :visibility),
      "config" => config,
      "metadata" => metadata
    }
  end

  defp workspace_context(workspace) do
    %{
      "path" => attr(workspace, :path),
      "prompt_path" => attr(workspace, :prompt_path)
    }
  end

  defp runner_policy(run, runtime_profile, input, metadata) do
    configured =
      first_present([
        attr(input, :runner_policy),
        attr(metadata, :runner_policy),
        attr(runtime_profile, :config) |> attr(:runner_policy),
        attr(runtime_profile, :metadata) |> attr(:runner_policy)
      ]) || %{}

    Map.merge(
      %{
        "runner_kind" => attr(run, :runner_kind),
        "execution_surface" => attr(runtime_profile, :execution_surface),
        "billing_mode" => attr(runtime_profile, :billing_mode),
        "long_running" => true,
        "manager_trusted_within_budget" => true
      },
      normalize_map(configured)
    )
  end

  defp delegation_policy(input, metadata, work_metadata, runtime_config) do
    configured =
      first_present([
        attr(input, :delegation_policy),
        attr(metadata, :delegation_policy),
        attr(work_metadata, :delegation_policy),
        attr(runtime_config, :delegation_policy)
      ]) || %{}

    Map.merge(
      %{
        "manager_decides_task_count" => true,
        "human_approval_required_for_normal_spend" => false,
        "requires_approval_for_protected_actions" => true
      },
      normalize_map(configured)
    )
  end

  defp techtree_publish_policy(input, metadata, work_metadata) do
    first_present([
      attr(input, :techtree_publish_policy),
      attr(metadata, :techtree_publish_policy),
      attr(work_metadata, :techtree_publish_policy)
    ])
    |> normalize_optional_map()
  end

  defp protected_actions(input, metadata, work_metadata, runtime_config) do
    configured =
      [
        attr(input, :protected_actions),
        attr(metadata, :protected_actions),
        attr(work_metadata, :protected_actions),
        attr(runtime_config, :protected_actions)
      ]
      |> Enum.flat_map(&list/1)

    actions = Enum.uniq(configured ++ @default_protected_actions)

    %{
      "actions" => actions,
      "requires_explicit_approval" => true,
      "metadata" =>
        first_present([
          attr(input, :protected_action_metadata),
          attr(metadata, :protected_action_metadata),
          attr(work_metadata, :protected_action_metadata)
        ])
        |> normalize_optional_map()
    }
  end

  defp visibility(run, work_item, runtime_profile) do
    %{
      "run" => attr(run, :visibility),
      "work_item" => attr(work_item, :visibility),
      "runtime" => attr(runtime_profile, :visibility),
      "default_artifact_visibility" => "operator"
    }
  end

  defp budget_notes(input, metadata, work_metadata) do
    first_present([
      attr(input, :budget_notes),
      attr(metadata, :budget_notes),
      attr(work_metadata, :budget_notes)
    ])
    |> list()
  end

  defp artifact_expectations(input, metadata, work_metadata) do
    first_present([
      attr(input, :artifact_expectations),
      attr(metadata, :artifact_expectations),
      attr(work_metadata, :artifact_expectations)
    ])
    |> case do
      nil ->
        [
          "Record a proof packet with the work completed, changed files, and checks run."
        ]

      value ->
        list(value)
    end
  end

  defp first_present(values) do
    Enum.find(values, fn
      nil -> false
      "" -> false
      [] -> false
      %{} = map -> map_size(map) > 0
      _value -> true
    end)
  end

  defp list(nil), do: []
  defp list(value) when is_list(value), do: value
  defp list(value), do: [value]

  defp normalize_optional_map(nil), do: nil
  defp normalize_optional_map(value), do: normalize_map(value)

  defp normalize_map(value) when is_map(value) do
    Map.new(value, fn {key, val} -> {to_string(key), val} end)
  end

  defp normalize_map(_value), do: %{}

  defp attr(nil, _key), do: nil

  defp attr(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp attr(struct, key), do: Map.get(struct, key)
end
