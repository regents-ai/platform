defmodule PlatformPhx.RegentStaking do
  @moduledoc false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Ethereum
  alias PlatformPhx.RegentStaking.Abi
  alias PlatformPhx.RuntimeConfig
  alias PlatformPhx.WalletAction

  @usdc_decimals 6
  @token_decimals 18

  def overview(current_human \\ nil) do
    with {:ok, cfg} <- config(),
         {:ok, state} <- load_state(cfg, primary_wallet_address(current_human)) do
      {:ok, state}
    end
  end

  def account(address, current_human \\ nil) do
    with {:ok, cfg} <- config(),
         {:ok, wallet_address} <- normalize_required_address(address),
         {:ok, state} <- load_state(cfg, wallet_address) do
      {:ok, Map.put(state, :connected_wallet_address, primary_wallet_address(current_human))}
    end
  end

  def stake(attrs, principal) do
    with {:ok, cfg} <- config(),
         {:ok, wallet_address} <- required_wallet(principal),
         {:ok, amount} <- parse_amount(Map.get(attrs, "amount"), @token_decimals) do
      {:ok,
       %{
         staking: compact_state(cfg, wallet_address),
         wallet_action:
           wallet_action(%{
             "resource" => "regent_staking",
             "action" => "stake",
             "expected_signer" => wallet_address,
             "chain_id" => cfg.chain_id,
             "to" => cfg.contract_address,
             "value" => "0x0",
             "data" => Abi.encode_stake(amount, wallet_address)
           })
       }}
    end
  end

  def unstake(attrs, principal) do
    with {:ok, cfg} <- config(),
         {:ok, wallet_address} <- required_wallet(principal),
         {:ok, amount} <- parse_amount(Map.get(attrs, "amount"), @token_decimals) do
      {:ok,
       %{
         staking: compact_state(cfg, wallet_address),
         wallet_action:
           wallet_action(%{
             "resource" => "regent_staking",
             "action" => "unstake",
             "expected_signer" => wallet_address,
             "chain_id" => cfg.chain_id,
             "to" => cfg.contract_address,
             "value" => "0x0",
             "data" => Abi.encode_unstake(amount, wallet_address)
           })
       }}
    end
  end

  def claim_usdc(_attrs, principal) do
    with {:ok, cfg} <- config(),
         {:ok, wallet_address} <- required_wallet(principal) do
      {:ok,
       %{
         staking: compact_state(cfg, wallet_address),
         wallet_action:
           wallet_action(%{
             "resource" => "regent_staking",
             "action" => "claim_usdc",
             "expected_signer" => wallet_address,
             "chain_id" => cfg.chain_id,
             "to" => cfg.contract_address,
             "value" => "0x0",
             "data" => Abi.encode_claim_usdc(wallet_address)
           })
       }}
    end
  end

  def claim_regent(_attrs, principal) do
    with {:ok, cfg} <- config(),
         {:ok, wallet_address} <- required_wallet(principal) do
      {:ok,
       %{
         staking: compact_state(cfg, wallet_address),
         wallet_action:
           wallet_action(%{
             "resource" => "regent_staking",
             "action" => "claim_regent",
             "expected_signer" => wallet_address,
             "chain_id" => cfg.chain_id,
             "to" => cfg.contract_address,
             "value" => "0x0",
             "data" => Abi.encode_claim_regent(wallet_address)
           })
       }}
    end
  end

  def claim_and_restake_regent(_attrs, principal) do
    with {:ok, cfg} <- config(),
         {:ok, wallet_address} <- required_wallet(principal) do
      {:ok,
       %{
         staking: compact_state(cfg, wallet_address),
         wallet_action:
           wallet_action(%{
             "resource" => "regent_staking",
             "action" => "claim_and_restake_regent",
             "expected_signer" => wallet_address,
             "chain_id" => cfg.chain_id,
             "to" => cfg.contract_address,
             "value" => "0x0",
             "data" => Abi.encode_claim_and_restake_regent()
           })
       }}
    end
  end

  def validate_config do
    with {:ok, cfg} <- config() do
      validate_rpc(cfg)
    end
  end

  def validate_rpc(%{
        rpc_url: rpc_url,
        chain_id: expected_chain_id,
        contract_address: contract_address
      }) do
    with {:ok, observed_chain_id} <- rpc_chain_id(rpc_url),
         :ok <- ensure_chain_id(observed_chain_id, expected_chain_id),
         {:ok, _owner} <- call_address(contract_address, Abi.encode_call(:owner), rpc_url) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  defp load_state(cfg, wallet_address) do
    with {:ok, owner} <-
           call_address(cfg.contract_address, Abi.encode_call(:owner), cfg.rpc_url),
         {:ok, stake_token} <-
           call_address(cfg.contract_address, Abi.encode_call(:stake_token), cfg.rpc_url),
         {:ok, usdc} <- call_address(cfg.contract_address, Abi.encode_call(:usdc), cfg.rpc_url),
         {:ok, treasury_recipient} <-
           call_address(cfg.contract_address, Abi.encode_call(:treasury_recipient), cfg.rpc_url),
         {:ok, staker_share_bps} <-
           call_uint(cfg.contract_address, Abi.encode_call(:staker_share_bps), cfg.rpc_url),
         {:ok, paused} <- call_bool(cfg.contract_address, Abi.encode_call(:paused), cfg.rpc_url),
         {:ok, total_staked} <-
           call_uint(cfg.contract_address, Abi.encode_call(:total_staked), cfg.rpc_url),
         {:ok, treasury_residual_usdc} <-
           call_uint(cfg.contract_address, Abi.encode_call(:treasury_residual_usdc), cfg.rpc_url),
         {:ok, total_recognized_rewards_usdc} <-
           call_uint(
             cfg.contract_address,
             Abi.encode_call(:total_recognized_rewards_usdc),
             cfg.rpc_url
           ),
         {:ok, materialized_outstanding} <-
           call_uint(
             cfg.contract_address,
             Abi.encode_call(:unclaimed_regent_liability),
             cfg.rpc_url
           ),
         {:ok, available_reward_inventory} <-
           call_uint(
             cfg.contract_address,
             Abi.encode_call(:available_regent_reward_inventory),
             cfg.rpc_url
           ),
         {:ok, total_claimed_so_far} <-
           call_uint(cfg.contract_address, Abi.encode_call(:total_claimed_regent), cfg.rpc_url),
         {:ok, wallet_stake_balance_raw} <-
           optional_uint_call(
             wallet_address,
             cfg.contract_address,
             fn address -> Abi.encode_address_call(:staked_balance, address) end,
             cfg.rpc_url
           ),
         {:ok, wallet_claimable_usdc_raw} <-
           optional_uint_call(
             wallet_address,
             cfg.contract_address,
             fn address -> Abi.encode_address_call(:preview_claimable_usdc, address) end,
             cfg.rpc_url
           ),
         {:ok, wallet_claimable_regent_raw} <-
           optional_uint_call(
             wallet_address,
             cfg.contract_address,
             fn address -> Abi.encode_address_call(:preview_claimable_regent, address) end,
             cfg.rpc_url
           ),
         {:ok, wallet_token_balance_raw} <-
           optional_uint_call(
             wallet_address,
             stake_token,
             fn address -> Abi.encode_address_call(:balance_of, address) end,
             cfg.rpc_url
           ) do
      {:ok,
       %{
         chain_id: cfg.chain_id,
         chain_label: cfg.chain_label,
         contract_address: cfg.contract_address,
         owner_address: owner,
         stake_token_address: stake_token,
         usdc_address: usdc,
         treasury_recipient: treasury_recipient,
         staker_share_bps: staker_share_bps,
         paused: paused,
         total_staked_raw: raw_amount(total_staked),
         total_staked: format_units(total_staked, @token_decimals),
         total_recognized_rewards_usdc_raw: raw_amount(total_recognized_rewards_usdc),
         total_recognized_rewards_usdc:
           format_units(total_recognized_rewards_usdc, @usdc_decimals),
         treasury_residual_usdc_raw: raw_amount(treasury_residual_usdc),
         treasury_residual_usdc: format_units(treasury_residual_usdc, @usdc_decimals),
         materialized_outstanding_raw: raw_amount(materialized_outstanding),
         materialized_outstanding: format_units(materialized_outstanding, @token_decimals),
         available_reward_inventory_raw: raw_amount(available_reward_inventory),
         available_reward_inventory: format_units(available_reward_inventory, @token_decimals),
         total_claimed_so_far_raw: raw_amount(total_claimed_so_far),
         total_claimed_so_far: format_units(total_claimed_so_far, @token_decimals),
         wallet_address: wallet_address,
         wallet_stake_balance_raw: raw_amount(wallet_stake_balance_raw),
         wallet_stake_balance: format_optional_units(wallet_stake_balance_raw, @token_decimals),
         wallet_token_balance_raw: raw_amount(wallet_token_balance_raw),
         wallet_token_balance: format_optional_units(wallet_token_balance_raw, @token_decimals),
         wallet_claimable_usdc_raw: raw_amount(wallet_claimable_usdc_raw),
         wallet_claimable_usdc: format_optional_units(wallet_claimable_usdc_raw, @usdc_decimals),
         wallet_claimable_regent_raw: raw_amount(wallet_claimable_regent_raw),
         wallet_claimable_regent:
           format_optional_units(wallet_claimable_regent_raw, @token_decimals)
       }}
    else
      {:error, _reason} -> {:error, :unavailable}
    end
  end

  defp compact_state(cfg, wallet_address) do
    %{
      chain_id: cfg.chain_id,
      chain_label: cfg.chain_label,
      contract_address: cfg.contract_address,
      wallet_address: wallet_address
    }
  end

  defp config do
    runtime_config = runtime_config_module()
    contract_address = runtime_config.regent_staking_contract_address() |> normalize_address()
    rpc_url = runtime_config.regent_staking_rpc_url() |> normalize_string()

    if blank?(contract_address) or blank?(rpc_url) do
      {:error, :unconfigured}
    else
      {:ok,
       %{
         chain_id: runtime_config.regent_staking_chain_id(),
         chain_label: runtime_config.regent_staking_chain_label(),
         contract_address: contract_address,
         rpc_url: rpc_url
       }}
    end
  end

  defp call_uint(to, data, rpc_url) do
    with {:ok, result} <-
           ethereum_module().json_rpc(rpc_url, "eth_call", [%{to: to, data: data}, "latest"]) do
      {:ok, Abi.decode_uint256(result)}
    else
      {:error, _reason} -> {:error, :upstream_unavailable}
    end
  rescue
    _ -> {:error, :upstream_unavailable}
  end

  defp call_address(to, data, rpc_url) do
    with {:ok, result} <-
           ethereum_module().json_rpc(rpc_url, "eth_call", [%{to: to, data: data}, "latest"]) do
      {:ok, Abi.decode_address(result)}
    else
      {:error, _reason} -> {:error, :upstream_unavailable}
    end
  rescue
    _ -> {:error, :upstream_unavailable}
  end

  defp call_bool(to, data, rpc_url) do
    with {:ok, result} <-
           ethereum_module().json_rpc(rpc_url, "eth_call", [%{to: to, data: data}, "latest"]) do
      {:ok, Abi.decode_bool(result)}
    else
      {:error, _reason} -> {:error, :upstream_unavailable}
    end
  rescue
    _ -> {:error, :upstream_unavailable}
  end

  defp optional_uint_call(nil, _to, _encoder, _rpc_url), do: {:ok, nil}

  defp optional_uint_call(address, to, encoder, rpc_url) when is_function(encoder, 1) do
    call_uint(to, encoder.(address), rpc_url)
  end

  defp rpc_chain_id(rpc_url) do
    with {:ok, result} <- ethereum_module().json_rpc(rpc_url, "eth_chainId", []) do
      {:ok, Ethereum.hex_to_integer(result)}
    else
      {:error, _reason} -> {:error, :rpc_unavailable}
    end
  rescue
    _error -> {:error, :rpc_unavailable}
  end

  defp ensure_chain_id(observed_chain_id, expected_chain_id)
       when observed_chain_id == expected_chain_id,
       do: :ok

  defp ensure_chain_id(observed_chain_id, expected_chain_id) do
    {:error, {:wrong_chain_id, observed: observed_chain_id, expected: expected_chain_id}}
  end

  defp required_wallet(%HumanUser{} = human) do
    case primary_wallet_address(human) do
      nil -> {:error, :unauthorized}
      address -> {:ok, address}
    end
  end

  defp required_wallet(%{"wallet_address" => wallet_address}) do
    case normalize_address(wallet_address) do
      nil -> {:error, :unauthorized}
      address -> {:ok, address}
    end
  end

  defp required_wallet(_principal), do: {:error, :unauthorized}

  defp primary_wallet_address(%HumanUser{} = human) do
    [human.wallet_address | List.wrap(human.wallet_addresses)]
    |> Enum.find(&(is_binary(&1) and String.trim(&1) != ""))
    |> normalize_address()
  end

  defp primary_wallet_address(%{"wallet_address" => wallet_address}),
    do: normalize_address(wallet_address)

  defp primary_wallet_address(_principal), do: nil

  defp wallet_action(attrs), do: WalletAction.from_tx(attrs)

  defp parse_amount(value, decimals) when is_binary(value) do
    trimmed = String.trim(value)

    with {decimal, ""} <- Decimal.parse(trimmed),
         true <- Decimal.compare(decimal, 0) == :gt || {:error, :amount_required},
         scaled <- Decimal.mult(decimal, Decimal.new(integer_pow10(decimals))),
         true <-
           Decimal.compare(scaled, Decimal.round(scaled, 0)) == :eq ||
             {:error, :invalid_amount_precision} do
      {:ok, Decimal.to_integer(scaled)}
    else
      :error -> {:error, :amount_required}
      {:error, _} = error -> error
      _ -> {:error, :amount_required}
    end
  end

  defp parse_amount(_value, _decimals), do: {:error, :amount_required}

  defp normalize_required_address(value) do
    case normalize_address(value) do
      nil -> {:error, :invalid_address}
      address -> {:ok, address}
    end
  end

  defp normalize_address(value) when is_binary(value), do: Ethereum.normalize_address(value)
  defp normalize_address(_value), do: nil

  defp normalize_string(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_string(_value), do: nil

  defp format_units(value, decimals) when is_integer(value) do
    value
    |> Decimal.new()
    |> Decimal.div(Decimal.new(integer_pow10(decimals)))
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp format_units(nil, _decimals), do: nil
  defp format_optional_units(nil, _decimals), do: nil
  defp format_optional_units(value, decimals), do: format_units(value, decimals)

  defp raw_amount(nil), do: nil
  defp raw_amount(value) when is_integer(value), do: Integer.to_string(value)

  defp integer_pow10(exponent) when exponent >= 0, do: Integer.pow(10, exponent)

  defp blank?(value), do: value in [nil, ""]

  defp ethereum_module do
    Application.get_env(:platform_phx, :regent_staking, [])
    |> Keyword.get(:ethereum_module, Ethereum)
  end

  defp runtime_config_module do
    Application.get_env(:platform_phx, :regent_staking, [])
    |> Keyword.get(:runtime_config_module, RuntimeConfig)
  end
end
