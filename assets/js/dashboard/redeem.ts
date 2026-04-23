import { createPublicClient, http } from "viem";
import { base } from "viem/chains";

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
  formatRegentRounded2,
  getErrorMessage,
  parseConfig,
  requiredAddress,
  requiredBigInt,
  setNoticeState,
} from "./shared";
import type { Cleanup } from "./types";
import { ensureWalletReady, getWalletBridgeState } from "./wallet_runtime";

export function bindDashboardRedeem(el: HTMLElement): Cleanup {
  const config = parseConfig(el.dataset.dashboardConfig);
  const sourceSelect = el.querySelector<HTMLSelectElement>(
    "[data-dashboard-redeem-source]",
  );
  const tokenIdInput = el.querySelector<HTMLInputElement>(
    "[data-dashboard-redeem-token-id]",
  );
  const approveNftButton = el.querySelector<HTMLButtonElement>(
    "[data-dashboard-redeem-approve-nft]",
  );
  const approveUsdcButton = el.querySelector<HTMLButtonElement>(
    "[data-dashboard-redeem-approve-usdc]",
  );
  const redeemButton = el.querySelector<HTMLButtonElement>(
    "[data-dashboard-redeem-start]",
  );
  const claimButton = el.querySelector<HTMLButtonElement>(
    "[data-dashboard-redeem-claim]",
  );
  const claimableEl = el.querySelector<HTMLElement>(
    "[data-dashboard-redeem-claimable]",
  );
  const remainingEl = el.querySelector<HTMLElement>(
    "[data-dashboard-redeem-remaining]",
  );
  const notice = el.querySelector<HTMLElement>(
    "[data-dashboard-redeem-notice]",
  );
  let busy = false;

  const showNotice = (
    message: string,
    tone: "error" | "info" | "success" = "info",
  ) => {
    if (!notice) return;
    setNoticeState(notice, message, tone);
  };

  const setButtonBusy = (
    button: HTMLButtonElement | null,
    nextBusy: boolean,
    busyLabel: string,
    idleLabel: string,
  ) => {
    busy = nextBusy;
    if (!button) return;
    button.disabled = nextBusy;
    button.textContent = nextBusy ? busyLabel : idleLabel;
  };

  const refreshClaimable = async () => {
    const walletBridgeState = getWalletBridgeState();

    if (!config?.redeemerAddress || !claimableEl || !remainingEl) return;
    if (!walletBridgeState.account) {
      claimableEl.textContent = "--";
      remainingEl.textContent = "--";
      return;
    }

    try {
      const address = requiredAddress(
        config.redeemerAddress,
        "Redeemer address is missing.",
      );
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
    const redeemerAddress = requiredAddress(
      config?.redeemerAddress,
      "Redeemer address is missing.",
    );
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
    const redeemerAddress = requiredAddress(
      config?.redeemerAddress,
      "Redeemer address is missing.",
    );
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
      setButtonBusy(
        approveUsdcButton,
        false,
        "Approving...",
        "Approve 80 USDC",
      );
    }
  };

  const redeem = async () => {
    const wallet = ensureBaseWallet();
    const redeemerAddress = requiredAddress(
      config?.redeemerAddress,
      "Redeemer address is missing.",
    );
    const source = sourceSelect?.value === "ANIMATA2" ? ANIMATA2 : ANIMATA1;
    const tokenId = requiredBigInt(
      tokenIdInput?.value,
      "Enter a token ID from 1 to 999.",
    );
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
    const redeemerAddress = requiredAddress(
      config?.redeemerAddress,
      "Redeemer address is missing.",
    );
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
    void redeem().catch((error) =>
      showNotice(getErrorMessage(error, "Redeem failed."), "error"),
    );
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
