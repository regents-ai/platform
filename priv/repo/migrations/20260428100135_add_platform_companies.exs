defmodule PlatformPhx.Repo.Migrations.AddPlatformCompanies do
  use Ecto.Migration

  def up do
    create table(:platform_companies) do
      add :owner_human_id, references(:platform_human_users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :claimed_label, :string, null: false
      add :status, :string, null: false, default: "forming"
      add :public_summary, :text, null: false
      add :hero_statement, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:platform_companies, [:slug])
    create unique_index(:platform_companies, [:claimed_label])

    create index(:platform_companies, [:owner_human_id, :updated_at],
             name: :platform_companies_owner_updated_idx
           )

    create index(:platform_companies, [:status, :slug], name: :platform_companies_status_slug_idx)

    alter table(:platform_agents) do
      add :company_id, references(:platform_companies, on_delete: :delete_all)
    end

    execute("""
    INSERT INTO platform_human_users (
      privy_user_id,
      wallet_addresses,
      stripe_llm_billing_status,
      created_at,
      updated_at
    )
    SELECT
      'platform-house-owner',
      ARRAY[]::varchar[],
      'not_connected',
      now(),
      now()
    WHERE EXISTS (
      SELECT 1 FROM platform_agents WHERE owner_human_id IS NULL
    )
    ON CONFLICT (privy_user_id) DO NOTHING
    """)

    execute("""
    UPDATE platform_agents
    SET owner_human_id = human.id
    FROM platform_human_users AS human
    WHERE platform_agents.owner_human_id IS NULL
      AND human.privy_user_id = 'platform-house-owner'
    """)

    execute("""
    INSERT INTO platform_companies (
      owner_human_id,
      name,
      slug,
      claimed_label,
      status,
      public_summary,
      hero_statement,
      metadata,
      created_at,
      updated_at
    )
    SELECT
      owner_human_id,
      name,
      slug,
      claimed_label,
      status,
      public_summary,
      hero_statement,
      '{}'::jsonb,
      created_at,
      updated_at
    FROM platform_agents
    WHERE company_id IS NULL
    """)

    execute("""
    UPDATE platform_agents AS agent
    SET company_id = company.id
    FROM platform_companies AS company
    WHERE agent.company_id IS NULL
      AND company.slug = agent.slug
    """)

    execute("""
    ALTER TABLE platform_agents
      ALTER COLUMN company_id SET NOT NULL
    """)

    create index(:platform_agents, [:company_id])

    execute("""
    CREATE OR REPLACE FUNCTION platform_create_company_for_agent()
    RETURNS trigger AS $$
    BEGIN
      IF NEW.company_id IS NULL THEN
        INSERT INTO platform_companies (
          owner_human_id,
          name,
          slug,
          claimed_label,
          status,
          public_summary,
          hero_statement,
          metadata,
          created_at,
          updated_at
        )
        VALUES (
          NEW.owner_human_id,
          NEW.name,
          NEW.slug,
          NEW.claimed_label,
          NEW.status,
          NEW.public_summary,
          NEW.hero_statement,
          '{}'::jsonb,
          COALESCE(NEW.created_at, now()),
          COALESCE(NEW.updated_at, now())
        )
        RETURNING id INTO NEW.company_id;
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER platform_agents_company_before_insert
    BEFORE INSERT ON platform_agents
    FOR EACH ROW
    EXECUTE FUNCTION platform_create_company_for_agent()
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS platform_agents_company_before_insert ON platform_agents")
    execute("DROP FUNCTION IF EXISTS platform_create_company_for_agent()")

    drop_if_exists index(:platform_agents, [:company_id])

    alter table(:platform_agents) do
      remove :company_id
    end

    drop_if_exists index(:platform_companies, [:status, :slug],
                     name: :platform_companies_status_slug_idx
                   )

    drop_if_exists index(:platform_companies, [:owner_human_id, :updated_at],
                     name: :platform_companies_owner_updated_idx
                   )

    drop_if_exists unique_index(:platform_companies, [:claimed_label])
    drop_if_exists unique_index(:platform_companies, [:slug])
    drop table(:platform_companies)
  end
end
