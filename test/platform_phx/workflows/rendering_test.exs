defmodule PlatformPhx.Workflows.RenderingTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.Workflows

  test "parses nested workflow policy and includes it in prompts" do
    workflow = """
    ---
    kind: regent.workflow.v1
    runner:
      default: hermes_local_manager
    delegation:
      strategy: manager_decides
      allowed_executors:
        - codex_exec
        - openclaw_local_executor
    techtree:
      enabled: true
      publish_default: false
      allowed_publish_kinds:
        - node
        - marimo_notebook
    output:
      proof_packet: true
      techtree_publish_candidate: true
    ---
    Produce a proof packet for {{ work_item.title }}.
    """

    assert {:ok, parsed} = Workflows.parse(workflow)
    assert parsed.config["runner"]["default"] == "hermes_local_manager"

    assert parsed.config["delegation"]["allowed_executors"] == [
             "codex_exec",
             "openclaw_local_executor"
           ]

    assert parsed.config["techtree"]["allowed_publish_kinds"] == ["node", "marimo_notebook"]
    assert parsed.config["output"]["techtree_publish_candidate"] == true

    context =
      Workflows.prompt_context(
        %{
          id: 12,
          runner_kind: "codex_exec",
          input: %{},
          metadata: %{},
          work_item: %{title: "Publish candidate", metadata: %{}},
          runtime_profile: %{config: %{}, metadata: %{}}
        },
        %{path: "/workspace"}
      )

    assert {:ok, prompt} = Workflows.manager_prompt(parsed, context)
    assert prompt =~ "\"default\": \"hermes_local_manager\""
    assert prompt =~ "\"allowed_executors\": ["
    assert prompt =~ "\"enabled\": true"
    assert prompt =~ "\"publish_default\": false"
    assert prompt =~ "\"techtree_publish_candidate\": true"
  end

  test "renders manager and executor prompts with RWR policy metadata" do
    workflow = %{
      source: "REGENT_WORKFLOW.md",
      path: "/workspace/REGENT_WORKFLOW.md",
      config: %{},
      prompt_template: "Finish {{ work_item.title }} with {{ run.runner_kind }}."
    }

    context =
      Workflows.prompt_context(
        %{
          id: 101,
          runner_kind: "codex_exec",
          visibility: "operator",
          input: %{
            delegation_policy: %{strategy: "parallel"},
            techtree_publish_policy: %{destination: "draft_node", publish_after_review: true},
            budget_notes: ["Spend is allowed inside the active run budget."],
            artifact_expectations: ["Attach a proof packet and test output."]
          },
          metadata: %{
            protected_actions: ["database_migration"],
            protected_action_metadata: %{approval_scope: "operator"}
          },
          work_item: %{
            id: 44,
            title: "Review release flow",
            body: "Check the release path.",
            visibility: "company",
            acceptance_criteria: ["Proof is recorded."],
            metadata: %{}
          },
          runtime_profile: %{
            id: 7,
            name: "Hosted Codex",
            runner_kind: "codex_exec",
            execution_surface: "hosted_sprite",
            billing_mode: "platform_hosted",
            visibility: "operator",
            config: %{runner_policy: %{max_runtime_minutes: 30}},
            metadata: %{}
          }
        },
        %{path: "/workspace", prompt_path: "/workspace/REGENT_PROMPT.md"}
      )

    assert context["runner_policy"]["runner_kind"] == "codex_exec"
    assert context["runner_policy"]["max_runtime_minutes"] == 30
    assert context["delegation_policy"]["strategy"] == "parallel"
    assert context["techtree_publish_policy"]["destination"] == "draft_node"
    assert context["visibility"]["work_item"] == "company"
    assert "database_migration" in context["protected_actions"]["actions"]
    assert "deploy" in context["protected_actions"]["actions"]
    assert context["protected_actions"]["metadata"]["approval_scope"] == "operator"
    assert context["budget_notes"] == ["Spend is allowed inside the active run budget."]
    assert context["artifact_expectations"] == ["Attach a proof packet and test output."]

    assert {:ok, manager_prompt} = Workflows.manager_prompt(workflow, context)
    assert {:ok, executor_prompt} = Workflows.executor_prompt(workflow, context)

    assert manager_prompt =~ "# Regent Workflow"
    assert manager_prompt =~ "Regent Manager Workflow"
    assert executor_prompt =~ "# Regent Workflow"
    assert executor_prompt =~ "Regent Executor Workflow"

    for prompt <- [manager_prompt, executor_prompt] do
      assert prompt =~ "Finish Review release flow with codex_exec."
      assert prompt =~ "## Runner Policy"
      assert prompt =~ "\"max_runtime_minutes\": 30"
      assert prompt =~ "## Delegation Policy"
      assert prompt =~ "\"strategy\": \"parallel\""
      assert prompt =~ "## Techtree Publish Policy"
      assert prompt =~ "\"destination\": \"draft_node\""
      assert prompt =~ "## Protected Actions"
      assert prompt =~ "\"database_migration\""
      assert prompt =~ "\"approval_scope\": \"operator\""
      assert prompt =~ "## Visibility"
      assert prompt =~ "\"work_item\": \"company\""
      assert prompt =~ "## Budget Notes"
      assert prompt =~ "Spend is allowed inside the active run budget."
      assert prompt =~ "## Artifact Expectations"
      assert prompt =~ "Attach a proof packet and test output."
    end
  end

  test "returns an error when a workflow prompt references a missing value" do
    workflow = %{
      source: "REGENT_WORKFLOW.md",
      path: "/workspace/REGENT_WORKFLOW.md",
      config: %{},
      prompt_template: "Finish {{ work_item.title }} for {{ missing.value }}."
    }

    context = %{"work_item" => %{"title" => "Review release flow"}}

    assert {:error, {:missing_workflow_template_value, "missing.value"}} =
             Workflows.manager_prompt(workflow, context)
  end

  test "uses safe artifact expectations and protected-action defaults" do
    context =
      Workflows.prompt_context(
        %{
          id: 11,
          runner_kind: "codex_exec",
          visibility: "operator",
          input: %{},
          metadata: %{},
          work_item: %{title: "Default proof", metadata: %{}},
          runtime_profile: %{config: %{}, metadata: %{}}
        },
        %{path: "/workspace"}
      )

    assert context["artifact_expectations"] == [
             "Record a proof packet with the work completed, changed files, and checks run."
           ]

    assert context["protected_actions"]["requires_explicit_approval"] == true
    assert "deploy" in context["protected_actions"]["actions"]
    assert "billing_change" in context["protected_actions"]["actions"]
    assert "contract_deploy" in context["protected_actions"]["actions"]
    assert "money_movement" in context["protected_actions"]["actions"]
  end
end
