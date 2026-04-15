import { PrivyProvider, useIdentityToken, usePrivy } from "@privy-io/react-auth";
import { animate } from "animejs";
import React from "react";
import { createRoot, type Root } from "react-dom/client";
import {
  createPublicClient,
  http,
  isAddress,
  type WalletClient,
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
import { usePrivyWalletClient, type PrivyEthereumWalletLike } from "./privy";

type DashboardConfig = {
  privyAppId: string | null;
  privyClientId: string | null;
  privySession?: string;
  basenamesMint?: string;
  baseRpcUrl?: string | null;
  redeemerAddress?: string | null;
};

type WalletBridgeState = {
  privyReady: boolean;
  authenticated: boolean;
  account: `0x${string}` | null;
  chainId: number | null;
  privyId: string | null;
  wallet: PrivyEthereumWalletLike | null;
  walletClient: WalletClient | null;
  displayName: string | null;
  identityToken: string | null;
  login: (() => void) | null;
  logout: (() => void) | null;
};

type BridgeEventDetail = {
  privyReady: boolean;
  authenticated: boolean;
  account: `0x${string}` | null;
  chainId: number | null;
};

type Cleanup = () => void;

const bridgeRoots = new WeakMap<Element, Root>();

let walletBridgeState: WalletBridgeState = {
  privyReady: false,
  authenticated: false,
  account: null,
  chainId: null,
  privyId: null,
  wallet: null,
  walletClient: null,
  displayName: null,
  identityToken: null,
  login: null,
  logout: null,
};

let walletSessionSyncInFlight: Promise<void> | null = null;
let walletReloadRequested = false;

function parseConfig(raw: string | null | undefined): DashboardConfig | null {
  if (!raw) return null;

  try {
    return JSON.parse(raw) as DashboardConfig;
  } catch {
    return null;
  }
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
  const { ready, authenticated, login, logout, user } = usePrivy();
  const { identityToken } = useIdentityToken();
  const { account, chainId, privyId, wallet, walletClient } =
    usePrivyWalletClient();

  React.useEffect(() => {
    walletBridgeState = {
      privyReady: ready,
      authenticated,
      account,
      chainId,
      privyId,
      wallet,
      walletClient,
      displayName: getPrivyDisplayName(user),
      identityToken,
      login,
      logout,
    };

    emitWalletBridgeState();
  }, [
    account,
    authenticated,
    chainId,
    identityToken,
    login,
    logout,
    privyId,
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
    walletBridgeState = {
      ...walletBridgeState,
      privyReady: false,
      login: null,
      logout: null,
    };
    emitWalletBridgeState();
    return;
  }

  const existing = bridgeRoots.get(el);
  if (existing) return;

  const root = createRoot(el);
  root.render(
    <React.StrictMode>
      <PrivyProvider appId={config.privyAppId} clientId={config.privyClientId}>
        <DashboardPrivyBridge />
      </PrivyProvider>
    </React.StrictMode>,
  );
  bridgeRoots.set(el, root);
}

export function unmountDashboardPrivyBridge(el: Element): void {
  const root = bridgeRoots.get(el);
  if (!root) return;

  root.unmount();
  bridgeRoots.delete(el);
}

export function bindDashboardWallet(el: HTMLElement): Cleanup {
  const config = parseConfig(el.dataset.dashboardConfig);
  const connectButton = el.querySelector<HTMLButtonElement>("[data-wallet-sign-in]");
  const connectedShell = el.querySelector<HTMLElement>("[data-wallet-connected]");
  const triggerButton = el.querySelector<HTMLButtonElement>("[data-wallet-trigger]");
  const caret = el.querySelector<HTMLElement>("[data-wallet-caret]");
  const drawer = el.querySelector<HTMLElement>("[data-wallet-drawer]");
  const drawerInner = el.querySelector<HTMLElement>("[data-wallet-drawer-inner]");
  const addressText = el.querySelector<HTMLElement>("[data-wallet-address-text]");
  const copyButton = el.querySelector<HTMLButtonElement>("[data-wallet-copy]");
  const copyCheck = el.querySelector<HTMLElement>("[data-wallet-copy-check]");
  const disconnectButton = el.querySelector<HTMLButtonElement>("[data-wallet-disconnect]");
  const notice = el.querySelector<HTMLElement>("[data-dashboard-wallet-notice]");
  const serverSignedIn = el.dataset.walletSignedIn === "true";
  const serverAddress = normalizeWalletAddress(el.dataset.walletAddress);
  let pendingConnect = false;
  let drawerOpen = false;
  let copyResetTimer: number | undefined;
  let disconnecting = false;

  const showNotice = (message: string, tone: "error" | "info" = "info") => {
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

  const renderWalletState = (detail?: Partial<BridgeEventDetail>) => {
    const privyReady = detail?.privyReady ?? walletBridgeState.privyReady;
    const authenticated = detail?.authenticated ?? walletBridgeState.authenticated;
    const connectedAddress =
      normalizeWalletAddress(detail?.account) ??
      normalizeWalletAddress(walletBridgeState.account) ??
      serverAddress;
    const connected = serverSignedIn || authenticated;

    if (connectButton) {
      connectButton.disabled = connected || !privyReady || disconnecting;
    }

    if (triggerButton) {
      triggerButton.disabled = !connected || disconnecting;
    }

    if (disconnectButton) {
      disconnectButton.disabled = disconnecting;
    }

    setHidden(connectButton, connected);
    setHidden(connectedShell, !connected);

    if (!connected) {
      closeDrawer(true);
    }

    if (addressText) {
      addressText.textContent = abbreviateWalletAddress(connectedAddress);
    }

    if (copyButton) {
      copyButton.disabled = !connectedAddress;
    }
  };

  const syncAndReload = async (label: string) => {
    if (!config?.privySession) return;

    if (!walletSessionSyncInFlight) {
      walletSessionSyncInFlight = syncPrivySession(config.privySession).finally(() => {
        walletSessionSyncInFlight = null;
      });
    }

    showNotice(label, "info");
    await walletSessionSyncInFlight;

    if (!walletReloadRequested) {
      walletReloadRequested = true;
      window.location.reload();
    }
  };

  const onState = async (event: Event) => {
    const detail = (event as CustomEvent<BridgeEventDetail>).detail;
    renderWalletState(detail);

    if (
      detail.authenticated &&
      walletBridgeState.account &&
      walletBridgeState.identityToken &&
      (pendingConnect || !serverSignedIn)
    ) {
      pendingConnect = false;

      try {
        await syncAndReload(
          serverSignedIn ? "Restoring your sign in..." : "Finishing sign in...",
        );
      } catch (error) {
        walletReloadRequested = false;
        showNotice(getErrorMessage(error, "Could not start your wallet session."), "error");
      }
    }
  };

  const onConnectClick = () => {
    if (!walletBridgeState.login) {
      showNotice("Wallet sign-in is not ready yet.", "error");
      return;
    }

    pendingConnect = true;
    showNotice("Waiting for wallet confirmation...", "info");
    walletBridgeState.login();
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
    const address =
      normalizeWalletAddress(walletBridgeState.account) ??
      serverAddress;

    if (!address) {
      showNotice("No wallet address is available yet.", "error");
      return;
    }

    try {
      await navigator.clipboard.writeText(address);

      if (copyResetTimer) {
        window.clearTimeout(copyResetTimer);
      }

      if (copyCheck) {
        copyCheck.style.opacity = "0";
        copyCheck.style.transform = "scale(0.6)";

        animate(copyCheck, {
          opacity: [0, 1],
          scale: [0.6, 1],
          duration: 180,
          ease: "outBack",
        });

        copyResetTimer = window.setTimeout(() => {
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

  const onDisconnectClick = async () => {
    try {
      disconnecting = true;
      pendingConnect = false;
      closeDrawer(true);
      renderWalletState();
      showNotice("Signing out...", "info");

      if (config?.privySession) {
        await clearPrivySession(config.privySession);
      }

      await Promise.resolve(walletBridgeState.logout?.());
      window.location.reload();
    } catch (error) {
      disconnecting = false;
      walletReloadRequested = false;
      renderWalletState();
      showNotice(getErrorMessage(error, "Could not disconnect this wallet."), "error");
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

  window.addEventListener("dashboard:wallet-state", onState);
  window.addEventListener("click", onWindowClick);
  window.addEventListener("keydown", onWindowKeydown);
  connectButton?.addEventListener("click", onConnectClick);
  triggerButton?.addEventListener("click", onTriggerClick);
  copyButton?.addEventListener("click", onCopyClick);
  disconnectButton?.addEventListener("click", onDisconnectClick);
  renderWalletState();

  if (
    walletBridgeState.authenticated &&
    walletBridgeState.account &&
    walletBridgeState.identityToken &&
    !serverSignedIn
  ) {
    void syncAndReload("Restoring your sign in...").catch((error) => {
      walletReloadRequested = false;
      showNotice(getErrorMessage(error, "Could not start your wallet session."), "error");
    });
  }

  return () => {
    if (copyResetTimer) {
      window.clearTimeout(copyResetTimer);
    }

    window.removeEventListener("dashboard:wallet-state", onState);
    window.removeEventListener("click", onWindowClick);
    window.removeEventListener("keydown", onWindowKeydown);
    connectButton?.removeEventListener("click", onConnectClick);
    triggerButton?.removeEventListener("click", onTriggerClick);
    copyButton?.removeEventListener("click", onCopyClick);
    disconnectButton?.removeEventListener("click", onDisconnectClick);
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
  if (!walletBridgeState.account || !walletBridgeState.identityToken) {
    throw new Error("Wallet session is not ready.");
  }

  await fetchJson(endpoint, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${walletBridgeState.identityToken}`,
    },
    body: JSON.stringify({
      display_name: walletBridgeState.displayName,
    }),
  });
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
    throw new Error(message);
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

function getWalletAddressesFromPrivyUser(privyUser: unknown): `0x${string}`[] {
  if (!privyUser || typeof privyUser !== "object") return [];

  const candidateAddresses = new Set<string>();
  const directWalletAddress =
    "wallet" in privyUser &&
    privyUser.wallet &&
    typeof privyUser.wallet === "object" &&
    "address" in privyUser.wallet
      ? privyUser.wallet.address
      : null;

  if (typeof directWalletAddress === "string" && isAddress(directWalletAddress)) {
    candidateAddresses.add(directWalletAddress);
  }

  const linkedAccounts =
    "linkedAccounts" in privyUser && Array.isArray(privyUser.linkedAccounts)
      ? privyUser.linkedAccounts
      : [];

  linkedAccounts.forEach((account) => {
    if (
      account &&
      typeof account === "object" &&
      typeof account.type === "string" &&
      (account.type === "wallet" ||
        account.type === "wallet_account" ||
        account.type === "ethereum") &&
      typeof account.address === "string" &&
      isAddress(account.address)
    ) {
      candidateAddresses.add(account.address);
    }
  });

  return Array.from(candidateAddresses) as `0x${string}`[];
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
