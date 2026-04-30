defmodule PlatformPhx.XMTPMirror.Rooms do
  @moduledoc false

  import Ecto.Query

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.Repo
  alias PlatformPhx.XMTPMirror.Membership
  alias PlatformPhx.XMTPMirror.XmtpMembershipCommand
  alias PlatformPhx.XMTPMirror.XmtpMessage
  alias PlatformPhx.XMTPMirror.XmtpRoom

  @canonical_room_key "public-chatbox"
  @agent_home_room_key "agent-chatbox"
  @formation_room_key "formation:company-opening"
  @default_capacity 200
  @default_presence_ttl_seconds 120

  @spec canonical_room_key() :: String.t()
  def canonical_room_key, do: @canonical_room_key

  @spec agent_home_room_key() :: String.t()
  def agent_home_room_key, do: @agent_home_room_key

  @spec formation_room_key() :: String.t()
  def formation_room_key, do: @formation_room_key

  @spec company_room_key(Agent.t() | String.t()) :: String.t()
  def company_room_key(%Agent{slug: slug}), do: company_room_key(slug)

  def company_room_key(slug) when is_binary(slug) do
    "company:" <> AgentPlatform.normalize_slug(slug)
  end

  @spec public_room?(XmtpRoom.t() | nil) :: boolean()
  def public_room?(%XmtpRoom{room_key: @canonical_room_key}), do: true
  def public_room?(%XmtpRoom{room_key: @agent_home_room_key}), do: true
  def public_room?(%XmtpRoom{room_key: @formation_room_key}), do: true

  def public_room?(%XmtpRoom{room_key: room_key}) when is_binary(room_key) do
    String.starts_with?(room_key, "#{@canonical_room_key}-shard-") or
      String.starts_with?(room_key, "company:")
  end

  def public_room?(_room), do: false

  @spec default_capacity() :: pos_integer()
  def default_capacity, do: @default_capacity

  @spec default_presence_ttl_seconds() :: pos_integer()
  def default_presence_ttl_seconds, do: @default_presence_ttl_seconds

  @spec ensure_room(map()) :: {:ok, XmtpRoom.t()} | {:error, Ecto.Changeset.t()}
  def ensure_room(attrs) when is_map(attrs) do
    key = value_for(attrs, "room_key")

    case get_room_by_key(key) do
      nil ->
        %XmtpRoom{}
        |> XmtpRoom.changeset(normalize_room_attrs(attrs))
        |> Repo.insert()

      %XmtpRoom{} = room ->
        room
        |> XmtpRoom.changeset(normalize_room_attrs(attrs))
        |> Repo.update()
    end
  end

  @spec ensure_company_room(Agent.t()) :: {:ok, XmtpRoom.t()} | {:error, Ecto.Changeset.t()}
  def ensure_company_room(%Agent{} = agent) do
    ensure_room(%{
      "room_key" => company_room_key(agent),
      "xmtp_group_id" => "xmtp-#{company_room_key(agent)}",
      "name" => "#{agent.name} Room",
      "status" => "active",
      "presence_ttl_seconds" => @default_presence_ttl_seconds,
      "capacity" => @default_capacity
    })
  end

  @spec get_room_by_key(String.t() | nil) :: XmtpRoom.t() | nil
  def get_room_by_key(room_key) when is_binary(room_key) and room_key != "" do
    Repo.get_by(XmtpRoom, room_key: room_key)
  end

  def get_room_by_key(_room_key), do: nil

  @spec room_panel(HumanUser.t() | nil, String.t() | nil) ::
          {:ok, map()} | {:error, :room_not_found}
  def room_panel(current_human, room_key) when is_binary(room_key) do
    room = get_room_by_key(room_key)
    connected_wallet = connected_wallet(current_human)
    member_count = room_member_count(room)
    seat_count = room_capacity(room)
    membership_state = panel_membership_state(current_human, room, member_count, seat_count)
    moderator? = moderator?(current_human, room || room_key)

    {:ok,
     %{
       room_id: room && room.id,
       room_key: room_key,
       room_name: room_name(room, room_key),
       ready?: ready?(room),
       status: room && room.status,
       connected_wallet: connected_wallet,
       member_count: member_count,
       active_member_count: member_count,
       seat_count: seat_count,
       seats_remaining: max(seat_count - member_count, 0),
       membership_state: membership_state,
       moderator?: moderator?,
       can_join?: can_join?(current_human, room, membership_state, member_count, seat_count),
       can_send?: membership_state == :joined,
       messages: panel_messages(room, connected_wallet, moderator?)
     }}
  end

  def room_panel(_current_human, _room_key), do: {:error, :room_not_found}

  @spec resolve_join_room(map()) :: {:ok, XmtpRoom.t()} | {:error, :room_not_found}
  def resolve_join_room(attrs) when is_map(attrs) do
    room =
      if explicit_room_reference?(attrs) do
        resolve_room(attrs)
      else
        select_join_room()
      end

    case room do
      nil -> {:error, :room_not_found}
      %XmtpRoom{} = resolved -> {:ok, resolved}
    end
  end

  @spec resolve_message_room(map()) :: {:ok, XmtpRoom.t()} | {:error, :room_not_found}
  def resolve_message_room(attrs) when is_map(attrs) do
    case resolve_room(attrs) do
      nil -> {:error, :room_not_found}
      %XmtpRoom{} = room -> {:ok, room}
    end
  end

  @spec resolve_room(map() | String.t() | integer() | nil) :: XmtpRoom.t() | nil
  def resolve_room(%{} = attrs) do
    cond do
      room_id = value_for(attrs, "room_id") ->
        Repo.get(XmtpRoom, normalize_id(room_id))

      shard_key = value_for(attrs, "shard_key") ->
        get_room_by_key(shard_key)

      room_key = value_for(attrs, "room_key") ->
        get_room_by_key(room_key)

      true ->
        get_room_by_key(@canonical_room_key)
    end
  end

  def resolve_room(room_key) when is_binary(room_key), do: get_room_by_key(room_key)
  def resolve_room(room_id) when is_integer(room_id), do: Repo.get(XmtpRoom, room_id)
  def resolve_room(_), do: nil

  @spec list_shards() :: [map()]
  def list_shards do
    XmtpRoom
    |> where([r], r.status == "active")
    |> order_by([r], asc: r.room_key)
    |> Repo.all()
    |> Enum.map(&encode_shard/1)
  end

  @spec active_member_count(integer()) :: non_neg_integer()
  def active_member_count(room_id) when is_integer(room_id) do
    add_count =
      XmtpMembershipCommand
      |> where([c], c.room_id == ^room_id and c.op == "add_member" and c.status == "done")
      |> Repo.aggregate(:count, :id)

    remove_count =
      XmtpMembershipCommand
      |> where([c], c.room_id == ^room_id and c.op == "remove_member" and c.status == "done")
      |> Repo.aggregate(:count, :id)

    max(add_count - remove_count, 0)
  end

  def active_member_count(_room_id), do: 0

  @spec parse_limit(map(), pos_integer()) :: pos_integer()
  def parse_limit(attrs, default) when is_map(attrs) and is_integer(default) do
    attrs
    |> value_for("limit")
    |> normalize_limit(default)
  end

  @spec normalize_id(String.t() | integer() | nil) :: integer() | nil
  def normalize_id(id) when is_integer(id) and id > 0, do: id

  def normalize_id(id) when is_binary(id) do
    case Integer.parse(String.trim(id)) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> nil
    end
  end

  def normalize_id(_id), do: nil

  @spec value_for(map(), String.t()) :: term()
  def value_for(attrs, key) when is_map(attrs) and is_binary(key), do: Map.get(attrs, key)

  defp explicit_room_reference?(attrs) when is_map(attrs) do
    not is_nil(value_for(attrs, "room_id")) or
      not is_nil(value_for(attrs, "shard_key")) or
      not is_nil(value_for(attrs, "room_key"))
  end

  defp select_join_room do
    case list_joinable_rooms() do
      [room | _rest] -> room
      [] -> ensure_next_shard_room()
    end
  end

  defp list_joinable_rooms do
    XmtpRoom
    |> where([r], r.status == "active" and like(r.room_key, ^"#{@canonical_room_key}%"))
    |> Repo.all()
    |> Enum.sort_by(&room_sort_key/1)
    |> Enum.filter(&(active_member_count(&1.id) < room_capacity(&1)))
  end

  defp ensure_next_shard_room do
    canonical_room = get_room_by_key(@canonical_room_key)

    if canonical_room do
      next_number =
        XmtpRoom
        |> where([r], like(r.room_key, ^"#{@canonical_room_key}-shard-%"))
        |> Repo.all()
        |> Enum.map(&room_sort_key/1)
        |> Enum.reject(&(&1 == 9_999))
        |> Enum.max(fn -> 1 end)
        |> Kernel.+(1)

      shard_key = "#{@canonical_room_key}-shard-#{next_number}"

      case ensure_room(%{
             "room_key" => shard_key,
             "xmtp_group_id" => "xmtp-#{shard_key}",
             "name" => "#{canonical_room.name || "Platform Room"} ##{next_number}",
             "status" => canonical_room.status || "active",
             "presence_ttl_seconds" =>
               canonical_room.presence_ttl_seconds || @default_presence_ttl_seconds,
             "capacity" => @default_capacity
           }) do
        {:ok, room} -> room
        {:error, _changeset} -> get_room_by_key(shard_key)
      end
    end
  end

  defp encode_shard(%XmtpRoom{} = room) do
    active_members = active_member_count(room.id)
    capacity = room_capacity(room)

    %{
      id: room.id,
      room_key: room.room_key,
      xmtp_group_id: room.xmtp_group_id,
      name: room.name,
      status: room.status,
      presence_ttl_seconds: room.presence_ttl_seconds,
      capacity: capacity,
      active_members: active_members,
      joinable: active_members < capacity
    }
  end

  defp normalize_room_attrs(attrs) do
    %{
      room_key: value_for(attrs, "room_key"),
      xmtp_group_id: value_for(attrs, "xmtp_group_id"),
      name: value_for(attrs, "name"),
      status: value_for(attrs, "status") || "active",
      presence_ttl_seconds:
        value_for(attrs, "presence_ttl_seconds") || @default_presence_ttl_seconds,
      capacity: @default_capacity
    }
  end

  defp panel_messages(nil, _connected_wallet, _moderator?), do: []

  defp panel_messages(%XmtpRoom{} = room, connected_wallet, moderator?) do
    XmtpMessage
    |> where([m], m.room_id == ^room.id and m.moderation_state == "visible")
    |> order_by([m], asc: m.sent_at, asc: m.id)
    |> limit(50)
    |> Repo.all()
    |> Enum.map(&encode_panel_message(&1, connected_wallet, moderator?))
  end

  defp encode_panel_message(%XmtpMessage{} = message, connected_wallet, _moderator?) do
    sender_wallet = normalize_address(message.sender_wallet_address)

    %{
      key: Integer.to_string(message.id),
      author: message.sender_label || short_wallet(sender_wallet) || "Room member",
      body: message.body,
      stamp: stamp(message.sent_at),
      side: message_side(sender_wallet, connected_wallet),
      sender_kind: message.sender_type || :human,
      sender_wallet: sender_wallet,
      sender_inbox_id: message.sender_inbox_id,
      can_delete?: false,
      can_kick?: false
    }
  end

  defp panel_membership_state(_current_human, nil, _member_count, _seat_count), do: :offline
  defp panel_membership_state(nil, _room, _member_count, _seat_count), do: :watching

  defp panel_membership_state(%HumanUser{} = human, %XmtpRoom{} = room, member_count, seat_count) do
    case Membership.membership_state(human, room) do
      "joined" -> :joined
      "join_pending" -> :join_pending
      "leave_pending" -> :join_pending
      "not_joined" when member_count >= seat_count -> :full
      "join_failed" -> :not_joined
      "leave_failed" -> :joined
      _ -> identity_ready_state(human)
    end
  end

  defp identity_ready_state(%HumanUser{} = human) do
    case Membership.require_human_inbox_id(human) do
      {:ok, _inbox_id} -> :not_joined
      {:error, :xmtp_identity_required} -> :setup_required
    end
  end

  defp can_join?(%HumanUser{}, %XmtpRoom{}, :not_joined, member_count, seat_count),
    do: member_count < seat_count

  defp can_join?(_current_human, _room, _state, _member_count, _seat_count), do: false

  defp moderator?(%HumanUser{} = human, %XmtpRoom{room_key: "company:" <> slug}) do
    not is_nil(AgentPlatform.get_owned_agent(human, slug))
  end

  defp moderator?(%HumanUser{} = human, "company:" <> slug) do
    not is_nil(AgentPlatform.get_owned_agent(human, slug))
  end

  defp moderator?(_current_human, _room), do: false

  defp connected_wallet(%HumanUser{} = human) do
    AgentPlatform.current_wallet_address(human)
  end

  defp connected_wallet(_current_human), do: nil

  defp room_member_count(%XmtpRoom{id: id}), do: active_member_count(id)
  defp room_member_count(_room), do: 0

  @spec room_capacity(XmtpRoom.t() | nil) :: pos_integer()
  def room_capacity(_room), do: @default_capacity

  defp room_name(%XmtpRoom{name: name}, _room_key) when is_binary(name) and name != "", do: name
  defp room_name(_room, room_key), do: room_key

  defp ready?(%XmtpRoom{status: "active"}), do: true
  defp ready?(_room), do: false

  defp normalize_address(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_address(_value), do: nil

  defp message_side(nil, _connected_wallet), do: :other
  defp message_side(_sender_wallet, nil), do: :other

  defp message_side(sender_wallet, connected_wallet) do
    if normalize_address(sender_wallet) == normalize_address(connected_wallet),
      do: :self,
      else: :other
  end

  defp stamp(%DateTime{} = sent_at) do
    Calendar.strftime(sent_at, "%b %-d, %H:%M UTC")
  end

  defp stamp(_sent_at), do: ""

  defp short_wallet(nil), do: nil

  defp short_wallet(wallet_address) when is_binary(wallet_address) do
    if String.length(wallet_address) <= 10 do
      wallet_address
    else
      String.slice(wallet_address, 0, 6) <> "..." <> String.slice(wallet_address, -4, 4)
    end
  end

  defp normalize_limit(value, _default) when is_integer(value) and value > 0,
    do: min(value, 100)

  defp normalize_limit(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} when int > 0 -> min(int, 100)
      _ -> default
    end
  end

  defp normalize_limit(_value, default), do: default

  defp room_sort_key(%XmtpRoom{room_key: @canonical_room_key}), do: 1

  defp room_sort_key(%XmtpRoom{room_key: room_key}) do
    room_key
    |> String.replace_prefix("#{@canonical_room_key}-shard-", "")
    |> Integer.parse()
    |> case do
      {shard_number, ""} when shard_number > 0 -> shard_number
      _ -> 9_999
    end
  end
end
