defmodule PlatformPhxWeb.CompanyRoomComponents do
  @moduledoc false
  use PlatformPhxWeb, :html

  attr :room, :map, required: true
  attr :form, :map, required: true
  attr :id, :string, default: "company-room"
  attr :form_id, :string, default: "company-room-form"
  attr :layout, :string, default: "wide"
  attr :class, :string, default: nil
  attr :eyebrow, :string, default: "Company room"
  attr :title, :string, default: "Talk with this company in one shared room"

  attr :description, :string,
    default:
      "Join the room to ask questions, follow updates, and keep the company conversation in one place."

  attr :empty_title, :string, default: "No one has posted here yet."

  attr :empty_copy, :string,
    default: "Join the room, then post the first update or question to start the thread."

  attr :message_placeholder, :string, default: "Ask a question or share an update."
  attr :moderator_label, :string, default: "Owner admin"

  def company_room(assigns) do
    ~H"""
    <section
      id={@id}
      phx-hook="DashboardXmtpRoom"
      class={[
        "overflow-hidden rounded-[1.8rem] border border-[color:var(--border)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--card)_96%,var(--background)_4%),color-mix(in_oklch,var(--background)_90%,transparent))] shadow-[0_28px_90px_-56px_color-mix(in_oklch,var(--brand-ink)_35%,transparent)]",
        @class
      ]}
    >
      <div class="border-b border-[color:var(--border)] px-5 py-5 sm:px-6">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div class="space-y-3">
            <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              {@eyebrow}
            </p>
            <div class="space-y-2">
              <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                {@title}
              </h3>
              <p class="max-w-[44rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                {@description}
              </p>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2 text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
            <span class="rounded-full border border-[color:var(--border)] px-3 py-1">
              {room_state_label(@room)}
            </span>
            <span class="rounded-full border border-[color:var(--border)] px-3 py-1">
              {Integer.to_string(@room.member_count)}/{Integer.to_string(@room.seat_count)} seats filled
            </span>
            <span class="rounded-full border border-[color:var(--border)] px-3 py-1">
              {active_member_copy(@room)}
            </span>
            <span
              :if={@room.connected_wallet}
              class="rounded-full border border-[color:var(--border)] px-3 py-1"
            >
              {short_wallet(@room.connected_wallet)}
            </span>
            <span
              :if={@room.moderator?}
              class="rounded-full border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--brand-1)_18%,transparent)] px-3 py-1 text-[color:var(--foreground)]"
            >
              {@moderator_label}
            </span>
          </div>
        </div>
      </div>

      <div class={[
        "grid gap-0",
        @layout == "wide" && "xl:grid-cols-[minmax(0,1.12fr)_minmax(21rem,0.88fr)]"
      ]}>
        <div class={[
          "border-b border-[color:var(--border)] px-5 py-5 sm:px-6",
          @layout == "wide" && "xl:border-b-0 xl:border-r"
        ]}>
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                Room activity
              </p>
              <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                Read along before you join. Post once you are in.
              </p>
            </div>
          </div>

          <div
            data-dashboard-xmtp-feed
            class="mt-5 flex max-h-[30rem] min-h-[16rem] flex-col gap-3 overflow-y-auto pr-1"
          >
            <%= if @room.messages == [] do %>
              <div class="flex min-h-[13rem] items-center justify-center rounded-[1.4rem] border border-dashed border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_85%,transparent)] px-5 py-6 text-center text-sm leading-6 text-[color:var(--muted-foreground)]">
                <div class="max-w-[24rem] space-y-2">
                  <p class="font-display text-[1.1rem] leading-none text-[color:var(--foreground)]">
                    {@empty_title}
                  </p>
                  <p>
                    {@empty_copy}
                  </p>
                </div>
              </div>
            <% else %>
              <%= for message <- @room.messages do %>
                <article
                  id={"#{@id}-message-#{message.key}"}
                  data-xmtp-entry
                  data-message-key={message.key}
                  class={[
                    "rounded-[1.35rem] border px-4 py-4",
                    message.side == :self &&
                      "border-[color:color-mix(in_oklch,var(--brand-1)_30%,var(--border)_70%)] bg-[color:color-mix(in_oklch,var(--brand-1)_8%,transparent)]",
                    message.side != :self &&
                      "border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_88%,transparent)]"
                  ]}
                >
                  <div class="flex items-start justify-between gap-3">
                    <div class="space-y-1">
                      <div class="flex flex-wrap items-center gap-2 text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                        <span>{sender_label(message.sender_kind)}</span>
                        <span>{message.author}</span>
                        <span>{message.stamp}</span>
                      </div>
                      <p class="text-sm leading-7 text-[color:var(--foreground)]">{message.body}</p>
                    </div>

                    <div :if={message.can_delete? || message.can_kick?} class="flex shrink-0 gap-2">
                      <button
                        :if={message.can_delete?}
                        type="button"
                        phx-click="xmtp_delete_message"
                        phx-value-message_id={message.key}
                        class="rounded-full border border-[color:var(--border)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)] hover:text-[color:var(--foreground)]"
                      >
                        Remove
                      </button>

                      <button
                        :if={message.can_kick?}
                        type="button"
                        phx-click="xmtp_kick_user"
                        phx-value-target={message.sender_wallet || message.sender_inbox_id}
                        class="rounded-full border border-[color:var(--border)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:#a6574f] hover:text-[color:#a6574f]"
                      >
                        Remove person
                      </button>
                    </div>
                  </div>
                </article>
              <% end %>
            <% end %>
          </div>
        </div>

        <div class="px-5 py-5 sm:px-6">
          <div class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_88%,transparent)] p-4">
            <p class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
              Room status
            </p>
            <p
              data-dashboard-xmtp-status
              class="mt-3 text-sm leading-6 text-[color:var(--foreground)]"
            >
              {room_status_copy(@room)}
            </p>
          </div>

          <div class="mt-5 flex flex-wrap gap-3">
            <button
              :if={@room.can_join?}
              type="button"
              phx-click="xmtp_join"
              class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition duration-200 hover:-translate-y-0.5 hover:opacity-90"
            >
              Join room
            </button>
          </div>

          <.form for={@form} id={@form_id} phx-submit="xmtp_send" class="mt-5 space-y-4">
            <label class="space-y-2">
              <span class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                Post a message
              </span>
              <.input
                field={@form[:body]}
                type="textarea"
                rows="4"
                placeholder={@message_placeholder}
                disabled={!@room.can_send?}
                class="min-h-32 w-full rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm leading-6 text-[color:var(--foreground)]"
              />
            </label>

            <div class="flex flex-wrap items-center justify-between gap-3">
              <p class="max-w-[20rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                {composer_copy(@room)}
              </p>
              <button
                type="submit"
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition duration-200 hover:-translate-y-0.5 hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={!@room.can_send?}
              >
                Send
              </button>
            </div>
          </.form>
        </div>
      </div>
    </section>
    """
  end

  def room_status_copy(%{status_override: message}) when is_binary(message) and message != "",
    do: message

  def room_status_copy(%{room_id: nil}), do: "This chat is not ready yet."

  def room_status_copy(%{membership_state: :join_pending}),
    do: "Your room seat is being prepared."

  def room_status_copy(%{membership_state: :joined}), do: "You are in the room."

  def room_status_copy(%{membership_state: :setup_required}),
    do: "Reconnect your wallet before you join this room."

  def room_status_copy(%{membership_state: :full}),
    do: "All seats are filled right now. You can still read along from this page."

  def room_status_copy(%{membership_state: :kicked}),
    do: "You were removed from the room. Join again later if a seat opens."

  def room_status_copy(%{connected_wallet: nil}), do: "Sign in with your wallet to join the room."

  def room_status_copy(%{seats_remaining: seats_remaining}),
    do: "#{seats_remaining} seats are open. Join when you are ready."

  def room_state_label(%{status_override: _message, membership_state: :join_pending}),
    do: "Joining"

  def room_state_label(%{room_id: nil}), do: "Offline"
  def room_state_label(%{membership_state: :join_pending}), do: "Joining"
  def room_state_label(%{membership_state: :joined}), do: "In room"
  def room_state_label(%{membership_state: :full}), do: "Full"
  def room_state_label(%{membership_state: :kicked}), do: "Removed"
  def room_state_label(%{membership_state: :setup_required}), do: "Wallet needed"
  def room_state_label(%{connected_wallet: nil}), do: "Watch only"
  def room_state_label(_room), do: "Ready"

  def active_member_copy(%{active_member_count: 1}), do: "1 active now"

  def active_member_copy(%{active_member_count: count}) when is_integer(count),
    do: "#{count} active now"

  def active_member_copy(_room), do: "0 active now"

  def sender_label(:agent), do: "Agent"
  def sender_label(_kind), do: "Person"

  def composer_copy(%{can_send?: true}),
    do: "Keep messages short and clear so the room stays easy to follow."

  def composer_copy(%{can_join?: true}),
    do: "Join the room first if you want to post."

  def composer_copy(%{membership_state: :join_pending}),
    do: "Posting opens when your room seat is ready."

  def composer_copy(%{membership_state: :setup_required}),
    do: "Reconnect your wallet before posting."

  def composer_copy(%{membership_state: :full}),
    do: "This room is full right now, so posting is closed."

  def composer_copy(%{membership_state: :kicked}),
    do: "Posting is paused for this wallet until you join again."

  def composer_copy(_room),
    do: "Read along here even if you are not ready to post yet."

  def short_wallet(nil), do: nil

  def short_wallet(wallet_address) when is_binary(wallet_address) do
    trimmed = String.trim(wallet_address)

    if String.length(trimmed) <= 10 do
      trimmed
    else
      String.slice(trimmed, 0, 6) <> "..." <> String.slice(trimmed, -4, 4)
    end
  end
end
