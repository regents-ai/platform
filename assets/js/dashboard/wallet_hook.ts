import { formatPrivySessionErrorMessage } from "./privy";
import {
  debugHttpError,
  normalizeWalletAddress,
  parseConfig,
  privyDebugLog,
  redactWalletForDebug,
  getErrorMessage,
} from "./shared";
import type { BridgeEventDetail, Cleanup } from "./types";
import { bindDashboardWalletShell } from "./wallet_shell";
import { decideWalletSessionSync } from "./wallet_session_sync";
import {
  disconnectFailureNotice,
  type WalletNoticeTone,
} from "./wallet_bridge_state";
import {
  createWalletRenderState,
  walletReadyForSession,
} from "./wallet_render_state";
import {
  clearPrivySession,
  getWalletBridgeState,
  isWalletReloadRequested,
  isWalletSessionSyncInFlight,
  markWalletReloadRequested,
  resetWalletReloadRequested,
  syncPrivySessionOnce,
  WALLET_SESSION_SYNC_COOLDOWN_MS,
} from "./wallet_runtime";

export function bindDashboardWallet(el: HTMLElement): Cleanup {
  const config = parseConfig(el.dataset.dashboardConfig);
  const serverSignedIn = el.dataset.walletSignedIn === "true";
  const serverAddress = normalizeWalletAddress(el.dataset.walletAddress);
  const layoutRoot = el.closest("#platform-layout-root") ?? document.body;
  let serverSessionActive = serverSignedIn;
  let pendingConnect = false;
  let disconnecting = false;
  let privyModalOpen = getWalletBridgeState().isModalOpen;
  let lastSessionSyncAttemptKey: string | null = null;
  let sessionSyncCooldownUntilMs = 0;

  const shellBindings = Array.from(
    layoutRoot.querySelectorAll<HTMLElement>("[data-wallet-shell]"),
  ).map((shell) =>
    bindDashboardWalletShell(shell, {
      getDisconnecting: () => disconnecting,
      getPendingConnect: () => pendingConnect,
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

  const syncCooldownActive = (nowMs = Date.now()) =>
    sessionSyncCooldownUntilMs > nowMs;

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
    const walletBridgeState = getWalletBridgeState();
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
      linkedWalletAddresses:
        walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    });

    shellBindings.forEach((binding) => binding.renderWalletState(renderState));
  };

  const syncAndReload = async (label: string) => {
    if (!config?.privySession) return;

    const walletBridgeState = getWalletBridgeState();
    privyDebugLog("info", "sync-and-reload:start", {
      label,
      sessionEndpoint: config.privySession,
      inFlight: isWalletSessionSyncInFlight(),
      account: redactWalletForDebug(walletBridgeState.account),
      hasIdentityToken: Boolean(walletBridgeState.identityToken),
      linkedWalletAddresses:
        walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    });

    const walletSessionSync = syncPrivySessionOnce(config.privySession);

    showNotice(label, "info");
    await walletSessionSync;

    if (!isWalletReloadRequested()) {
      markWalletReloadRequested();
      privyDebugLog("info", "sync-and-reload:reload", {
        label,
        account: redactWalletForDebug(getWalletBridgeState().account),
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
      state: getWalletBridgeState(),
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
    const modalJustClosed = privyModalOpen && !detail.isModalOpen;
    const walletBridgeState = getWalletBridgeState();
    privyModalOpen = detail.isModalOpen;

    privyDebugLog("info", "wallet-state-event", {
      detail: {
        privyReady: detail.privyReady,
        authenticated: detail.authenticated,
        isModalOpen: detail.isModalOpen,
        account: redactWalletForDebug(detail.account),
        chainId: detail.chainId,
      },
      serverSignedIn: serverSessionActive,
      pendingConnect,
      linkedWalletAddresses:
        walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
    });

    renderWalletState(detail);

    if (modalJustClosed && pendingConnect && !detail.authenticated) {
      pendingConnect = false;
      clearNotices();
      return;
    }

    if (
      detail.authenticated &&
      walletBridgeState.account &&
      walletReadyForSession(
        walletBridgeState.linkedWalletAddresses,
        normalizeWalletAddress(detail.account) ??
          normalizeWalletAddress(walletBridgeState.account),
      )
    ) {
      try {
        await attemptSessionSync(
          serverSessionActive
            ? "Restoring your sign in..."
            : "Finishing sign in...",
        );
      } catch (error) {
        resetWalletReloadRequested();
        startSessionSyncCooldown(error);
        privyDebugLog(
          "error",
          "wallet-state-event:sync-failed",
          debugHttpError(error),
        );
        showNotice(formatPrivySessionErrorMessage(error), "error");
      }
    }
  }

  function onConnectClick() {
    if (syncCooldownActive()) {
      showCooldownNotice();
      return;
    }

    const walletBridgeState = getWalletBridgeState();
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
          linkedWalletAddresses:
            walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
        });
        showNotice("Wallet sign-in is not ready yet.", "error");
        return;
      }

      pendingConnect = true;
      privyDebugLog("info", "connect-click:link-wallet", {
        account: redactWalletForDebug(walletBridgeState.account),
        linkedWalletAddresses:
          walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
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
      linkedWalletAddresses:
        walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
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

      await Promise.resolve(getWalletBridgeState().logout?.());
      window.location.reload();
    } catch (error) {
      disconnecting = false;
      resetWalletReloadRequested();
      renderWalletState();

      const notice = disconnectFailureNotice({
        clearedServerSession,
        fallbackMessage: getErrorMessage(
          error,
          "Could not disconnect this wallet.",
        ),
      });

      if (clearedServerSession) {
        sessionSyncCooldownUntilMs =
          Date.now() + WALLET_SESSION_SYNC_COOLDOWN_MS;
      }

      showNotice(notice.message, notice.tone);
    }
  }

  window.addEventListener("dashboard:wallet-state", onState);
  renderWalletState();

  const walletBridgeState = getWalletBridgeState();
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
      linkedWalletAddresses:
        walletBridgeState.linkedWalletAddresses.map(redactWalletForDebug),
      hasIdentityToken: Boolean(walletBridgeState.identityToken),
    });
    void attemptSessionSync("Restoring your sign in...").catch((error) => {
      resetWalletReloadRequested();
      startSessionSyncCooldown(error);
      privyDebugLog(
        "error",
        "initial-sync-trigger:failed",
        debugHttpError(error),
      );
      showNotice(formatPrivySessionErrorMessage(error), "error");
    });
  }

  return () => {
    window.removeEventListener("dashboard:wallet-state", onState);
    shellBindings.forEach((binding) => binding.cleanup());
  };
}
