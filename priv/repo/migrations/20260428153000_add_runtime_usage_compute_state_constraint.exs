defmodule PlatformPhx.Repo.Migrations.AddRuntimeUsageComputeStateConstraint do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE runtime_usage_snapshots
    ADD CONSTRAINT runtime_usage_snapshots_compute_state_check
    CHECK (compute_state IS NULL OR compute_state IN ('active', 'paused', 'retired'))
    NOT VALID
    """)

    execute("""
    ALTER TABLE runtime_usage_snapshots
    VALIDATE CONSTRAINT runtime_usage_snapshots_compute_state_check
    """)
  end

  def down do
    raise "runtime usage compute state constraint is a hard cutover"
  end
end
