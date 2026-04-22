defmodule PlatformPhx.Dashboard do
  @moduledoc false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhx.Basenames
  alias PlatformPhx.OpenSea

  @type notice_tone :: :error | :info | :success
  @type notice :: %{tone: notice_tone(), message: String.t()}

  @type services_payload :: %{
          authenticated: boolean(),
          wallet_address: String.t() | nil,
          basenames_config: map() | nil,
          basenames_config_notice: notice() | nil,
          allowance: map() | nil,
          allowance_notice: notice() | nil,
          owned_names: [map()],
          owned_names_notice: notice() | nil,
          recent_names: [map()],
          recent_names_notice: notice() | nil,
          claimed_names: [map()],
          available_claims: [map()],
          holdings: map(),
          holdings_notice: notice() | nil,
          redeem_supply: map(),
          redeem_supply_notice: notice() | nil
        }

  @type agent_formation_payload :: %{
          formation: map() | nil,
          notice: notice() | nil
        }

  @type name_claim_state :: %{
          label: String.t(),
          normalized_label: String.t(),
          valid?: boolean(),
          reserved?: boolean(),
          available?: boolean() | nil,
          fqdn: String.t() | nil,
          ens_fqdn: String.t() | nil,
          label_error: String.t() | nil
        }

  @spec services_payload(%HumanUser{} | nil) :: {:ok, services_payload()}
  def services_payload(human) do
    wallet_address = AgentPlatform.current_wallet_address(human)
    claimed_names = AgentPlatform.claimed_names_for_human(human)

    {basenames_config, basenames_config_notice} =
      Basenames.config_payload()
      |> map_result(&map_basenames_config/1, nil, "Name settings are unavailable right now.")

    {allowance, allowance_notice} =
      case wallet_address do
        nil ->
          {nil, nil}

        address ->
          Basenames.allowance_payload(address)
          |> map_result(
            &map_allowance/1,
            nil,
            "Could not load free-claim access for this wallet."
          )
      end

    {owned_names, owned_names_notice} =
      case wallet_address do
        nil ->
          {[], nil}

        address ->
          Basenames.owned_payload(address)
          |> map_result(&map_owned_names/1, [], "Could not load the names held by this wallet.")
      end

    {recent_names, recent_names_notice} =
      Basenames.recent_payload(15)
      |> map_result(&map_recent_names/1, [], "Could not load the latest claimed names.")

    {holdings, holdings_notice} =
      AgentPlatform.holdings_for_human(human)
      |> map_result(
        &map_holdings/1,
        empty_holdings(),
        "Could not load wallet holdings right now."
      )

    {redeem_supply, redeem_supply_notice} =
      OpenSea.fetch_redeem_stats()
      |> map_result(
        &map_redeem_supply/1,
        %{animata: nil, regent_animata_ii: nil},
        "Could not load the latest redemption counts."
      )

    {:ok,
     %{
       authenticated: not is_nil(human),
       wallet_address: wallet_address,
       basenames_config: basenames_config,
       basenames_config_notice: basenames_config_notice,
       allowance: allowance,
       allowance_notice: allowance_notice,
       owned_names: owned_names,
       owned_names_notice: owned_names_notice,
       recent_names: recent_names,
       recent_names_notice: recent_names_notice,
       claimed_names: claimed_names,
       available_claims: Enum.reject(claimed_names, & &1.in_use),
       holdings: holdings,
       holdings_notice: holdings_notice,
       redeem_supply: redeem_supply,
       redeem_supply_notice: redeem_supply_notice
     }}
  end

  @spec agent_formation_payload(%HumanUser{} | nil) :: {:ok, agent_formation_payload()}
  def agent_formation_payload(human) do
    case Formation.formation_payload(human) do
      {:ok, payload} ->
        {:ok, %{formation: map_formation_payload(payload), notice: nil}}

      {:error, _reason} ->
        {:ok,
         %{
           formation: nil,
           notice: %{tone: :error, message: "Agent Formation is unavailable right now."}
         }}
    end
  end

  @spec name_claim_state(term(), String.t() | nil, String.t() | nil) :: name_claim_state()
  def name_claim_state(raw_label, _parent_name, _ens_parent_name) do
    label = normalize_label(raw_label)

    case Basenames.validate_label(label) do
      {:ok, normalized_label} ->
        case Basenames.availability_payload(normalized_label) do
          {:ok, payload} ->
            %{
              label: label,
              normalized_label: normalized_label,
              valid?: true,
              reserved?: payload["reserved"] == true,
              available?: payload["available"],
              fqdn: payload["fqdn"],
              ens_fqdn: payload["ensFqdn"],
              label_error: nil
            }

          {:error, {:bad_request, message}} ->
            invalid_name_claim_state(label, message)

          {:error, _reason} ->
            unavailable_name_claim_state(label, normalized_label)
        end

      {:error, {:bad_request, message}} ->
        invalid_name_claim_state(label, message)

      {:error, _reason} ->
        invalid_name_claim_state(label, "Enter a valid name.")
    end
  end

  defp invalid_name_claim_state(label, message) do
    %{
      label: label,
      normalized_label: normalize_label(label),
      valid?: false,
      reserved?: false,
      available?: nil,
      fqdn: nil,
      ens_fqdn: nil,
      label_error: message
    }
  end

  defp unavailable_name_claim_state(label, normalized_label) do
    %{
      label: label,
      normalized_label: normalized_label,
      valid?: false,
      reserved?: false,
      available?: nil,
      fqdn: nil,
      ens_fqdn: nil,
      label_error: "Name settings are unavailable right now."
    }
  end

  defp normalize_label(value) when is_binary(value), do: String.trim(value)
  defp normalize_label(_value), do: ""

  defp map_result({:ok, payload}, mapper, _default, _message), do: {mapper.(payload), nil}

  defp map_result({:error, _reason}, _mapper, default, message) do
    {default, %{tone: :error, message: message}}
  end

  defp map_basenames_config(payload) do
    %{
      parent_name: payload["parentName"],
      ens_parent_name: payload["ensParentName"],
      price_wei: payload["priceWei"],
      payment_recipient: payload["paymentRecipient"]
    }
  end

  defp map_allowance(payload) do
    %{
      snapshot_total: payload["snapshotTotal"] || 0,
      free_mints_used: payload["freeMintsUsed"] || 0,
      free_mints_remaining: payload["freeMintsRemaining"] || 0
    }
  end

  defp map_owned_names(%{"names" => names}) when is_list(names) do
    Enum.map(names, fn name ->
      %{
        label: name["label"],
        fqdn: name["fqdn"],
        ens_fqdn: name["ensFqdn"],
        ens_tx_hash: name["ensTxHash"],
        is_free: name["isFree"] == true,
        is_in_use: name["isInUse"] == true,
        created_at: name["createdAt"]
      }
    end)
  end

  defp map_owned_names(_payload), do: []

  defp map_recent_names(%{"names" => names}) when is_list(names) do
    Enum.map(names, fn name ->
      %{
        label: name["label"],
        fqdn: name["fqdn"],
        created_at: name["createdAt"]
      }
    end)
  end

  defp map_recent_names(_payload), do: []

  defp map_holdings(payload) when is_map(payload) do
    %{
      animata1: Map.get(payload, "animata1", []),
      animata2: Map.get(payload, "animata2", []),
      animata_pass: Map.get(payload, "animataPass", [])
    }
  end

  defp map_holdings(_payload), do: empty_holdings()

  defp map_redeem_supply(payload) when is_map(payload) do
    %{
      animata: Map.get(payload, "animata"),
      regent_animata_ii: Map.get(payload, "regent-animata-ii")
    }
  end

  defp map_redeem_supply(_payload), do: %{animata: nil, regent_animata_ii: nil}

  defp map_formation_payload(payload) when is_map(payload) do
    collections = Map.get(payload, :collections) || Map.get(payload, "collections") || %{}

    %{
      authenticated:
        Map.get(payload, :authenticated) || Map.get(payload, "authenticated") || false,
      wallet_address: Map.get(payload, :wallet_address) || Map.get(payload, "wallet_address"),
      eligible: Map.get(payload, :eligible) || Map.get(payload, "eligible") || false,
      collections: map_holdings(collections),
      claimed_names: Map.get(payload, :claimed_names) || Map.get(payload, "claimed_names") || [],
      available_claims:
        Map.get(payload, :available_claims) || Map.get(payload, "available_claims") || [],
      billing_account:
        Map.get(payload, :billing_account) || Map.get(payload, "billing_account") || %{},
      owned_companies:
        Map.get(payload, :owned_companies) || Map.get(payload, "owned_companies") || [],
      active_formations:
        Map.get(payload, :active_formations) || Map.get(payload, "active_formations") || []
    }
  end

  defp empty_holdings do
    %{
      animata1: [],
      animata2: [],
      animata_pass: []
    }
  end
end
