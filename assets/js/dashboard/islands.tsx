import {
  getIdentityToken,
  PrivyProvider,
  type PrivyClientConfig,
  useIdentityToken,
  usePrivy,
  useUser,
} from "@privy-io/react-auth";
import { animate } from "animejs";
import React from "react";
import { createRoot, type Root } from "react-dom/client";
import {
  createPublicClient,
  http,
  isAddress,
} from "viem";
import { base, mainnet } from "viem/chains";

import {
  ANIMATA1,
  ANIMATA2,
  USDC,
  USDC_PRICE,
  erc20Abi,
  erc721Abi,
  redeemerAbi,
} from "./redeem-constants";
import {
  formatPrivySessionErrorMessage,
  getLinkedWalletAddressesFromPrivyUser,
  usePrivyWalletClient,
} from "./privy";
import {
  disconnectFailureNotice,
  emptyWalletBridgeState,
  type WalletBridgeState,
  type WalletNoticeTone,
} from "./wallet_bridge_state";
import {
  createWalletRenderState,
  walletReadyForSession,
  type WalletRenderState,
} from "./wallet_render_state";
import { decideWalletSessionSync } from "./wallet_session_sync";

type DashboardConfig = {
  privyAppId: string | null;
  privyClientId: string | null;
  privySession?: string;
  basenamesMint?: string;
  baseRpcUrl?: string | null;
  redeemerAddress?: string | null;
};

type BridgeEventDetail = {
  privyReady: boolean;
  authenticated: boolean;
  account: `0x${string}` | null;
  chainId: number | null;
};

type Cleanup = () => void;

const bridgeRoots = new WeakMap<Element, Root>();
const DASHBOARD_PRIVY_CONFIG: PrivyClientConfig = {
  loginMethods: ["wallet"],
  appearance: {
    walletChainType: "ethereum-only",
    walletList: ["metamask", "coinbase_wallet", "rainbow", "wallet_connect"],
  },
};

let walletBridgeState: WalletBridgeState = emptyWalletBridgeState();

let walletSessionSyncInFlight: Promise<void> | null = null;
let walletReloadRequested = false;
let lastWalletBridgeDispatchKey: string | null = null;
const WALLET_SESSION_SYNC_COOLDOWN_MS = 4_000;

class HttpRequestError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "HttpRequestError";
    this.status = status;
  }
}

function privyDebugEnabled(): boolean {
  if (typeof window === "undefined") return false;

  const params = new URLSearchParams(window.location.search);
  return params.get("debug_privy") === "1" ||
    window.localStorage.getItem("debug:privy") === "1";
}

function redactWalletForDebug(value: string | null | undefined): string | null {
  const address = normalizeWalletAddress(value);
  if (!address) return null;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function privyDebugLog(
  level: "info" | "warn" | "error",
  event: string,
  details: Record<string, unknown> = {},
) {
  if (!privyDebugEnabled()) return;

  const prefix = `[privy-debug] ${event}`;

  if (level === "error") {
    console.error(prefix, details);
    return;
  }

  if (level === "warn") {
    console.warn(prefix, details);
    return;
  }

  console.info(prefix, details);
}

function debugHttpError(error: unknown): Record<string, unknown> {
  if (error instanceof HttpRequestError) {
    return {
      name: error.name,
      message: error.message,
      status: error.status,
    };
  }

  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
    };
  }

  return {
    message: String(error),
  };
}

function parseConfig(raw: string | null | undefined): DashboardConfig | null {
  if (!raw) return null;

  try {
    return JSON.parse(raw) as DashboardConfig;
  } catch {
    return null;
  }
}

function createWalletBridgeDispatchKey(state: WalletBridgeState): string {
  return JSON.stringify({
    privyReady: state.privyReady,
    authenticated: state.authenticated,
    account: state.account,
    chainId: state.chainId,
    privyId: state.privyId,
    identityToken: state.identityToken ?? "",
    linkedWalletAddresses: [...state.linkedWalletAddresses].sort(),
  });
}

function emitWalletBridgeState() {
  window.dispatchEvent(
    new CustomEvent<BridgeEventDetail>("dashboard:wallet-state", {
      detail: {
        privyReady: walletBridgeState.privyReady,
        authenticated: walletBridgeState.authenticated,
        account: walletBridgeState.account,
        chainId: walletBridgeState.chainId,
      },
    }),
  );
}

function DashboardPrivyBridge() {
  const { ready, authenticated, login, linkWallet, logout, user } = usePrivy();
  const { identityToken } = useIdentityToken();
  const { refreshUser } = useUser();
  const { account, chainId, privyId, wallet, walletClient } =
    usePrivyWalletClient();
  const linkedWalletAddresses = React.useMemo(
    () => getLinkedWalletAddressesFromPrivyUser(user),
    [user],
  );

  React.useEffect(() => {
    const nextWalletBridgeState: WalletBridgeState = {
      privyReady: ready,
      authenticated,
      account,
      chainId,
      privyId,
      wallet,
      walletClient,
      displayName: getPrivyDisplayName(user),
      identityToken,
      linkedWalletAddresses,
      login,
      linkWallet,
      logout,
      refreshUser,
    };

    walletBridgeState = nextWalletBridgeState;

    const nextDispatchKey = createWalletBridgeDispatchKey(nextWalletBridgeState);

    if (nextDispatchKey === lastWalletBridgeDispatchKey) {
      return;
    }

    lastWalletBridgeDispatchKey = nextDispatchKey;

    privyDebugLog("info", "bridge-state", {
      ready,
      authenticated,
      account: redactWalletForDebug(account),
      chainId,
      privyId,
      hasIdentityToken: Boolean(identityToken),
      linkedWalletAddresses: linkedWalletAddresses.map(redactWalletForDebug),
      hasWalletClient: Boolean(walletClient),
    });

    emitWalletBridgeState();
  }, [
    account,
    authenticated,
    chainId,
    identityToken,
    linkedWalletAddresses,
    login,
    linkWallet,
    logout,
    privyId,
    refreshUser,
    ready,
    user,
    wallet,
    walletClient,
  ]);

  return null;
}

export function mountDashboardPrivyBridge(el: Element): void {
  const config = parseConfig(el.getAttribute("data-dashboard-config"));

  if (!config?.privyAppId || !config?.privyClientId) {
    walletBridgeState = emptyWalletBridgeState();
    lastWalletBridgeDispatchKey = null;
    emitWalletBridgeState();
    return;
  }

  const existing = bridgeRoots.get(el);
  if (existing) return;

  const root = createRoot(el);
  root.render(
    <PrivyProvider
      appId={config.privyAppId}
      clientId={config.privyClientId}
      config={DASHBOARD_PRIVY_CONFIG}
    >
      <DashboardPrivyBridge />
    </PrivyProvider>,
  );
  bridgeRoots.set(el, root);
}

export function unmountDashboardPrivyBridge(el: Element): void {
  const root = bridgeRoots.get(el);
  if (!root) return;

  root.unmount();
  bridgeRoots.delete(el);
}

type WalletShellBinding = {
  clearNotice: () => void;
  cleanup: Cleanup;
  renderWalletState: (state: WalletRenderState) => void;
  showNotice: (message: string, tone?: WalletNoticeTone) => void;
};

type WalletShellBindingOptions = {
  getDisconnecting: () => boolean;
  onConnectClick: () => void;
  onDisconnectClick: () => Promise<void>;
  serverAddress: `0x${string}` | null;
};

function bindDashboardWalletShell(
  el: HTMLElement,
  options: WalletShellBindingOptions,
): WalletShellBinding {
  const connectButton = el.querySelector<HTMLButtonElement>("[data-wallet-sign-in]");
  const connectedShell = el.querySelector<HTMLElement>("[data-wallet-connected]");
  const triggerButton = el.querySelector<HTMLButtonElement>("[data-wallet-trigger]");
  const caret = el.querySelector<HTMLElement>("[data-wallet-caret]");
  const drawer = el.querySelector<HTMLElement>("[data-wallet-drawer]");
  const drawerInner = el.querySelector<HTMLElement>("[data-wallet-drawer-inner]");
  const addressText = el.querySelector<HTMLElement>("[data-wallet-address-text]");
  const copyButton = el.querySelector<HTMLButtonElement>("[data-wallet-copy]");
  const copyIcon = el.querySelector<HTMLElement>("[data-wallet-copy-icon]");
  const copyCheck = el.querySelector<HTMLElement>("[data-wallet-copy-check]");
  const disconnectButton = el.querySelector<HTMLButtonElement>("[data-wallet-disconnect]");
  const notice = el.querySelector<HTMLElement>("[data-dashboard-wallet-notice]");
  let drawerOpen = false;
  let copyResetTimer: number | undefined;
  let currentRenderState: WalletRenderState = {
    privyReady: false,
    authenticated: false,
    connected: false,
    connectedAddress: options.serverAddress,
  };

  const showNotice = (message: string, tone: WalletNoticeTone = "info") => {
    if (!notice) return;
    setNoticeState(notice, message, tone);
  };

  const clearNotice = () => {
    if (!notice) return;
    notice.classList.add("hidden");
    notice.textContent = "";
  };

  const setHidden = (target: HTMLElement | null, hidden: boolean) => {
    if (!target) return;
    target.hidden = hidden;
    target.classList.toggle("hidden", hidden);
  };

  const resetCopyFeedback = (immediate = false) => {
    if (copyIcon) {
      copyIcon.style.opacity = "1";
      copyIcon.style.transform = "scale(1)";
    }

    if (copyCheck) {
      copyCheck.style.opacity = "0";
      copyCheck.style.transform = "translate(60%, -55%) scale(0.7)";

      if (immediate) {
        copyCheck.style.transition = "none";
      } else {
        copyCheck.style.removeProperty("transition");
      }
    }
  };

  const closeDrawer = (immediate = false) => {
    if (!drawer || !drawerInner || !triggerButton) return;
    if (!drawerOpen && drawer.hidden) return;

    drawerOpen = false;
    triggerButton.setAttribute("aria-expanded", "false");

    if (caret) {
      animate(caret, {
        rotate: 0,
        duration: immediate ? 0 : 220,
        ease: "outExpo",
      });
    }

    if (immediate) {
      drawer.hidden = true;
      drawer.classList.remove("pp-wallet-drawer-open");
      drawerInner.style.opacity = "0";
      drawerInner.style.transform = "translateY(-10px)";
      return;
    }

    animate(drawerInner, {
      opacity: [1, 0],
      translateY: [0, -10],
      duration: 180,
      ease: "outQuad",
      onComplete: () => {
        if (!drawerOpen) {
          drawer.hidden = true;
          drawer.classList.remove("pp-wallet-drawer-open");
        }
      },
    });
  };

  const openDrawer = () => {
    if (!drawer || !drawerInner || !triggerButton) return;

    drawerOpen = true;
    drawer.hidden = false;
    drawer.classList.add("pp-wallet-drawer-open");
    triggerButton.setAttribute("aria-expanded", "true");
    drawerInner.style.opacity = "0";
    drawerInner.style.transform = "translateY(-10px)";

    if (caret) {
      animate(caret, {
        rotate: 180,
        duration: 240,
        ease: "outExpo",
      });
    }

    animate(drawerInner, {
      opacity: [0, 1],
      translateY: [-10, 0],
      duration: 240,
      ease: "outExpo",
    });
  };

  const renderWalletState = (state: WalletRenderState) => {
    currentRenderState = state;

    if (connectButton) {
      connectButton.disabled = state.connected || !state.privyReady || options.getDisconnecting();
    }

    if (triggerButton) {
      triggerButton.disabled = !state.connected || options.getDisconnecting();
    }

    if (disconnectButton) {
      disconnectButton.disabled = options.getDisconnecting();
    }

    setHidden(connectButton, state.connected);
    setHidden(connectedShell, !state.connected);

    if (!state.connected) {
      closeDrawer(true);
    }

    if (addressText) {
      addressText.textContent = abbreviateWalletAddress(state.connectedAddress);
    }

    if (copyButton) {
      copyButton.disabled = !state.connectedAddress;
    }
  };

  const onTriggerClick = () => {
    if (drawerOpen) {
      closeDrawer();
    } else {
      clearNotice();
      openDrawer();
    }
  };

  const onCopyClick = async () => {
    const address = currentRenderState.connectedAddress;

    if (!address) {
      showNotice("No wallet address is available yet.", "error");
      return;
    }

    try {
      await navigator.clipboard.writeText(address);

      if (copyResetTimer) {
        window.clearTimeout(copyResetTimer);
      }

      resetCopyFeedback(true);

      if (copyIcon) {
        animate(copyIcon, {
          opacity: [1, 0],
          scale: [1, 0.7],
          duration: 160,
          ease: "outQuad",
        });
      }

      if (copyCheck) {
        animate(copyCheck, {
          opacity: [0, 1],
          scale: [0.7, 1],
          duration: 180,
          ease: "outBack",
        });

        copyResetTimer = window.setTimeout(() => {
          if (copyIcon) {
            animate(copyIcon, {
              opacity: [0, 1],
              scale: [0.78, 1],
              duration: 220,
              ease: "outQuad",
            });
          }

          animate(copyCheck, {
            opacity: [1, 0],
            scale: [1, 0.8],
            duration: 240,
            ease: "outQuad",
          });
        }, 900);
      }
    } catch (error) {
      showNotice(getErrorMessage(error, "Could not copy this wallet address."), "error");
    }
  };

  const onWindowClick = (event: MouseEvent) => {
    if (!drawerOpen) return;
    if (el.contains(event.target as Node)) return;
    closeDrawer();
  };

  const onWindowKeydown = (event: KeyboardEvent) => {
    if (event.key === "Escape") {
      closeDrawer();
    }
  };

  const onDisconnectButtonClick = () => {
    void options.onDisconnectClick();
  };

  window.addEventListener("click", onWindowClick);
  window.addEventListener("keydown", onWindowKeydown);
  connectButton?.addEventListener("click", options.onConnectClick);
  triggerButton?.addEventListener("click", onTriggerClick);
  copyButton?.addEventListener("click", onCopyClick);
  disconnectButton?.addEventListener("click", onDisconnectButtonClick);

  return {
    clearNotice,
    cleanup: () => {
      if (copyResetTimer) {
        window.clearTimeout(copyResetTimer);
      }

      resetCopyFeedback(true);
      window.removeEventListener("click", onWindowClick);
      window.removeEventListener("keydown", onWindowKeydown);
      connectButton?.removeEventListener("click", options.onConnectClick);
      triggerButton?.removeEventListener("click", onTriggerClick);
      copyButton?.removeEventListener("click", onCopyClick);
      disconnectButton?.removeEventListener("click", onDisconnectButtonClick);
    },
    renderWalletState,
    showNotice,
  };
}

export function bindDashboardWallet(el: HTMLElement): Cleanup {
  const config = parseConfig(el.dataset.dashboardConfig);
  const serverSignedIn = el.dataset.walletSignedIn === "true";
  const serverAddress = normalizeWalletAddress(el.dataset.walletAddress);
  const layoutRoot = el.closest("#platform-layout-root") ?? document.body;
  let serverSessionActive = serverSignedIn;
  let pendingConnect = false;
  let disconnecting = false;
  let lastSessionSyncAttemptKey: string | null = null;
  let sessionSyncCooldownUntilMs = 0;

  const shellBindings = Array.from(
    layoutRoot.querySelectorAll<HTMLElement>("[data-wallet-shell]"),
  ).map((shell) =>
    bindDashboardWalletShell(shell, {
      getDisconnecting: () => disconnecting,
      onConnectClick,
      onDisconnectClick,
      serverAddress,
    }),
  );

  const showNotice = (message: string, tone: WalletNoticeTone = "info") => {
    shellBindings.forEach((binding) => binding.showNotice(message, tone));
  };

  const clearNotices = () => {
    shellBindings.forEach((binding) => binding.clearNotice());
  };

  const syncCooldownActive = (nowMs = Date.now()) => sessionSyncCooldownUntilMs > nowMs;

  const startSessionSyncCooldown = (error: unknown) => {
    sessionSyncCooldownUntilMs = Date.now() + WALLET_SESSION_SYNC_COOLDOWN_MS;
    privyDebugLog("warn", "sync-cooldown:start", {
      cooldownMs: WALLET_SESSION_SYNC_COOLDOWN_MS,
      ...debugHttpError(error),
    });
  };

  const showCooldownNotice = () => {
    showNotice(
      "Please wait a few seconds, then try again.\nIf it keeps happening, disconnect your wallet and connect it again.",
      "info",
    );
  };

  const renderWalletState = (detail?: Partial<BridgeEventDetail>) => {
    const renderState = createWalletRenderState({
      privyReady: detail?.privyReady ?? walletBridgeState.privyReady,
      authenticated: detail?.authenticated ?? walletBridgeState.authenticated,
      detailAccount: normalizeWalletAddress(detail?.account),
      bridgeAccount: normalizeWalletAddress(walletBridgeState.account),
      linkedWalletAddresses: walletBridgeState.linkedWalletAddresses,
      serverSignedIn: serverSessionActive,
      serverAddress,
    });

    privyDebugLog("info", "render-wallet-state", {
      serverSignedIn: serverSessionActive,
      privyReady: renderState.privyReady,
      authenticated: renderState.authenticated,
      connected: renderState.connected,
      connectedAddress: redactWalletForDebug(renderState.connectedAddress),
      linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    });

    shellBindings.forEach((binding) => binding.renderWalletState(renderState));
  };

  const syncAndReload = async (label: string) => {
    if (!config?.privySession) return;

    privyDebugLog("info", "sync-and-reload:start", {
      label,
      sessionEndpoint: config.privySession,
      inFlight: Boolean(walletSessionSyncInFlight),
      account: redactWalletForDebug(walletBridgeState.account),
      hasIdentityToken: Boolean(walletBridgeState.identityToken),
      linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    });

    if (!walletSessionSyncInFlight) {
      walletSessionSyncInFlight = syncPrivySession(config.privySession).finally(() => {
        walletSessionSyncInFlight = null;
      });
    }

    showNotice(label, "info");
    await walletSessionSyncInFlight;

    if (!walletReloadRequested) {
      walletReloadRequested = true;
      privyDebugLog("info", "sync-and-reload:reload", {
        label,
        account: redactWalletForDebug(walletBridgeState.account),
      });
      window.location.reload();
    }
  };

  const attemptSessionSync = async (label: string) => {
    const decision = decideWalletSessionSync({
      serverSignedIn: serverSessionActive,
      pendingConnect,
      lastAttemptKey: lastSessionSyncAttemptKey,
      cooldownUntilMs: sessionSyncCooldownUntilMs,
      state: walletBridgeState,
    });

    if (!decision.shouldSync || !decision.attemptKey) {
      return;
    }

    lastSessionSyncAttemptKey = decision.attemptKey;
    pendingConnect = false;
    await syncAndReload(label);
  };

  async function onState(event: Event) {
    const detail = (event as CustomEvent<BridgeEventDetail>).detail;

    privyDebugLog("info", "wallet-state-event", {
      detail: {
        privyReady: detail.privyReady,
        authenticated: detail.authenticated,
        account: redactWalletForDebug(detail.account),
        chainId: detail.chainId,
      },
      serverSignedIn: serverSessionActive,
      pendingConnect,
      linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    });

    renderWalletState(detail);

    if (
      detail.authenticated &&
      walletBridgeState.account &&
          walletReadyForSession(
            walletBridgeState.linkedWalletAddresses,
            normalizeWalletAddress(detail.account) ?? normalizeWalletAddress(walletBridgeState.account),
          )
    ) {
      try {
        await attemptSessionSync(
          serverSessionActive ? "Restoring your sign in..." : "Finishing sign in...",
        );
      } catch (error) {
        walletReloadRequested = false;
        startSessionSyncCooldown(error);
        privyDebugLog("error", "wallet-state-event:sync-failed", debugHttpError(error));
        showNotice(formatPrivySessionErrorMessage(error), "error");
      }
    }
  }

  function onConnectClick() {
    if (syncCooldownActive()) {
      showCooldownNotice();
      return;
    }

    clearNotices();
    lastSessionSyncAttemptKey = null;

    if (
      walletBridgeState.authenticated &&
      !walletReadyForSession(
        walletBridgeState.linkedWalletAddresses,
        normalizeWalletAddress(walletBridgeState.account),
      )
    ) {
      if (!walletBridgeState.linkWallet) {
        privyDebugLog("warn", "connect-click:link-wallet-missing", {
          account: redactWalletForDebug(walletBridgeState.account),
          linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
        });
        showNotice("Wallet sign-in is not ready yet.", "error");
        return;
      }

      pendingConnect = true;
      privyDebugLog("info", "connect-click:link-wallet", {
        account: redactWalletForDebug(walletBridgeState.account),
        linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
      });
      showNotice("Confirm your wallet to finish sign in...", "info");
      walletBridgeState.linkWallet();
      return;
    }

    if (!walletBridgeState.login) {
      privyDebugLog("warn", "connect-click:login-missing", {
        account: redactWalletForDebug(walletBridgeState.account),
      });
      showNotice("Wallet sign-in is not ready yet.", "error");
      return;
    }

    pendingConnect = true;
    privyDebugLog("info", "connect-click:login", {
      account: redactWalletForDebug(walletBridgeState.account),
      linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    });
    showNotice("Waiting for wallet confirmation...", "info");
    walletBridgeState.login();
  }

  async function onDisconnectClick() {
    let clearedServerSession = false;

    try {
      disconnecting = true;
      pendingConnect = false;
      lastSessionSyncAttemptKey = null;
      sessionSyncCooldownUntilMs = 0;
      renderWalletState();
      showNotice("Signing out...", "info");

      if (config?.privySession) {
        await clearPrivySession(config.privySession);
        serverSessionActive = false;
        clearedServerSession = true;
      }

      await Promise.resolve(walletBridgeState.logout?.());
      window.location.reload();
    } catch (error) {
      disconnecting = false;
      walletReloadRequested = false;
      renderWalletState();

      const notice = disconnectFailureNotice({
        clearedServerSession,
        fallbackMessage: getErrorMessage(error, "Could not disconnect this wallet."),
      });

      if (clearedServerSession) {
        sessionSyncCooldownUntilMs = Date.now() + WALLET_SESSION_SYNC_COOLDOWN_MS;
      }

      showNotice(notice.message, notice.tone);
    }
  }

  window.addEventListener("dashboard:wallet-state", onState);
  renderWalletState();

  if (
    walletBridgeState.authenticated &&
    walletBridgeState.account &&
    walletReadyForSession(
      walletBridgeState.linkedWalletAddresses,
      normalizeWalletAddress(walletBridgeState.account),
    ) &&
    !serverSessionActive
  ) {
    privyDebugLog("info", "initial-sync-trigger", {
      account: redactWalletForDebug(walletBridgeState.account),
      linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
      hasIdentityToken: Boolean(walletBridgeState.identityToken),
    });
    void attemptSessionSync("Restoring your sign in...").catch((error) => {
      walletReloadRequested = false;
      startSessionSyncCooldown(error);
      privyDebugLog("error", "initial-sync-trigger:failed", debugHttpError(error));
      showNotice(formatPrivySessionErrorMessage(error), "error");
    });
  }

  return () => {
    window.removeEventListener("dashboard:wallet-state", onState);
    shellBindings.forEach((binding) => binding.cleanup());
  };
}

export function bindDashboardNameClaim(el: HTMLElement): Cleanup {
  const config = parseConfig(el.dataset.dashboardConfig);
  const freeButton = el.querySelector<HTMLButtonElement>("[data-dashboard-claim-free]");
  const paidButton = el.querySelector<HTMLButtonElement>("[data-dashboard-claim-paid]");
  const notice = el.querySelector<HTMLElement>("[data-dashboard-claim-notice]");
  let busy = false;

  const showNotice = (message: string, tone: "error" | "info" | "success" = "info") => {
    if (!notice) return;
    setNoticeState(notice, message, tone);
  };

  const setBusy = (button: HTMLButtonElement | null, nextBusy: boolean, busyLabel: string, idleLabel: string) => {
    busy = nextBusy;
    if (!button) return;
    button.disabled = nextBusy;
    button.textContent = nextBusy ? busyLabel : idleLabel;
  };

  const claimSuccessRedirect = (label: string) => {
    const params = new URLSearchParams({
      claimedLabel: label,
      stage: "setup",
    });
    window.location.assign(`/agent-formation?${params.toString()}`);
  };

  const performFreeClaim = async () => {
    if (!config?.basenamesMint) {
      showNotice("Name claims are not configured yet.", "error");
      return;
    }

    const wallet = ensureWalletReady();
    const normalizedLabel = readRequiredValue(el, "#phase1-normalized-label", "Enter a valid name.");
    const fqdn = readRequiredValue(el, "#phase1-fqdn", "Enter a valid name.");

    setBusy(freeButton, true, "Claiming...", "Claim from snapshot");

    try {
      const timestamp = Date.now();
      const signature = await wallet.walletClient.signMessage({
        account: wallet.account,
        message: createMintMessage(wallet.account, fqdn, base.id, timestamp),
      });

      await fetchJson(config.basenamesMint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          address: wallet.account,
          label: normalizedLabel,
          signature,
          timestamp,
        }),
      });

      showNotice(`Claimed ${fqdn}. Opening Agent Formation...`, "success");
      window.setTimeout(() => claimSuccessRedirect(normalizedLabel), 240);
    } catch (error) {
      showNotice(getErrorMessage(error, "Free claim failed."), "error");
    } finally {
      setBusy(freeButton, false, "Claiming...", "Claim from snapshot");
    }
  };

  const performPaidClaim = async () => {
    if (!config?.basenamesMint) {
      showNotice("Name claims are not configured yet.", "error");
      return;
    }

    const wallet = ensureWalletReady();
    const normalizedLabel = readRequiredValue(el, "#phase2-normalized-label", "Enter a valid name.");
    const fqdn = readRequiredValue(el, "#phase2-fqdn", "Enter a valid name.");
    const paymentRecipient = requiredAddress(paidButton?.dataset.paymentRecipient, "Paid claims are unavailable right now.");
    const priceWei = requiredBigInt(paidButton?.dataset.priceWei, "Paid claims are unavailable right now.");
    const paymentChain = wallet.chainId === mainnet.id ? mainnet : base;

    if (wallet.chainId !== base.id && wallet.chainId !== mainnet.id) {
      showNotice("Switch to Base or Ethereum before paying for this name.", "error");
      return;
    }

    setBusy(paidButton, true, "Paying...", "Pay and claim");

    try {
      const timestamp = Date.now();
      const signature = await wallet.walletClient.signMessage({
        account: wallet.account,
        message: createMintMessage(wallet.account, fqdn, base.id, timestamp),
      });

      const txHash = await wallet.walletClient.sendTransaction({
        account: wallet.account,
        chain: paymentChain,
        to: paymentRecipient,
        value: priceWei,
      });

      const paymentClient = createPublicClient({
        chain: paymentChain,
        transport:
          paymentChain.id === base.id
            ? http(config.baseRpcUrl ?? undefined)
            : http(),
      });

      const receipt = await paymentClient.waitForTransactionReceipt({ hash: txHash, timeout: 120_000 });
      if (receipt.status !== "success") {
        throw new Error("Payment did not complete.");
      }

      await fetchJson(config.basenamesMint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          address: wallet.account,
          label: normalizedLabel,
          signature,
          timestamp,
          paymentTxHash: txHash,
          paymentChainId: paymentChain.id,
        }),
      });

      showNotice(`Claimed ${fqdn}. Opening Agent Formation...`, "success");
      window.setTimeout(() => claimSuccessRedirect(normalizedLabel), 240);
    } catch (error) {
      showNotice(getErrorMessage(error, "Paid claim failed."), "error");
    } finally {
      setBusy(paidButton, false, "Paying...", "Pay and claim");
    }
  };

  const onFreeClick = () => {
    if (busy) return;
    void performFreeClaim();
  };

  const onPaidClick = () => {
    if (busy) return;
    void performPaidClaim();
  };

  freeButton?.addEventListener("click", onFreeClick);
  paidButton?.addEventListener("click", onPaidClick);

  return () => {
    freeButton?.removeEventListener("click", onFreeClick);
    paidButton?.removeEventListener("click", onPaidClick);
  };
}

export function bindDashboardRedeem(el: HTMLElement): Cleanup {
  const config = parseConfig(el.dataset.dashboardConfig);
  const sourceSelect = el.querySelector<HTMLSelectElement>("[data-dashboard-redeem-source]");
  const tokenIdInput = el.querySelector<HTMLInputElement>("[data-dashboard-redeem-token-id]");
  const approveNftButton = el.querySelector<HTMLButtonElement>("[data-dashboard-redeem-approve-nft]");
  const approveUsdcButton = el.querySelector<HTMLButtonElement>("[data-dashboard-redeem-approve-usdc]");
  const redeemButton = el.querySelector<HTMLButtonElement>("[data-dashboard-redeem-start]");
  const claimButton = el.querySelector<HTMLButtonElement>("[data-dashboard-redeem-claim]");
  const claimableEl = el.querySelector<HTMLElement>("[data-dashboard-redeem-claimable]");
  const remainingEl = el.querySelector<HTMLElement>("[data-dashboard-redeem-remaining]");
  const notice = el.querySelector<HTMLElement>("[data-dashboard-redeem-notice]");
  let busy = false;

  const showNotice = (message: string, tone: "error" | "info" | "success" = "info") => {
    if (!notice) return;
    setNoticeState(notice, message, tone);
  };

  const setButtonBusy = (button: HTMLButtonElement | null, nextBusy: boolean, busyLabel: string, idleLabel: string) => {
    busy = nextBusy;
    if (!button) return;
    button.disabled = nextBusy;
    button.textContent = nextBusy ? busyLabel : idleLabel;
  };

  const refreshClaimable = async () => {
    if (!config?.redeemerAddress || !claimableEl || !remainingEl) return;
    if (!walletBridgeState.account) {
      claimableEl.textContent = "--";
      remainingEl.textContent = "--";
      return;
    }

    try {
      const address = requiredAddress(config.redeemerAddress, "Redeemer address is missing.");
      const client = createPublicClient({
        chain: base,
        transport: http(config.baseRpcUrl ?? undefined),
      });

      const claimable = (await client.readContract({
        address,
        abi: redeemerAbi,
        functionName: "claimable",
        args: [walletBridgeState.account],
      })) as bigint;

      const [pool, released, claimed] = (await client.readContract({
        address,
        abi: redeemerAbi,
        functionName: "getVest",
        args: [walletBridgeState.account],
      })) as readonly [bigint, bigint, bigint, bigint];

      claimableEl.textContent = formatRegentRounded2(claimable);
      remainingEl.textContent = formatRegentRounded2(pool + released - claimed);
    } catch {
      claimableEl.textContent = "--";
      remainingEl.textContent = "--";
    }
  };

  const ensureBaseWallet = () => {
    const wallet = ensureWalletReady();
    if (wallet.chainId !== base.id) {
      throw new Error("Switch your wallet to Base before redeeming.");
    }
    return wallet;
  };

  const approveNft = async () => {
    const wallet = ensureBaseWallet();
    const redeemerAddress = requiredAddress(config?.redeemerAddress, "Redeemer address is missing.");
    const source = sourceSelect?.value === "ANIMATA2" ? ANIMATA2 : ANIMATA1;
    const client = createPublicClient({
      chain: base,
      transport: http(config?.baseRpcUrl ?? undefined),
    });

    setButtonBusy(approveNftButton, true, "Approving NFT...", "Approve NFT");

    try {
      const hash = await wallet.walletClient.writeContract({
        address: source,
        abi: erc721Abi,
        functionName: "setApprovalForAll",
        args: [redeemerAddress, true],
        account: wallet.account,
        chain: base,
      });

      await client.waitForTransactionReceipt({ hash });
      showNotice("NFT approval confirmed.", "success");
    } catch (error) {
      showNotice(getErrorMessage(error, "NFT approval failed."), "error");
    } finally {
      setButtonBusy(approveNftButton, false, "Approving NFT...", "Approve NFT");
    }
  };

  const approveUsdc = async () => {
    const wallet = ensureBaseWallet();
    const redeemerAddress = requiredAddress(config?.redeemerAddress, "Redeemer address is missing.");
    const client = createPublicClient({
      chain: base,
      transport: http(config?.baseRpcUrl ?? undefined),
    });

    setButtonBusy(approveUsdcButton, true, "Approving...", "Approve 80 USDC");

    try {
      const hash = await wallet.walletClient.writeContract({
        address: USDC,
        abi: erc20Abi,
        functionName: "approve",
        args: [redeemerAddress, USDC_PRICE],
        account: wallet.account,
        chain: base,
      });

      await client.waitForTransactionReceipt({ hash });
      showNotice("USDC approval confirmed.", "success");
    } catch (error) {
      showNotice(getErrorMessage(error, "USDC approval failed."), "error");
    } finally {
      setButtonBusy(approveUsdcButton, false, "Approving...", "Approve 80 USDC");
    }
  };

  const redeem = async () => {
    const wallet = ensureBaseWallet();
    const redeemerAddress = requiredAddress(config?.redeemerAddress, "Redeemer address is missing.");
    const source = sourceSelect?.value === "ANIMATA2" ? ANIMATA2 : ANIMATA1;
    const tokenId = requiredBigInt(tokenIdInput?.value, "Enter a token ID from 1 to 999.");
    const client = createPublicClient({
      chain: base,
      transport: http(config?.baseRpcUrl ?? undefined),
    });

    if (tokenId < 1n || tokenId > 999n) {
      throw new Error("Enter a token ID from 1 to 999.");
    }

    setButtonBusy(redeemButton, true, "Redeeming...", "Redeem");

    try {
      const hash = await wallet.walletClient.writeContract({
        address: redeemerAddress,
        abi: redeemerAbi,
        functionName: "redeem",
        args: [source, tokenId],
        account: wallet.account,
        chain: base,
      });

      await client.waitForTransactionReceipt({ hash });
      showNotice("Redeem confirmed. Reloading the page...", "success");
      await refreshClaimable();
      window.setTimeout(() => window.location.reload(), 500);
    } catch (error) {
      showNotice(getErrorMessage(error, "Redeem failed."), "error");
    } finally {
      setButtonBusy(redeemButton, false, "Redeeming...", "Redeem");
    }
  };

  const claimUnlocked = async () => {
    const wallet = ensureBaseWallet();
    const redeemerAddress = requiredAddress(config?.redeemerAddress, "Redeemer address is missing.");
    const client = createPublicClient({
      chain: base,
      transport: http(config?.baseRpcUrl ?? undefined),
    });

    setButtonBusy(claimButton, true, "Claiming...", "Claim unlocked REGENT");

    try {
      const hash = await wallet.walletClient.writeContract({
        address: redeemerAddress,
        abi: redeemerAbi,
        functionName: "claim",
        args: [],
        account: wallet.account,
        chain: base,
      });

      await client.waitForTransactionReceipt({ hash });
      showNotice("Claim confirmed. Reloading the page...", "success");
      await refreshClaimable();
      window.setTimeout(() => window.location.reload(), 500);
    } catch (error) {
      showNotice(getErrorMessage(error, "Claim failed."), "error");
    } finally {
      setButtonBusy(claimButton, false, "Claiming...", "Claim unlocked REGENT");
    }
  };

  const onApproveNft = () => {
    if (busy) return;
    void approveNft();
  };

  const onApproveUsdc = () => {
    if (busy) return;
    void approveUsdc();
  };

  const onRedeem = () => {
    if (busy) return;
    void redeem().catch((error) => showNotice(getErrorMessage(error, "Redeem failed."), "error"));
  };

  const onClaim = () => {
    if (busy) return;
    void claimUnlocked();
  };

  const onWalletState = () => {
    void refreshClaimable();
  };

  approveNftButton?.addEventListener("click", onApproveNft);
  approveUsdcButton?.addEventListener("click", onApproveUsdc);
  redeemButton?.addEventListener("click", onRedeem);
  claimButton?.addEventListener("click", onClaim);
  window.addEventListener("dashboard:wallet-state", onWalletState);
  void refreshClaimable();

  return () => {
    approveNftButton?.removeEventListener("click", onApproveNft);
    approveUsdcButton?.removeEventListener("click", onApproveUsdc);
    redeemButton?.removeEventListener("click", onRedeem);
    claimButton?.removeEventListener("click", onClaim);
    window.removeEventListener("dashboard:wallet-state", onWalletState);
  };
}

async function syncPrivySession(endpoint: string) {
  privyDebugLog("info", "sync-privy-session:start", {
    endpoint,
    authenticated: walletBridgeState.authenticated,
    account: redactWalletForDebug(walletBridgeState.account),
    linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    readyForBridgeSession: walletReadyForBridgeSession(),
    hasCachedIdentityToken: Boolean(walletBridgeState.identityToken),
  });

  if (!walletBridgeState.account || !walletReadyForBridgeSession()) {
    privyDebugLog("warn", "sync-privy-session:not-ready", {
      authenticated: walletBridgeState.authenticated,
      account: redactWalletForDebug(walletBridgeState.account),
      linkedWalletAddresses: walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
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
    privyDebugLog("error", "sync-privy-session:no-identity-token-after-refresh", {
      account: redactWalletForDebug(walletBridgeState.account),
    });
    throw new Error("Wallet session is not ready.");
  }

  try {
    await postPrivySession(endpoint, identityToken);
    privyDebugLog("info", "sync-privy-session:success", {
      endpoint,
      account: redactWalletForDebug(walletBridgeState.account),
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
  return walletBridgeState.authenticated && walletBridgeState.account !== null &&
    walletBridgeState.linkedWalletAddresses.some(
      (candidate) =>
        candidate.toLowerCase() === walletBridgeState.account?.toLowerCase(),
    );
}

async function postPrivySession(endpoint: string, identityToken: string) {
  privyDebugLog("info", "post-privy-session:request", {
    endpoint,
    account: redactWalletForDebug(walletBridgeState.account),
    hasIdentityToken: identityToken.trim().length > 0,
    displayNamePresent: Boolean(walletBridgeState.displayName),
  });

  await fetchJson(endpoint, {
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

async function clearPrivySession(endpoint: string) {
  await fetchJson(endpoint, { method: "DELETE" });
}

function ensureWalletReady() {
  if (!walletBridgeState.authenticated || !walletBridgeState.account || !walletBridgeState.walletClient) {
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

    if (typeof freshIdentityToken === "string" && freshIdentityToken.trim() !== "") {
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

function normalizeWalletAddress(value: string | null | undefined): `0x${string}` | null {
  if (!value) return null;

  const trimmed = value.trim();
  if (!trimmed || !isAddress(trimmed)) return null;
  return trimmed as `0x${string}`;
}

function abbreviateWalletAddress(value: string | null | undefined): string {
  const address = normalizeWalletAddress(value);
  if (!address) return "No wallet connected";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

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

function setNoticeState(
  el: HTMLElement,
  message: string,
  tone: "error" | "info" | "success",
) {
  el.classList.remove("hidden");
  el.textContent = message;

  const toneClass =
    tone === "error"
      ? "text-[color:#a6574f]"
      : tone === "success"
        ? "text-[color:var(--foreground)]"
        : "text-[color:var(--muted-foreground)]";

  const baseClass =
    el.dataset.noticeStyle === "compact"
      ? "text-sm leading-5"
      : "mt-4 text-sm leading-6";

  el.className = `${baseClass} ${toneClass}`;

  animate(el, {
    opacity: [0, 1],
    translateY: [8, 0],
    duration: 240,
    ease: "outExpo",
  });
}

function readRequiredValue(root: HTMLElement, selector: string, message: string) {
  const el = root.querySelector<HTMLInputElement>(selector);
  const value = el?.value?.trim();
  if (!value) throw new Error(message);
  return value;
}

function requiredAddress(value: string | null | undefined, message: string): `0x${string}` {
  const trimmed = value?.trim();
  if (!trimmed || !isAddress(trimmed)) throw new Error(message);
  return trimmed as `0x${string}`;
}

function requiredBigInt(value: string | null | undefined, message: string) {
  const trimmed = value?.trim();
  if (!trimmed) throw new Error(message);

  try {
    return BigInt(trimmed);
  } catch {
    throw new Error(message);
  }
}

async function fetchJson<T>(input: string, init?: RequestInit): Promise<T> {
  const csrfToken = getCsrfToken();
  const method = (init?.method ?? "GET").toUpperCase();
  const shouldSendCsrfToken =
    csrfToken &&
    ["POST", "PUT", "PATCH", "DELETE"].includes(method) &&
    !hasHeader(init?.headers, "x-csrf-token");

  const response = await fetch(input, {
    ...init,
    headers: {
      accept: "application/json",
      ...(shouldSendCsrfToken ? { "x-csrf-token": csrfToken } : {}),
      ...(init?.headers ?? {}),
    },
  });

  const text = await response.text();
  const payload = tryParseJson(text);

  if (!response.ok) {
    const parsedPayload = payload as
      | { statusMessage?: unknown; message?: unknown }
      | null;

    const message =
      (parsedPayload &&
        ((typeof parsedPayload.statusMessage === "string" &&
          parsedPayload.statusMessage) ||
          (typeof parsedPayload.message === "string" &&
            parsedPayload.message))) ||
      text ||
      `Request failed (${response.status})`;

    privyDebugLog("warn", "fetch-json:request-failed", {
      input,
      method,
      status: response.status,
      message,
    });
    throw new HttpRequestError(message, response.status);
  }

  return (payload ?? {}) as T;
}

function getCsrfToken(): string | null {
  const token = document
    .querySelector("meta[name='csrf-token']")
    ?.getAttribute("content")
    ?.trim();

  return token ? token : null;
}

function hasHeader(headers: HeadersInit | undefined, name: string): boolean {
  if (!headers) return false;

  const normalizedName = name.toLowerCase();

  if (headers instanceof Headers) {
    return headers.has(normalizedName);
  }

  if (Array.isArray(headers)) {
    return headers.some(([headerName]) => headerName.toLowerCase() === normalizedName);
  }

  return Object.keys(headers).some((headerName) => headerName.toLowerCase() === normalizedName);
}

function tryParseJson(value: string): unknown {
  if (!value) return null;

  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function getErrorMessage(error: unknown, fallback: string) {
  if (error instanceof Error && error.message) return error.message;
  if (error && typeof error === "object" && "message" in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === "string" && message) return message;
  }
  return fallback;
}

function getPrivyDisplayName(privyUser: unknown): string | null {
  if (!privyUser || typeof privyUser !== "object") return null;

  if (
    "email" in privyUser &&
    privyUser.email &&
    typeof privyUser.email === "object" &&
    "address" in privyUser.email &&
    typeof privyUser.email.address === "string" &&
    privyUser.email.address.trim()
  ) {
    return privyUser.email.address.trim();
  }

  if (
    "twitter" in privyUser &&
    privyUser.twitter &&
    typeof privyUser.twitter === "object" &&
    "username" in privyUser.twitter &&
    typeof privyUser.twitter.username === "string" &&
    privyUser.twitter.username.trim()
  ) {
    return privyUser.twitter.username.trim();
  }

  return null;
}

function createMintMessage(
  address: string,
  fqdn: string,
  chainId: number,
  timestamp: number,
) {
  return [
    "Regent Basenames Mint",
    `Address: ${address.toLowerCase()}`,
    `Name: ${fqdn.toLowerCase()}`,
    `ChainId: ${chainId}`,
    `Timestamp: ${timestamp}`,
  ].join("\n");
}

function formatRegentRounded2(amount: bigint) {
  const denom = 10n ** 18n;
  const scaled = amount * 100n;
  const cents = (scaled + denom / 2n) / denom;
  const whole = cents / 100n;
  const fraction = cents % 100n;
  return `${whole.toLocaleString()}.${fraction.toString().padStart(2, "0")}`;
}
