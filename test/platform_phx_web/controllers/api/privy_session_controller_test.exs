defmodule PlatformPhxWeb.Api.PrivySessionControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.Accounts
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Repo

  defmodule PrivyStub do
    def verify_token("good-token") do
      {:ok,
       %{
         privy_user_id: "did:privy:test-user",
         wallet_address: "0x1111111111111111111111111111111111111111",
         wallet_addresses: [
           "0x1111111111111111111111111111111111111111",
           "0x2222222222222222222222222222222222222222"
         ]
       }}
    end

    def verify_token("bad-human-token") do
      {:ok,
       %{
         privy_user_id: "",
         wallet_address: "0x1111111111111111111111111111111111111111",
         wallet_addresses: ["0x1111111111111111111111111111111111111111"]
       }}
    end

    def verify_token(_token), do: {:error, :invalid_token}
  end

  defmodule XmtpIdentityStub do
    def ensure_identity(%HumanUser{} = human) do
      case ready_inbox_id(human) do
        {:ok, _inbox_id} ->
          {:ok, {:ready, human}}

        {:error, :xmtp_identity_required} ->
          {:ok,
           {:signature_required, human,
            %{
              "inbox_id" => nil,
              "wallet_address" => human.wallet_address,
              "client_id" => "xmtp-client-1",
              "signature_request_id" => "xmtp-signature-1",
              "signature_text" => "Sign to join Regent rooms"
            }}}
      end
    end

    def ready_inbox_id(%HumanUser{xmtp_inbox_id: "inbox-ready"}), do: {:ok, "inbox-ready"}
    def ready_inbox_id(%HumanUser{}), do: {:error, :xmtp_identity_required}

    def complete_identity(%HumanUser{} = human, wallet_address, attrs) do
      with ^wallet_address <- Map.get(attrs, "wallet_address"),
           "xmtp-client-1" <- Map.get(attrs, "client_id"),
           "xmtp-signature-1" <- Map.get(attrs, "signature_request_id"),
           signature when is_binary(signature) <- Map.get(attrs, "signature") do
        Accounts.update_human(human, %{
          "wallet_address" => wallet_address,
          "xmtp_inbox_id" => "inbox-ready"
        })
      else
        nil -> {:error, {:missing, "signature"}}
        _value -> {:error, :wallet_address_mismatch}
      end
    end
  end

  setup do
    original = Application.get_env(:platform_phx, :privy_session_controller, [])

    Application.put_env(
      :platform_phx,
      :privy_session_controller,
      privy_module: PrivyStub,
      xmtp_identity_module: XmtpIdentityStub
    )

    on_exit(fn ->
      Application.put_env(:platform_phx, :privy_session_controller, original)
    end)

    :ok
  end

  test "create signs in a human with the verified wallet and ignores posted wallet fields", %{
    conn: conn
  } do
    response =
      conn
      |> init_test_session(%{})
      |> put_csrf_token()
      |> put_req_header("authorization", "Bearer good-token")
      |> post("/api/auth/privy/session", %{
        wallet_address: "0x45C9a201e2937608905fEF17De9A67f25F9f98E0",
        display_name: "Regent Operator",
        role: "admin"
      })
      |> json_response(200)

    assert response["ok"] == true
    assert response["authenticated"] == true
    assert response["xmtp"]["status"] == "signature_required"
    assert response["xmtp"]["wallet_address"] == "0x1111111111111111111111111111111111111111"
    assert response["xmtp"]["client_id"] == "xmtp-client-1"
    refute Map.has_key?(response["human"], "role")
    assert is_nil(response["human"]["xmtp_inbox_id"])

    human = Repo.get_by!(HumanUser, privy_user_id: "did:privy:test-user")

    assert human.wallet_address == "0x1111111111111111111111111111111111111111"
    assert is_nil(human.xmtp_inbox_id)

    assert human.wallet_addresses == [
             "0x1111111111111111111111111111111111111111",
             "0x2222222222222222222222222222222222222222"
           ]

    assert human.display_name == "Regent Operator"
  end

  test "complete_xmtp saves a ready room identity for the signed-in human", %{conn: conn} do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "did:privy:xmtp-user",
        wallet_address: "0x1111111111111111111111111111111111111111",
        wallet_addresses: ["0x1111111111111111111111111111111111111111"],
        display_name: "Room Human"
      })
      |> Repo.insert!()

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/auth/privy/xmtp/complete", %{
        "wallet_address" => "0x1111111111111111111111111111111111111111",
        "client_id" => "xmtp-client-1",
        "signature_request_id" => "xmtp-signature-1",
        "signature" => "0xsigned"
      })
      |> json_response(200)

    assert response["ok"] == true
    assert response["authenticated"] == true
    assert response["xmtp"]["status"] == "ready"
    assert response["xmtp"]["inbox_id"] == "inbox-ready"
    assert response["human"]["xmtp_inbox_id"] == "inbox-ready"

    assert Repo.get!(HumanUser, human.id).xmtp_inbox_id == "inbox-ready"
  end

  test "csrf bootstrap returns a request token and session cookie", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> get("/api/auth/privy/csrf")

    response = json_response(conn, 200)

    assert response["ok"] == true
    assert is_binary(response["csrf_token"])
    assert response["csrf_token"] != ""

    assert Enum.any?(
             Plug.Conn.get_resp_header(conn, "set-cookie"),
             &String.contains?(&1, "_platform_phx_key")
           )
  end

  test "create rejects a missing csrf token", %{conn: conn} do
    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> init_test_session(%{})
      |> put_req_header("authorization", "Bearer good-token")
      |> post("/api/auth/privy/session", %{display_name: "Regent Operator"})
    end
  end

  test "create hides profile save internals from public errors", %{conn: conn} do
    response =
      conn
      |> init_test_session(%{})
      |> put_csrf_token()
      |> put_req_header("authorization", "Bearer bad-human-token")
      |> post("/api/auth/privy/session", %{display_name: "Regent Operator"})
      |> json_response(400)

    assert response["error"]["message"] ==
             "We could not save that profile. Check the name and try again."

    refute_public_leak(response["error"]["message"])
  end

  test "signed-in human can save a shader avatar through the profile route", %{conn: conn} do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "did:privy:avatar-user",
        wallet_address: "0x1111111111111111111111111111111111111111",
        wallet_addresses: ["0x1111111111111111111111111111111111111111"],
        display_name: "Avatar Owner"
      })
      |> Repo.insert!()

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> put("/api/auth/privy/profile/avatar", %{
        "kind" => "custom_shader",
        "shader_id" => "w3dfWN",
        "define_values" => %{}
      })
      |> json_response(200)

    assert response["authenticated"] == true
    assert response["human"]["avatar"]["kind"] == "custom_shader"
    assert response["human"]["avatar"]["shader_id"] == "w3dfWN"
    assert response["human"]["avatar"]["preview_type"] == "shader"

    updated_human = Repo.get!(HumanUser, human.id)
    assert updated_human.avatar["kind"] == "custom_shader"
    assert updated_human.avatar["shader_id"] == "w3dfWN"
  end

  defp put_csrf_token(conn) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> put_req_header("x-csrf-token", token)
  end

  defp refute_public_leak(message) do
    refute message =~ "privy_user_id"
    refute message =~ "can't be blank"
    refute message =~ "%{"
    refute message =~ "{:"
  end
end
