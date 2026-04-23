import { animate } from "animejs";

import {
  abbreviateWalletAddress,
  getErrorMessage,
  setNoticeState,
} from "./shared";
import type { Cleanup } from "./types";
import type { WalletNoticeTone } from "./wallet_bridge_state";
import type { WalletRenderState } from "./wallet_render_state";

export type WalletShellBinding = {
  clearNotice: () => void;
  cleanup: Cleanup;
  renderWalletState: (state: WalletRenderState) => void;
  showNotice: (message: string, tone?: WalletNoticeTone) => void;
};

export type WalletShellBindingOptions = {
  getDisconnecting: () => boolean;
  getPendingConnect: () => boolean;
  onConnectClick: () => void;
  onDisconnectClick: () => Promise<void>;
  serverAddress: `0x${string}` | null;
};

export function bindDashboardWalletShell(
  el: HTMLElement,
  options: WalletShellBindingOptions,
): WalletShellBinding {
  const connectButton = el.querySelector<HTMLButtonElement>(
    "[data-wallet-sign-in]",
  );
  const connectLabel = el.querySelector<HTMLElement>(
    "[data-wallet-sign-in-label]",
  );
  const connectedShell = el.querySelector<HTMLElement>(
    "[data-wallet-connected]",
  );
  const triggerButton = el.querySelector<HTMLButtonElement>(
    "[data-wallet-trigger]",
  );
  const caret = el.querySelector<HTMLElement>("[data-wallet-caret]");
  const drawer = el.querySelector<HTMLElement>("[data-wallet-drawer]");
  const drawerInner = el.querySelector<HTMLElement>(
    "[data-wallet-drawer-inner]",
  );
  const addressText = el.querySelector<HTMLElement>(
    "[data-wallet-address-text]",
  );
  const copyButton = el.querySelector<HTMLButtonElement>("[data-wallet-copy]");
  const copyIcon = el.querySelector<HTMLElement>("[data-wallet-copy-icon]");
  const copyCheck = el.querySelector<HTMLElement>("[data-wallet-copy-check]");
  const copyState = el.querySelector<HTMLElement>("[data-wallet-copy-state]");
  const disconnectButton = el.querySelector<HTMLButtonElement>(
    "[data-wallet-disconnect]",
  );
  const notice = el.querySelector<HTMLElement>(
    "[data-dashboard-wallet-notice]",
  );
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

    if (copyButton) {
      copyButton.dataset.copied = "false";
    }

    if (copyState) {
      copyState.classList.add("hidden");
      copyState.textContent = "Copied";
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
      connectButton.disabled =
        state.connected ||
        !state.privyReady ||
        options.getDisconnecting() ||
        options.getPendingConnect();

      if (connectLabel) {
        connectLabel.textContent = options.getPendingConnect()
          ? "Waiting for wallet..."
          : "Connect wallet";
      }
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
      copyButton.dataset.copied = "false";
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

      if (copyButton) {
        copyButton.dataset.copied = "true";
      }

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

        if (copyState) {
          copyState.classList.remove("hidden");
          copyState.textContent = "Copied";
        }

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

          if (copyState) {
            copyState.classList.add("hidden");
          }
        }, 900);
      }
    } catch (error) {
      showNotice(
        getErrorMessage(error, "Could not copy this wallet address."),
        "error",
      );
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
