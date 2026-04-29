defmodule PlatformPhx.AgentPlatform.Companies do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.Repo

  def create_company(%HumanUser{} = human, attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.new()
      |> put_owner_human_id(human.id)
      |> normalize_company_attrs()

    %Company{}
    |> Company.changeset(attrs)
    |> Repo.insert()
  end

  def list_owned_companies(nil), do: []

  def list_owned_companies(%HumanUser{id: id}) do
    Company
    |> where([company], company.owner_human_id == ^id)
    |> order_by([company], desc: company.updated_at, asc: company.slug)
    |> preload([:owner_human, :agents])
    |> Repo.all()
  end

  def get_owned_company(%HumanUser{} = human, id) when is_integer(id) do
    Company
    |> where([company], company.owner_human_id == ^human.id and company.id == ^id)
    |> preload([:owner_human, :agents])
    |> Repo.one()
  end

  def get_owned_company(%HumanUser{} = human, slug) when is_binary(slug) do
    Company
    |> where(
      [company],
      company.owner_human_id == ^human.id and company.slug == ^AgentPlatform.normalize_slug(slug)
    )
    |> preload([:owner_human, :agents])
    |> Repo.one()
  end

  def get_owned_company(_human, _id_or_slug), do: nil

  def get_company_for_owner_wallet(company_id, wallet_address)
      when is_binary(wallet_address) do
    with {:ok, company_id} <- cast_id(company_id),
         %Company{} = company <- get_company_with_owner(company_id),
         true <- owner_wallet?(company.owner_human, wallet_address) do
      {:ok, company}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      false -> {:error, {:forbidden, "Signed agent is not connected to this company"}}
      {:error, _reason} = error -> error
    end
  end

  def get_company_for_owner_wallet(_company_id, _wallet_address),
    do: {:error, {:forbidden, "Signed agent is not connected to this company"}}

  defp get_company_with_owner(company_id) do
    Company
    |> where([company], company.id == ^company_id)
    |> preload([:owner_human])
    |> Repo.one()
  end

  defp owner_wallet?(owner, wallet_address) do
    normalized_wallet = normalize_wallet(wallet_address)

    owner
    |> owner_wallets()
    |> Enum.any?(&(normalize_wallet(&1) == normalized_wallet))
  end

  defp owner_wallets(nil), do: []

  defp owner_wallets(owner) do
    [owner.wallet_address | owner.wallet_addresses || []]
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_wallet(value) when is_binary(value), do: String.downcase(value)
  defp normalize_wallet(_value), do: nil

  defp cast_id(value) when is_integer(value), do: {:ok, value}

  defp cast_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> {:ok, id}
      _other -> {:error, {:not_found, "Company not found"}}
    end
  end

  defp cast_id(_value), do: {:error, {:not_found, "Company not found"}}

  defp put_owner_human_id(attrs, human_id) do
    if Enum.any?(Map.keys(attrs), &is_binary/1) do
      Map.put(attrs, "owner_human_id", human_id)
    else
      Map.put(attrs, :owner_human_id, human_id)
    end
  end

  defp normalize_company_attrs(attrs) do
    attrs
    |> normalize_attr_slug(:slug)
    |> normalize_attr_slug("slug")
  end

  defp normalize_attr_slug(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, slug} -> Map.put(attrs, key, AgentPlatform.normalize_slug(slug))
      :error -> attrs
    end
  end
end
