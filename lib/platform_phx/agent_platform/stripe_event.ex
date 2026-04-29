defmodule PlatformPhx.AgentPlatform.StripeEvent do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_stripe_events" do
    field :event_id, :string
    field :event_type, :string
    field :customer_id, :string
    field :subscription_id, :string
    field :subscription_status, :string
    field :mode, :string
    field :metadata, :map, default: %{}
    field :processing_status, :string, default: "queued"
    field :processed_at, :utc_datetime

    timestamps(inserted_at: :received_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :event_id,
      :event_type,
      :customer_id,
      :subscription_id,
      :subscription_status,
      :mode,
      :metadata,
      :processing_status,
      :processed_at
    ])
    |> validate_required([:event_id, :event_type, :processing_status])
    |> validate_inclusion(:processing_status, ["queued", "processed"])
    |> check_constraint(:processing_status, name: :platform_stripe_events_processing_status_check)
    |> unique_constraint([:event_id, :event_type],
      name: :platform_stripe_events_event_id_event_type_index
    )
  end

  def worker_args(%__MODULE__{} = event) do
    %{
      "event_id" => event.event_id,
      "event_type" => event.event_type,
      "customer_id" => event.customer_id,
      "subscription_id" => event.subscription_id,
      "subscription_status" => event.subscription_status,
      "mode" => event.mode,
      "metadata" => event.metadata || %{}
    }
  end
end
