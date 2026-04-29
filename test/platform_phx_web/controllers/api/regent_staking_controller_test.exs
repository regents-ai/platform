defmodule PlatformPhxWeb.Api.RegentStakingControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  defmodule RegentStakingStub do
    def overview(%{"wallet_address" => wallet_address}) do
      {:ok,
       %{
         chain_id: 8453,
         chain_label: "Base",
         contract_address: "0x9999999999999999999999999999999999999999",
         wallet_address: wallet_address,
         total_staked: "1500"
       }}
    end

    def account(address, %{"wallet_address" => wallet_address}) do
      {:ok, %{wallet_address: String.downcase(address), wallet_claimable_usdc: "12"}}
      |> then(fn {:ok, payload} ->
        {:ok, Map.put(payload, :connected_wallet_address, wallet_address)}
      end)
    end

    def stake(%{"amount" => "1.5"}, %{"wallet_address" => wallet_address}) do
      {:ok,
       %{
         staking: %{wallet_address: wallet_address},
         wallet_action: %{
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
         wallet_action: %{
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
         wallet_action: %{
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
         wallet_action: %{
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
         wallet_action: %{
           chain_id: 8453,
           to: "0x9999999999999999999999999999999999999999",
           value: "0x0",
           data: "0xe72a8732"
         }
       }}
    end
  end

  setup do
    original = Application.get_env(:platform_phx, :regent_staking_api, [])
    previous_siwa = Application.get_env(:platform_phx, :siwa_client)
    Application.put_env(:platform_phx, :regent_staking_api, context_module: RegentStakingStub)
    Application.put_env(:platform_phx, :siwa_client, PlatformPhx.TestSiwaClient)

    on_exit(fn ->
      Application.put_env(:platform_phx, :regent_staking_api, original)
      Application.put_env(:platform_phx, :siwa_client, previous_siwa)
    end)

    :ok
  end

  test "show returns the regent staking overview", %{conn: conn} do
    conn =
      conn
      |> put_siwa_headers()
      |> get("/v1/agent/regent/staking")

    assert %{
             "ok" => true,
             "chain_id" => 8453,
             "wallet_address" => "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
             "total_staked" => "1500"
           } = json_response(conn, 200)
  end

  test "account returns account state", %{conn: conn} do
    conn =
      conn
      |> put_siwa_headers()
      |> get("/v1/agent/regent/staking/account/0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")

    assert %{
             "ok" => true,
             "wallet_address" => "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
             "connected_wallet_address" => "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
             "wallet_claimable_usdc" => "12"
           } = json_response(conn, 200)
  end

  test "stake returns a wallet action", %{conn: conn} do
    conn =
      conn
      |> put_siwa_headers()
      |> post("/v1/agent/regent/staking/stake", %{"amount" => "1.5"})

    assert %{
             "ok" => true,
             "staking" => %{
               "wallet_address" => "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
             },
             "wallet_action" => %{"chain_id" => 8453, "data" => "0x7acb7757"}
           } = json_response(conn, 200)
  end

  test "unstake returns a wallet action", %{conn: conn} do
    conn =
      conn
      |> put_siwa_headers()
      |> post("/v1/agent/regent/staking/unstake", %{"amount" => "1.5"})

    assert %{
             "ok" => true,
             "wallet_action" => %{"chain_id" => 8453, "data" => "0x8381e182"}
           } = json_response(conn, 200)
  end

  test "claim usdc returns a wallet action", %{conn: conn} do
    conn =
      conn
      |> put_siwa_headers()
      |> post("/v1/agent/regent/staking/claim-usdc", %{})

    assert %{
             "ok" => true,
             "wallet_action" => %{"chain_id" => 8453, "data" => "0x42852610"}
           } = json_response(conn, 200)
  end

  test "claim regent returns a wallet action", %{conn: conn} do
    conn =
      conn
      |> put_siwa_headers()
      |> post("/v1/agent/regent/staking/claim-regent", %{})

    assert %{
             "ok" => true,
             "wallet_action" => %{"chain_id" => 8453, "data" => "0x739c8d0d"}
           } = json_response(conn, 200)
  end

  test "claim and restake regent returns a wallet action", %{conn: conn} do
    conn =
      conn
      |> put_siwa_headers()
      |> post("/v1/agent/regent/staking/claim-and-restake-regent", %{})

    assert %{
             "ok" => true,
             "wallet_action" => %{"chain_id" => 8453, "data" => "0xe72a8732"}
           } = json_response(conn, 200)
  end

  test "stake returns amount validation message", %{conn: conn} do
    response =
      conn
      |> put_siwa_headers()
      |> post("/v1/agent/regent/staking/stake", %{})
      |> json_response(400)

    assert response["error"]["message"] == "Enter an amount before continuing"
  end

  test "stake hides unexpected internal errors", %{conn: conn} do
    response =
      conn
      |> put_siwa_headers()
      |> post("/v1/agent/regent/staking/stake", %{"amount" => "explode"})
      |> json_response(400)

    assert response["error"]["message"] == "Could not prepare that staking action right now."
    refute response["error"]["message"] =~ "external"
    refute response["error"]["message"] =~ "500"
    refute response["error"]["message"] =~ "upstream"
    refute response["error"]["message"] =~ "%{"
  end

  test "stale public staking route is not served", %{conn: conn} do
    conn =
      conn
      |> put_siwa_headers()
      |> get("/api/regent/staking")

    assert response(conn, 404)
  end

  defp put_siwa_headers(conn) do
    put_req_header(conn, "x-siwa-receipt", "regents-receipt")
  end
end
