defmodule PlatformPhx.Work do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.Repo
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.Work.BudgetPolicy
  alias PlatformPhx.Work.WorkGoal
  alias PlatformPhx.Work.WorkItem

  def create_goal(attrs) do
    %WorkGoal{}
    |> WorkGoal.changeset(attrs)
    |> Repo.insert()
  end

  def create_item(attrs) do
    %WorkItem{}
    |> WorkItem.changeset(attrs)
    |> Repo.insert()
  end

  def list_items(company_id) do
    WorkItem
    |> where([item], item.company_id == ^company_id)
    |> order_by([item], desc: item.updated_at, desc: item.id)
    |> Repo.all()
  end

  def list_items_for_owned_company(human_id, company_id) do
    WorkItem
    |> join(:inner, [item], company in Company, on: company.id == item.company_id)
    |> where(
      [item, company],
      company.owner_human_id == ^human_id and item.company_id == ^company_id
    )
    |> order_by([item], desc: item.updated_at, desc: item.id)
    |> preload([:assigned_worker, :assigned_agent_profile])
    |> Repo.all()
  end

  def create_budget_policy(attrs) do
    %BudgetPolicy{}
    |> BudgetPolicy.changeset(attrs)
    |> Repo.insert()
  end
end
