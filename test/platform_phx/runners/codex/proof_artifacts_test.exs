defmodule PlatformPhx.Runners.Codex.ProofArtifactsTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Runners.Codex.ProofArtifacts
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkArtifact

  test "records a Codex proof packet with collected workspace artifacts" do
    %{company: company, run: run} = run_fixture("codex_exec")

    assert {:ok, %WorkArtifact{} = artifact} =
             ProofArtifacts.record(
               run,
               %{
                 proof_title: "Codex proof",
                 proof: "Codex completed the work.",
                 collected_artifacts: %{
                   changed_files: ["lib/example.ex"],
                   patch: "diff --git a/lib/example.ex b/lib/example.ex\n",
                   test_output: "mix test passed\n"
                 }
               },
               "codex_exec"
             )

    assert artifact.company_id == company.id
    assert artifact.kind == "proof_packet"
    assert artifact.visibility == "operator"
    assert artifact.attestation_level == "platform_observed"
    assert artifact.content_inline =~ "lib/example.ex"
    assert artifact.content_inline =~ "mix test passed"
    assert artifact.metadata["runner_kind"] == "codex_exec"
    assert artifact.metadata["proof_source"] == "codex_exec"
  end

  test "does not duplicate an existing proof packet for the same run" do
    %{run: run} = run_fixture("codex_exec")

    assert {:ok, first_artifact} =
             ProofArtifacts.record(run, %{proof: "first"}, "codex_exec")

    assert {:ok, second_artifact} =
             ProofArtifacts.record(run, %{proof: "second"}, "codex_exec")

    assert first_artifact.id == second_artifact.id
  end

  defp run_fixture(runner_kind) do
    key = System.unique_integer([:positive])
    human = insert_human!(key)
    company = insert_company!(human, "codex-proof-#{key}")

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
        title: "Check proof collection"
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
        runner_kind: runner_kind,
        workspace_path: Path.join(System.tmp_dir!(), "codex-proof-#{key}")
      })

    %{company: company, run: run}
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-codex-proof-#{key}",
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
