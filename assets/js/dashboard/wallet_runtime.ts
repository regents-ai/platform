import { getIdentityToken } from "@privy-io/react-auth";
import { base } from "viem/chains";

import {
  debugHttpError,
  fetchJson,
  privyDebugLog,
  redactWalletForDebug,
} from "./shared";
import {
  emptyWalletBridgeState,
  type WalletBridgeState,
} from "./wallet_bridge_state";

let walletBridgeState: WalletBridgeState = emptyWalletBridgeState();
let walletSessionSyncInFlight: Promise<void> | null = null;
let walletReloadRequested = false;

export const WALLET_SESSION_SYNC_COOLDOWN_MS = 4_000;

type XmtpReadyState = {
  status: "ready";
  inbox_id: string;
  wallet_address: string;
};

type XmtpSignatureRequiredState = {
  status: "signature_required";
  inbox_id: null;
  wallet_address: string;
  client_id: string;
  signature_request_id: string;
  signature_text: string;
};

type PrivySessionResponse = {
  ok: boolean;
  xmtp?: XmtpReadyState | XmtpSignatureRequiredState | null;
};

export function getWalletBridgeState(): WalletBridgeState {
  return walletBridgeState;
}

export function setWalletBridgeState(state: WalletBridgeState): void {
  walletBridgeState = state;
}

export function resetWalletBridgeState(): void {
  walletBridgeState = emptyWalletBridgeState();
}

export function updateWalletBridgeState(
  updater: (state: WalletBridgeState) => WalletBridgeState,
): void {
  walletBridgeState = updater(walletBridgeState);
}

export function isWalletSessionSyncInFlight(): boolean {
  return Boolean(walletSessionSyncInFlight);
}

export function syncPrivySessionOnce(endpoint: string): Promise<void> {
  if (!walletSessionSyncInFlight) {
    walletSessionSyncInFlight = syncPrivySession(endpoint).finally(() => {
      walletSessionSyncInFlight = null;
    });
  }

  return walletSessionSyncInFlight;
}

export function isWalletReloadRequested(): boolean {
  return walletReloadRequested;
}

export function markWalletReloadRequested(): void {
  walletReloadRequested = true;
}

export function resetWalletReloadRequested(): void {
  walletReloadRequested = false;
}

export function createWalletBridgeDispatchKey(state: WalletBridgeState): string {
  return JSON.stringify({
    privyReady: state.privyReady,
    authenticated: state.authenticated,
    isModalOpen: state.isModalOpen,
    account: state.account,
    chainId: state.chainId,
    privyId: state.privyId,
    identityToken: state.identityToken ?? "",
    linkedWalletAddresses: [...state.linkedWalletAddresses].sort(),
  });
}

export function emitWalletBridgeState() {
  window.dispatchEvent(
    new CustomEvent("dashboard:wallet-state", {
      detail: {
        privyReady: walletBridgeState.privyReady,
        authenticated: walletBridgeState.authenticated,
        isModalOpen: walletBridgeState.isModalOpen,
        account: walletBridgeState.account,
        chainId: walletBridgeState.chainId,
      },
    }),
  );
}

async function syncPrivySession(endpoint: string) {
  privyDebugLog("info", "sync-privy-session:start", {
    endpoint,
    authenticated: walletBridgeState.authenticated,
    account: redactWalletForDebug(walletBridgeState.account),
    linkedWalletAddresses:
      walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    readyForBridgeSession: walletReadyForBridgeSession(),
    hasCachedIdentityToken: Boolean(walletBridgeState.identityToken),
  });

  if (!walletBridgeState.account || !walletReadyForBridgeSession()) {
    privyDebugLog("warn", "sync-privy-session:not-ready", {
      authenticated: walletBridgeState.authenticated,
      account: redactWalletForDebug(walletBridgeState.account),
      linkedWalletAddresses:
        walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    });
    throw new Error("Wallet session is not ready.");
  }

  let identityToken = await resolveIdentityToken();

  if (!identityToken) {
    privyDebugLog("warn", "sync-privy-session:missing-cached-identity-token", {
      account: redactWalletForDebug(walletBridgeState.account),
    });
    identityToken = await refreshIdentityToken();
  }

  if (!identityToken) {
    privyDebugLog(
      "error",
      "sync-privy-session:no-identity-token-after-refresh",
      {
        account: redactWalletForDebug(walletBridgeState.account),
      },
    );
    throw new Error("Wallet session is not ready.");
  }

  try {
    const session = await postPrivySession(endpoint, identityToken);
    await completeXmtpIdentity(endpoint, session);

    privyDebugLog("info", "sync-privy-session:success", {
      endpoint,
      account: redactWalletForDebug(walletBridgeState.account),
      xmtpStatus: session.xmtp?.status ?? null,
    });
  } catch (error) {
    privyDebugLog("error", "sync-privy-session:failed", {
      endpoint,
      account: redactWalletForDebug(walletBridgeState.account),
      ...debugHttpError(error),
    });
    throw error;
  }
}

function walletReadyForBridgeSession(): boolean {
  return (
    walletBridgeState.authenticated &&
    walletBridgeState.account !== null &&
    walletBridgeState.linkedWalletAddresses.some(
      (candidate) =>
        candidate.toLowerCase() === walletBridgeState.account?.toLowerCase(),
    )
  );
}

async function postPrivySession(
  endpoint: string,
  identityToken: string,
): Promise<PrivySessionResponse> {
  privyDebugLog("info", "post-privy-session:request", {
    endpoint,
    account: redactWalletForDebug(walletBridgeState.account),
    hasIdentityToken: identityToken.trim().length > 0,
    displayNamePresent: Boolean(walletBridgeState.displayName),
  });

  return fetchJson<PrivySessionResponse>(endpoint, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${identityToken}`,
    },
    body: JSON.stringify({
      display_name: walletBridgeState.displayName,
    }),
  });
}

async function completeXmtpIdentity(
  sessionEndpoint: string,
  session: PrivySessionResponse,
) {
  if (session.xmtp?.status !== "signature_required") return;

  const xmtp = session.xmtp;

  privyDebugLog("info", "complete-xmtp-identity:signature-required", {
    walletAddress: redactWalletForDebug(xmtp.wallet_address),
  });

  const signature = await signXmtpSignatureText(
    xmtp.signature_text,
    xmtp.wallet_address,
  );

  await fetchJson<PrivySessionResponse>(xmtpCompleteEndpoint(sessionEndpoint), {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify({
      wallet_address: xmtp.wallet_address,
      client_id: xmtp.client_id,
      signature_request_id: xmtp.signature_request_id,
      signature,
    }),
  });
}

async function signXmtpSignatureText(
  message: string,
  expectedAddress: string,
): Promise<`0x${string}`> {
  const wallet = ensureWalletReady();

  if (wallet.account.toLowerCase() !== expectedAddress.toLowerCase()) {
    throw new Error("Switch to the wallet connected to this page first.");
  }

  return wallet.walletClient.signMessage({
    account: wallet.account,
    message,
  });
}

function xmtpCompleteEndpoint(sessionEndpoint: string): string {
  const url = new URL(sessionEndpoint, window.location.origin);
  url.pathname = url.pathname.replace(/\/session$/, "/xmtp/complete");
  return url.pathname + url.search;
}

async function refreshIdentityToken(): Promise<string | null> {
  try {
    await walletBridgeState.refreshUser?.();
    walletBridgeState = {
      ...walletBridgeState,
      identityToken: null,
    };
    privyDebugLog("info", "refresh-identity-token:requested", {
      account: redactWalletForDebug(walletBridgeState.account),
    });
  } catch {
    privyDebugLog("error", "refresh-identity-token:failed", {
      account: redactWalletForDebug(walletBridgeState.account),
    });
    return null;
  }

  return resolveIdentityToken();
}

export async function clearPrivySession(endpoint: string) {
  await fetchJson(endpoint, { method: "DELETE" });
}

export function ensureWalletReady() {
  if (
    !walletBridgeState.authenticated ||
    !walletBridgeState.account ||
    !walletBridgeState.walletClient
  ) {
    throw new Error("Sign in with your wallet first.");
  }

  return {
    account: walletBridgeState.account,
    chainId: walletBridgeState.chainId ?? base.id,
    walletClient: walletBridgeState.walletClient,
  };
}

async function resolveIdentityToken(): Promise<string | null> {
  const cachedIdentityToken = walletBridgeState.identityToken?.trim();

  if (cachedIdentityToken) {
    privyDebugLog("info", "resolve-identity-token:cached", {
      account: redactWalletForDebug(walletBridgeState.account),
    });
    return cachedIdentityToken;
  }

  try {
    const freshIdentityToken = await getIdentityToken();

    if (
      typeof freshIdentityToken === "string" &&
      freshIdentityToken.trim() !== ""
    ) {
      walletBridgeState = {
        ...walletBridgeState,
        identityToken: freshIdentityToken,
      };

      privyDebugLog("info", "resolve-identity-token:fresh", {
        account: redactWalletForDebug(walletBridgeState.account),
      });
      return freshIdentityToken;
    }
  } catch {
    privyDebugLog("warn", "resolve-identity-token:fresh-read-failed", {
      account: redactWalletForDebug(walletBridgeState.account),
    });
  }

  privyDebugLog("warn", "resolve-identity-token:none", {
    account: redactWalletForDebug(walletBridgeState.account),
  });
  return null;
}
