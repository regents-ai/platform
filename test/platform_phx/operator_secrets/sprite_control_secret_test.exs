defmodule PlatformPhx.OperatorSecrets.SpriteControlSecretTest do
  use ExUnit.Case, async: false

  alias PlatformPhx.OperatorSecrets.SpriteControlSecret

  test "fetch_token returns the configured sprite control token" do
    assert {:ok, "test-sprites-token"} = SpriteControlSecret.fetch_token()
  end

  test "reload reads the token from a locked file and keeps the prior token when permissions are too open" do
    original_config = Application.get_env(:platform_phx, SpriteControlSecret)
    original_path = System.get_env("SPRITES_API_TOKEN_FILE")

    tmp_dir =
      Path.join(System.tmp_dir!(), "sprite-control-secret-#{System.unique_integer([:positive])}")

    secret_path = Path.join(tmp_dir, "sprites-api-token")

    on_exit(fn ->
      if original_path do
        System.put_env("SPRITES_API_TOKEN_FILE", original_path)
      else
        System.delete_env("SPRITES_API_TOKEN_FILE")
      end

      Application.put_env(:platform_phx, SpriteControlSecret, original_config)
      assert :ok = SpriteControlSecret.reload()
      File.rm_rf!(tmp_dir)
    end)

    File.mkdir_p!(tmp_dir)
    File.write!(secret_path, "locked-file-token\n")
    File.chmod!(secret_path, 0o600)

    Application.put_env(:platform_phx, SpriteControlSecret, validate_permissions?: true)
    System.put_env("SPRITES_API_TOKEN_FILE", secret_path)

    assert :ok = SpriteControlSecret.reload()
    assert {:ok, "locked-file-token"} = SpriteControlSecret.fetch_token()

    File.chmod!(secret_path, 0o644)

    assert {:error, {:unavailable, message}} = SpriteControlSecret.reload()
    assert message =~ "must not be readable by group or world"
    assert {:ok, "locked-file-token"} = SpriteControlSecret.fetch_token()
  end
end
