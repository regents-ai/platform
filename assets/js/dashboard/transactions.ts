import { createPublicClient, http } from "viem";
import { base, baseSepolia, mainnet } from "viem/chains";

import { ensureWalletReady } from "./wallet_runtime";

export async function signDashboardWalletMessage(
  message: string,
  expectedAddress?: string | null,
): Promise<`0x${string}`> {
  const wallet = ensureWalletReady();

  if (
    expectedAddress &&
    wallet.account.toLowerCase() !== expectedAddress.toLowerCase()
  ) {
    throw new Error("Switch to the wallet connected to this page first.");
  }

  return wallet.walletClient.signMessage({
    account: wallet.account,
    message,
  });
}

type DashboardTxRequest = {
  chain_id: number;
  to: `0x${string}`;
  value?: string | null;
  data?: `0x${string}` | null;
};

type DashboardTxOptions = {
  baseRpcUrl?: string | null;
  baseSepoliaRpcUrl?: string | null;
};

function chainForTransaction(chainId: number) {
  if (chainId === base.id) return base;
  if (chainId === baseSepolia.id) return baseSepolia;
  if (chainId === mainnet.id) return mainnet;
  throw new Error("Switch to the network used by Regent staking, then try again.");
}

function rpcUrlForTransaction(chainId: number, options: DashboardTxOptions) {
  if (chainId === base.id) return options.baseRpcUrl ?? undefined;
  if (chainId === baseSepolia.id) return options.baseSepoliaRpcUrl ?? undefined;
  return undefined;
}

export async function sendDashboardWalletTransaction(
  txRequest: DashboardTxRequest,
  options: DashboardTxOptions = {},
): Promise<`0x${string}`> {
  const wallet = ensureWalletReady();

  if (wallet.chainId !== txRequest.chain_id) {
    throw new Error("Switch your wallet to the Regent staking network before continuing.");
  }

  const chain = chainForTransaction(txRequest.chain_id);
  const value =
    typeof txRequest.value === "string" && txRequest.value.trim() !== ""
      ? BigInt(txRequest.value)
      : 0n;

  const hash = await wallet.walletClient.sendTransaction({
    account: wallet.account,
    chain,
    to: txRequest.to,
    data: txRequest.data ?? undefined,
    value,
  });

  const client = createPublicClient({
    chain,
    transport: http(rpcUrlForTransaction(chain.id, options)),
  });

  const receipt = await client.waitForTransactionReceipt({
    hash,
    timeout: 120_000,
  });

  if (receipt.status !== "success") {
    throw new Error("The staking transaction did not finish successfully.");
  }

  return hash;
}
