defmodule PlatformPhx.InfrastructureConfigTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  test "production runtime uses pooled database URL settings" do
    runtime = File.read!(Path.join(@root, "config/runtime.exs"))

    assert runtime =~ ~s|System.get_env("DATABASE_URL")|
    refute runtime =~ "DATABASE_DIRECT_URL"
    assert runtime =~ "ssl: true"
    assert runtime =~ "prepare: :unnamed"

    assert runtime =~ ~S<System.get_env("ECTO_POOL_SIZE") || "5">
    assert runtime =~ ~s(migration_default_prefix: "platform")
    assert runtime =~ ~s(migration_source: "schema_migrations_platform")
  end

  test "release migrations use the direct database URL and platform schema only" do
    release = File.read!(Path.join(@root, "lib/platform_phx/release.ex"))

    assert release =~ ~s|System.fetch_env!("DATABASE_DIRECT_URL")|
    refute release =~ ~s|System.fetch_env!("DATABASE_URL")|
    assert release =~ ~s(@schema "platform")
    assert release =~ ~s(@migration_source "schema_migrations_platform")
    refute release =~ ~s(@schema "autolaunch")
    refute release =~ ~s(@schema "techtree")
  end

  test "release setup documents the direct migration database URL" do
    env_example = File.read!(Path.join(@root, ".env.example"))
    readme = File.read!(Path.join(@root, "README.md"))
    launch_guide = File.read!(Path.join(@root, "docs/regent-local-and-fly-launch-testing.md"))

    assert env_example =~ "DATABASE_DIRECT_URL"
    assert readme =~ "`DATABASE_DIRECT_URL`"
    assert launch_guide =~ "DATABASE_DIRECT_URL=\"$DATABASE_DIRECT_URL\""
  end

  test "Fly deploy workflow checks out the build context used by the Dockerfile" do
    workflow = File.read!(Path.join(@root, ".github/workflows/fly-deploy.yml"))
    dockerfile = File.read!(Path.join(@root, "Dockerfile"))

    assert workflow =~ "path: platform"
    assert workflow =~ "repository: regents-ai/elixir-utils"
    assert workflow =~ "path: elixir-utils"
    assert workflow =~ "flyctl deploy --config platform/fly.toml --remote-only ."

    assert dockerfile =~ "COPY platform/mix.exs platform/mix.lock platform/"
    assert dockerfile =~ "COPY elixir-utils elixir-utils"
  end
end
