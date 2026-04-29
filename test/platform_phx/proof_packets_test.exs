defmodule PlatformPhx.ProofPacketsTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.ProofPackets
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.Security.Redactor
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns

  test "local OpenClaw proof defaults to operator-only and local self-reported" do
    %{company: company, item: item, run: run} = local_openclaw_run_fixture("proof-defaults")

    assert {:ok, artifact} =
             ProofPackets.record_artifact(%{
               company_id: company.id,
               work_item_id: item.id,
               run_id: run.id,
               kind: "proof_packet",
               title: "Local proof",
               content_inline: "CHAT TRANSCRIPT: private customer text",
               metadata: %{"private_memory" => "customer details"}
             })

    assert artifact.visibility == "operator"
    assert artifact.attestation_level == "local_self_reported"
    assert artifact.content_inline == "[redacted]"
    assert artifact.metadata["sensitivity"] == "sensitive"
    assert artifact.metadata["private_memory"] == "[redacted]"
  end

  test "public artifact publishing requires explicit publish action" do
    %{company: company, item: item, run: run} = local_openclaw_run_fixture("publish-action")

    attrs = %{
      company_id: company.id,
      work_item_id: item.id,
      run_id: run.id,
      kind: "proof_packet",
      title: "Local proof",
      visibility: "public"
    }

    assert {:error, :explicit_publish_action_required} = ProofPackets.record_artifact(attrs)

    assert {:ok, artifact} =
             attrs
             |> Map.put(:publish_action, "publish_artifact")
             |> ProofPackets.record_artifact()

    assert artifact.visibility == "public"
  end

  test "artifact recording accepts current fields from JSON-shaped params" do
    %{company: company, item: item, run: run} = local_openclaw_run_fixture("json-shaped")

    assert {:ok, artifact} =
             ProofPackets.record_artifact(%{
               "company_id" => company.id,
               "work_item_id" => item.id,
               "run_id" => run.id,
               "kind" => "proof_packet",
               "title" => "Local proof",
               "metadata" => %{"api_key" => "sk-secret"}
             })

    assert artifact.visibility == "operator"
    assert artifact.attestation_level == "local_self_reported"
    assert artifact.metadata["api_key"] == "[redacted]"
  end

  test "redactor removes obvious secret and private fields" do
    payload =
      Redactor.redact_event_payload(%{
        "api_key" => "sk-live-secret",
        "nested" => %{"refresh_token" => "token"},
        "notes" => "CHAT TRANSCRIPT: private customer text",
        "safe" => "ordinary update"
      })

    assert payload["api_key"] == "[redacted]"
    assert payload["nested"]["refresh_token"] == "[redacted]"
    assert payload["notes"] == "[redacted]"
    assert payload["safe"] == "ordinary update"
  end

  defp local_openclaw_run_fixture(key) do
    human = insert_human!(key)
    company = insert_company!(human, key)

    {:ok, runtime} =
      RuntimeRegistry.create_runtime_profile(%{
        company_id: company.id,
        name: "#{key} runtime",
        runner_kind: "openclaw_local_executor",
        execution_surface: "local_bridge"
      })

    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        created_by_human_id: human.id,
        name: "#{key} profile",
        agent_kind: "openclaw",
        default_runner_kind: "openclaw_local_executor"
      })

    {:ok, worker} =
      AgentRegistry.register_worker(%{
        company_id: company.id,
        agent_profile_id: profile.id,
        runtime_profile_id: runtime.id,
        name: "#{key} worker",
        agent_kind: "openclaw",
        worker_role: "executor",
        execution_surface: "local_bridge",
        runner_kind: "openclaw_local_executor"
      })

    {:ok, policy} =
      Work.create_budget_policy(%{
        company_id: company.id,
        scope_kind: "company"
      })

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: profile.id,
        assigned_worker_id: worker.id,
        budget_policy_id: policy.id,
        title: "#{key} work",
        desired_runner_kind: "openclaw_local_executor"
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runtime_profile_id: runtime.id,
        runner_kind: "openclaw_local_executor"
      })

    %{company: company, item: item, run: run}
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-proof-#{key}",
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
end
