defmodule PlatformPhx.Repo.Migrations.CreatePlatformStripeEvents do
  use Ecto.Migration

  def change do
    create table(:platform_stripe_events) do
      add :event_id, :string, null: false
      add :event_type, :string, null: false
      add :customer_id, :string
      add :subscription_id, :string
      add :subscription_status, :string
      add :mode, :string
      add :metadata, :map, null: false, default: %{}
      add :processing_status, :string, null: false, default: "queued"
      add :processed_at, :utc_datetime

      timestamps(inserted_at: :received_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:platform_stripe_events, [:event_id, :event_type])
    create index(:platform_stripe_events, [:processing_status, :received_at])

    create constraint(:platform_stripe_events, :platform_stripe_events_processing_status_check,
             check: "processing_status IN ('queued', 'processed')"
           )
  end
end
