defmodule PlatformPhx.AgentPlatform.CompanyProfiles do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.Repo

  @public_preloads [:subdomain, :services, :connections, :artifacts, :owner_human]

  @type t :: %{
          agent: Agent.t(),
          host: String.t() | nil
        }

  @spec list_agents() :: [Agent.t()]
  def list_agents do
    Agent
    |> published_agent_query()
    |> order_by([agent], asc: agent.slug)
    |> preload(^@public_preloads)
    |> Repo.all()
  end

  @spec get_agent_by_slug(String.t()) :: Agent.t() | nil
  def get_agent_by_slug(slug) when is_binary(slug) do
    Agent
    |> published_agent_query()
    |> where([agent], agent.slug == ^normalize_slug(slug))
    |> preload(^@public_preloads)
    |> Repo.one()
  end

  def get_agent_by_slug(_slug), do: nil

  @spec get_agent_by_host(String.t()) :: Agent.t() | nil
  def get_agent_by_host(host) when is_binary(host) do
    normalized_host = normalize_host(host)

    Repo.one(
      from agent in published_agent_query(Agent),
        join: subdomain in assoc(agent, :subdomain),
        where: subdomain.hostname == ^normalized_host and subdomain.active == true,
        preload: ^@public_preloads
    )
  end

  def get_agent_by_host(_host), do: nil

  @spec by_slug(String.t()) :: t() | nil
  def by_slug(slug) when is_binary(slug) do
    slug
    |> get_agent_by_slug()
    |> profile(nil)
  end

  def by_slug(_slug), do: nil

  @spec by_host(String.t()) :: t() | nil
  def by_host(host) when is_binary(host) do
    host
    |> get_agent_by_host()
    |> profile(normalize_host(host))
  end

  def by_host(_host), do: nil

  defp published_agent_query(query) do
    where(query, [agent], agent.status == "published")
  end

  defp profile(%Agent{} = agent, host) do
    %{
      agent: agent,
      host: host || public_hostname(agent)
    }
  end

  defp profile(nil, _host), do: nil

  defp public_hostname(%Agent{subdomain: %Subdomain{hostname: hostname, active: true}}),
    do: hostname

  defp public_hostname(_agent), do: nil

  defp normalize_slug(value) do
    value
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/[^a-z0-9-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp normalize_host(value) do
    value
    |> String.downcase()
    |> String.trim()
  end
end
