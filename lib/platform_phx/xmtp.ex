defmodule PlatformPhx.Xmtp do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeConfig
  alias Xmtp.Principal

  @manager __MODULE__.Manager
  @shared_agent_room_key "platform_agents"
  @formation_room_key "formation:company-opening"

  def child_spec(opts \\ []) do
    Xmtp.child_spec(
      Keyword.merge(opts,
        name: @manager,
        repo: PlatformPhx.Repo,
        pubsub: PlatformPhx.PubSub,
        rooms: {:mfa, __MODULE__, :rooms, []}
      )
    )
  end

  def rooms do
    shared_room_definitions() ++ formation_room_definitions() ++ company_room_definitions()
  end

  def default_room_key do
    @shared_agent_room_key
  end

  def formation_room_key, do: @formation_room_key

  def topic(room_key \\ default_room_key()), do: Xmtp.topic(@manager, room_key)

  def subscribe(room_key \\ default_room_key()) do
    Xmtp.subscribe(@manager, room_key)
  end

  def room_panel(principal, room_key \\ default_room_key(), claims \\ %{}) do
    Xmtp.public_room_panel(@manager, room_key, normalize_principal(principal), claims)
  end

  def request_join(principal, room_key \\ default_room_key(), claims \\ %{}) do
    Xmtp.request_join(@manager, room_key, normalize_principal(principal), claims)
  end

  def complete_join_signature(
        principal,
        request_id,
        signature,
        room_key \\ default_room_key(),
        claims \\ %{}
      ) do
    Xmtp.complete_join_signature(
      @manager,
      room_key,
      normalize_principal(principal),
      request_id,
      signature,
      claims
    )
  end

  def send_message(principal, body, room_key \\ default_room_key()) do
    Xmtp.send_public_message(@manager, room_key, normalize_principal(principal), body)
  end

  def heartbeat(principal, room_key \\ default_room_key()) do
    Xmtp.heartbeat(@manager, room_key, normalize_principal(principal))
  end

  def invite_user(actor, target, room_key \\ default_room_key(), claims \\ %{}) do
    Xmtp.invite_user(
      @manager,
      room_key,
      normalize_actor(actor),
      normalize_target(target),
      claims
    )
  end

  def kick_user(actor, target, room_key \\ default_room_key()) do
    Xmtp.kick_user(@manager, room_key, normalize_actor(actor), normalize_target(target))
  end

  def moderator_delete_message(actor, message_id, room_key \\ default_room_key()) do
    Xmtp.moderator_delete_message(
      @manager,
      room_key,
      normalize_actor(actor),
      message_id
    )
  end

  def bootstrap_room!(opts \\ []) do
    room_key = Keyword.get(opts, :room_key, default_room_key())
    Xmtp.bootstrap_room!(@manager, room_key, opts)
  end

  def formation_room_panel(principal, claims \\ %{}) do
    room_panel(principal, @formation_room_key, claims)
  end

  def bootstrap_formation_room!(opts \\ []) do
    bootstrap_room!(Keyword.merge([reuse: true, room_key: @formation_room_key], opts))
  end

  def company_room_key(%Agent{slug: slug}), do: company_room_key(slug)

  def company_room_key(slug) when is_binary(slug) do
    "company:" <> AgentPlatform.normalize_slug(slug)
  end

  def company_room_panel(principal, agent_or_slug, claims \\ %{})

  def company_room_panel(principal, %Agent{} = agent, claims) do
    room_panel(principal, company_room_key(agent), claims)
  end

  def company_room_panel(principal, slug, claims) when is_binary(slug) do
    room_panel(principal, company_room_key(slug), claims)
  end

  def bootstrap_company_room!(agent_or_slug, opts \\ [])

  def bootstrap_company_room!(%Agent{} = agent, opts) do
    bootstrap_room!(Keyword.merge([reuse: true, room_key: company_room_key(agent)], opts))
  end

  def bootstrap_company_room!(slug, opts) when is_binary(slug) do
    bootstrap_room!(Keyword.merge([reuse: true, room_key: company_room_key(slug)], opts))
  end

  def reset_for_test!(room_key \\ default_room_key()) do
    Xmtp.reset_for_test!(@manager, room_key)
  end

  def principal_for_agent_wallet(wallet_address, label \\ nil) do
    Principal.agent(%{wallet_address: wallet_address, display_name: label})
  end

  defp normalize_actor(:system), do: :system
  defp normalize_actor(actor), do: normalize_principal(actor)

  defp normalize_target(target) when is_binary(target), do: target
  defp normalize_target(target), do: normalize_principal(target)

  defp normalize_principal(%HumanUser{} = human) do
    Principal.human(%{
      id: human.id,
      wallet_address: AgentPlatform.current_wallet_address(human),
      wallet_addresses: AgentPlatform.linked_wallet_addresses(human),
      display_name: human.display_name
    })
  end

  defp normalize_principal(%Agent{} = agent) do
    Principal.agent(%{
      id: agent.id,
      wallet_address: agent.wallet_address,
      display_name: agent.name
    })
  end

  defp normalize_principal(%{} = attrs), do: Principal.from(attrs)
  defp normalize_principal(nil), do: nil

  defp shared_room_definitions do
    :platform_phx
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:rooms, [])
    |> Enum.filter(&(&1[:key] == @shared_agent_room_key))
  end

  defp formation_room_definitions do
    [
      %{
        key: @formation_room_key,
        name: "Formation Room",
        description: "Shared room for people preparing company launches.",
        app_data: "platform-formation-room",
        agent_private_key: agent_room_private_key(),
        moderator_wallets: RuntimeConfig.regent_staking_operator_wallets(),
        capacity: 200,
        presence_timeout_ms: :timer.minutes(2),
        presence_check_interval_ms: :timer.seconds(30),
        policy_options: %{
          allowed_kinds: [:human],
          required_claims: %{}
        }
      }
    ]
  end

  defp company_room_definitions do
    Agent
    |> join(:left, [agent], owner in assoc(agent, :owner_human))
    |> where([agent, _owner], agent.status in ["forming", "published"])
    |> select([agent, owner], %{agent: agent, owner: owner})
    |> Repo.all()
    |> Enum.map(&company_room_definition/1)
  end

  defp company_room_definition(%{agent: %Agent{} = agent, owner: owner}) do
    %{
      key: company_room_key(agent),
      name: "#{agent.name} Room",
      description: "Chat room for #{agent.name}.",
      app_data: "company-room:#{agent.slug}",
      agent_private_key: agent_room_private_key(),
      moderator_wallets: owner_wallets(owner, agent),
      capacity: 200,
      presence_timeout_ms: :timer.minutes(2),
      presence_check_interval_ms: :timer.seconds(30),
      policy_options: %{
        allowed_kinds: [:human, :agent],
        required_claims: %{}
      }
    }
  end

  defp owner_wallets(%HumanUser{} = owner, _agent),
    do: AgentPlatform.linked_wallet_addresses(owner)

  defp owner_wallets(_owner, %Agent{} = agent), do: List.wrap(agent.wallet_address)

  defp agent_room_private_key do
    shared_room_definitions()
    |> Enum.find(&(&1[:key] == @shared_agent_room_key))
    |> case do
      nil -> nil
      room -> room[:agent_private_key]
    end
  end
end
