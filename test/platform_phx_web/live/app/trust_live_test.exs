defmodule PlatformPhxWeb.App.TrustLiveTest do
  use PlatformPhxWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Repo

  setup do
    session_id = "sess-live"
    token = "test-token"
    token_hash = :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

    previous = Application.get_env(:platform_phx, :agentbook, [])

    Application.put_env(
      :platform_phx,
      :agentbook,
      registration_module: PlatformPhxWeb.Api.AgentbookControllerTest.RegistrationStub,
      agent_book_module: PlatformPhxWeb.Api.AgentbookControllerTest.AgentBookStub
    )

    Repo.insert_all("platform_agentbook_sessions", [
      %{
        session_id: session_id,
        wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
        chain_id: 84_532,
        registry_address: "0x3333333333333333333333333333333333333333",
        token_id: "77",
        network: "world",
        source: "regents-cli",
        contract_address: "0x8b3f4f36c4564ab38c067ca0d7e2ed7d0d16f987",
        relay_url: "https://relay.example.com",
        nonce: 12,
        approval_token_hash: token_hash,
        app_id: "app_test",
        action: "agentbook-registration",
        rp_id: "app_test",
        signal: "0xfeed",
        rp_context: %{
          "rp_id" => "app_test",
          "nonce" => "nonce-123",
          "created_at" => 1_712_000_000,
          "expires_at" => 1_712_000_300,
          "signature" => "0xsig"
        },
        status: "pending",
        expires_at: ~U[2999-01-01 00:00:00Z],
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])

    on_exit(fn ->
      Application.put_env(:platform_phx, :agentbook, previous)
    end)

    {:ok, session_id: session_id, token: token}
  end

  test "trust page asks the person to sign in before approving", %{
    conn: conn,
    session_id: session_id,
    token: token
  } do
    {:ok, _view, html} = live(conn, "/app/trust?session_id=#{session_id}&token=#{token}")

    assert html =~ "Sign in before you continue."
    assert html =~ "Continue setup"
    refute html =~ "phx-hook=\"AgentbookTrustFlow\""
  end

  test "signed-in person sees the approval flow", %{
    conn: conn,
    session_id: session_id,
    token: token
  } do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "did:privy:live-trust",
        wallet_address: "0x1111111111111111111111111111111111111111",
        wallet_addresses: ["0x1111111111111111111111111111111111111111"],
        display_name: "Live Trust"
      })
      |> Repo.insert!()

    {:ok, _view, html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/app/trust?session_id=#{session_id}&token=#{token}")

    assert html =~ "Connect a human-backed trust record"
    assert html =~ "Connection summary"
    assert html =~ "Connect from your device"
    assert html =~ "Approval status"
    assert html =~ "Connection states"
    assert html =~ "phx-hook=\"AgentbookTrustFlow\""
    assert html =~ "data-session="
  end

  test "expired approval link no longer opens the trust flow", %{
    conn: conn,
    session_id: session_id,
    token: token
  } do
    Repo.update_all(
      from(session in "platform_agentbook_sessions", where: session.session_id == ^session_id),
      set: [expires_at: ~U[2020-01-01 00:00:00Z]]
    )

    {:ok, _view, html} = live(conn, "/app/trust?session_id=#{session_id}&token=#{token}")

    assert html =~ "We could not finish this approval."
    refute html =~ "phx-hook=\"AgentbookTrustFlow\""
  end
end
