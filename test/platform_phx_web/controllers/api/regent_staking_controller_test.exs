defmodule PlatformPhxWeb.Api.RegentStakingControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Repo

  @operator_wallet "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  @other_wallet "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

  defmodule RegentStakingStub do
    def overview(_human) do
      {:ok,
       %{
         chain_id: 8453,
         chain_label: "Base",
         contract_address: "0x9999999999999999999999999999999999999999",
         total_staked: "1500"
       }}
    end

    def account(address, _human) do
      {:ok, %{wallet_address: String.downcase(address), wallet_claimable_usdc: "12"}}
    end

    def stake(%{"amount" => "1.5"}, _human) do
      {:ok,
       %{
         tx_request: %{
           chain_id: 8453,
           to: "0x9999999999999999999999999999999999999999",
           value: "0x0",
           data: "0x7acb7757"
         }
       }}
    end

    def stake(%{"amount" => "explode"}, _human),
      do: {:error, {:external, %{status: 500, body: %{"error" => "upstream"}}}}

    def stake(_params, _human), do: {:error, :amount_required}

    def unstake(_params, _human) do
      {:ok,
       %{
         tx_request: %{
           chain_id: 8453,
           to: "0x9999999999999999999999999999999999999999",
           value: "0x0",
           data: "0x8381e182"
         }
       }}
    end

    def claim_usdc(_params, _human) do
      {:ok,
       %{
         tx_request: %{
           chain_id: 8453,
           to: "0x9999999999999999999999999999999999999999",
           value: "0x0",
           data: "0x42852610"
         }
       }}
    end

    def claim_regent(_params, _human) do
      {:ok,
       %{
         tx_request: %{
           chain_id: 8453,
           to: "0x9999999999999999999999999999999999999999",
           value: "0x0",
           data: "0x739c8d0d"
         }
       }}
    end

    def claim_and_restake_regent(_params, _human) do
      {:ok,
       %{
         tx_request: %{
           chain_id: 8453,
           to: "0x9999999999999999999999999999999999999999",
           value: "0x0",
           data: "0xe72a8732"
         }
       }}
    end

    def prepare_deposit_usdc(_params) do
      {:ok,
       %{
         prepared: %{
           action: "deposit_usdc",
           tx_request: %{
             chain_id: 8453,
             to: "0x9999999999999999999999999999999999999999",
             value: "0x0",
             data: "0x7dc6bb98"
           }
         }
       }}
    end

    def prepare_withdraw_treasury(_params) do
      {:ok,
       %{
         prepared: %{
           action: "withdraw_treasury",
           tx_request: %{
             chain_id: 8453,
             to: "0x9999999999999999999999999999999999999999",
             value: "0x0",
             data: "0xe13b5822"
           }
         }
       }}
    end
  end

  setup do
    original = Application.get_env(:platform_phx, :regent_staking_api, [])
    previous_operator_wallets = System.get_env("REGENT_STAKING_OPERATOR_WALLETS")
    Application.put_env(:platform_phx, :regent_staking_api, context_module: RegentStakingStub)

    on_exit(fn ->
      Application.put_env(:platform_phx, :regent_staking_api, original)
      restore_system_env("REGENT_STAKING_OPERATOR_WALLETS", previous_operator_wallets)
    end)

    :ok
  end

  test "show returns the regent staking overview", %{conn: conn} do
    conn = get(conn, "/api/regent/staking")

    assert %{
             "ok" => true,
             "chain_id" => 8453,
             "total_staked" => "1500"
           } = json_response(conn, 200)
  end

  test "account returns account state", %{conn: conn} do
    conn = get(conn, "/api/regent/staking/account/0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")

    assert %{
             "ok" => true,
             "wallet_address" => "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
             "wallet_claimable_usdc" => "12"
           } = json_response(conn, 200)
  end

  test "stake returns a wallet tx request", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> put_csrf_token()
      |> post("/api/regent/staking/stake", %{"amount" => "1.5"})

    assert %{
             "ok" => true,
             "tx_request" => %{"chain_id" => 8453, "data" => "0x7acb7757"}
           } = json_response(conn, 200)
  end

  test "stake hides unexpected internal errors", %{conn: conn} do
    response =
      conn
      |> init_test_session(%{})
      |> put_csrf_token()
      |> post("/api/regent/staking/stake", %{"amount" => "explode"})
      |> json_response(400)

    assert response["statusMessage"] == "Could not prepare that staking action right now."
    refute response["statusMessage"] =~ "external"
    refute response["statusMessage"] =~ "500"
    refute response["statusMessage"] =~ "upstream"
    refute response["statusMessage"] =~ "%{"
  end

  test "deposit prepare requires an operator wallet", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> put_csrf_token()
      |> post("/api/regent/staking/deposit-usdc/prepare", %{
        "amount" => "250.5",
        "source_tag" => "base_manual",
        "source_ref" => "2026-04"
      })

    assert json_response(conn, 401)["statusMessage"] ==
             "Sign in before preparing treasury actions"
  end

  test "deposit prepare rejects a signed-in non-operator", %{conn: conn} do
    System.put_env("REGENT_STAKING_OPERATOR_WALLETS", @operator_wallet)
    human = insert_human!(@other_wallet)

    conn =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/regent/staking/deposit-usdc/prepare", %{
        "amount" => "250.5",
        "source_tag" => "base_manual",
        "source_ref" => "2026-04"
      })

    assert json_response(conn, 403)["statusMessage"] ==
             "This wallet is not allowed to prepare treasury actions"
  end

  test "deposit prepare returns a multisig payload for an operator", %{conn: conn} do
    System.put_env("REGENT_STAKING_OPERATOR_WALLETS", @operator_wallet)
    human = insert_human!(@operator_wallet)

    conn =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/regent/staking/deposit-usdc/prepare", %{
        "amount" => "250.5",
        "source_tag" => "base_manual",
        "source_ref" => "2026-04"
      })

    assert %{
             "ok" => true,
             "prepared" => %{
               "action" => "deposit_usdc",
               "tx_request" => %{"data" => "0x7dc6bb98"}
             }
           } = json_response(conn, 200)
  end

  defp insert_human!(wallet_address) do
    Repo.insert!(%HumanUser{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: String.downcase(wallet_address),
      wallet_addresses: [String.downcase(wallet_address)],
      display_name: "Operator"
    })
  end

  defp restore_system_env(name, nil), do: System.delete_env(name)
  defp restore_system_env(name, value), do: System.put_env(name, value)

  defp put_csrf_token(conn) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> put_req_header("x-csrf-token", token)
  end
end
