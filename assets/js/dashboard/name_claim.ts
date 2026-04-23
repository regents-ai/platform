import { createPublicClient, http } from "viem";
import { base, mainnet } from "viem/chains";

import {
  createMintMessage,
  fetchJson,
  getErrorMessage,
  parseConfig,
  readRequiredValue,
  requiredAddress,
  requiredBigInt,
  setNoticeState,
} from "./shared";
import type { Cleanup } from "./types";
import { ensureWalletReady } from "./wallet_runtime";

export function bindDashboardNameClaim(el: HTMLElement): Cleanup {
  const config = parseConfig(el.dataset.dashboardConfig);
  const freeButton = el.querySelector<HTMLButtonElement>(
    "[data-dashboard-claim-free]",
  );
  const paidButton = el.querySelector<HTMLButtonElement>(
    "[data-dashboard-claim-paid]",
  );
  const notice = el.querySelector<HTMLElement>("[data-dashboard-claim-notice]");
  const phase1Input = el.querySelector<HTMLInputElement>(
    "#app-identity-phase1-name",
  );
  const phase2Input = el.querySelector<HTMLInputElement>(
    "#app-identity-phase2-name",
  );
  const syncTimers = new Set<number>();
  let busy = false;

  const showNotice = (
    message: string,
    tone: "error" | "info" | "success" = "info",
  ) => {
    if (!notice) return;
    setNoticeState(notice, message, tone);
  };

  const setBusy = (
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

  const claimSuccessRedirect = (label: string) => {
    const params = new URLSearchParams({ claimedLabel: label });
    window.location.assign(`/app/billing?${params.toString()}`);
  };

  const syncAutofilledField = (
    input: HTMLInputElement | null,
    normalizedSelector: string,
  ) => {
    if (!input) return;

    const currentValue = input.value.trim();

    if (!currentValue) return;

    const normalizedValue =
      el
        .querySelector<HTMLInputElement>(normalizedSelector)
        ?.value.trim()
        .toLowerCase() ?? "";

    if (normalizedValue === currentValue.toLowerCase()) return;

    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));
  };

  const queueAutofillSync = () => {
    [
      window.setTimeout(
        () => syncAutofilledField(phase1Input, "#phase1-normalized-label"),
        0,
      ),
      window.setTimeout(
        () => syncAutofilledField(phase2Input, "#phase2-normalized-label"),
        0,
      ),
      window.setTimeout(
        () => syncAutofilledField(phase1Input, "#phase1-normalized-label"),
        180,
      ),
      window.setTimeout(
        () => syncAutofilledField(phase2Input, "#phase2-normalized-label"),
        180,
      ),
    ].forEach((timer) => syncTimers.add(timer));
  };

  queueAutofillSync();

  const performFreeClaim = async () => {
    if (!config?.basenamesMint) {
      showNotice("Name claims are not configured yet.", "error");
      return;
    }

    const wallet = ensureWalletReady();
    const normalizedLabel = readRequiredValue(
      el,
      "#phase1-normalized-label",
      "Enter a valid name.",
    );
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

      showNotice(`Claimed ${fqdn}. Opening the next step...`, "success");
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
    const normalizedLabel = readRequiredValue(
      el,
      "#phase2-normalized-label",
      "Enter a valid name.",
    );
    const fqdn = readRequiredValue(el, "#phase2-fqdn", "Enter a valid name.");
    const paymentRecipient = requiredAddress(
      paidButton?.dataset.paymentRecipient,
      "Paid claims are unavailable right now.",
    );
    const priceWei = requiredBigInt(
      paidButton?.dataset.priceWei,
      "Paid claims are unavailable right now.",
    );
    const paymentChain = wallet.chainId === mainnet.id ? mainnet : base;

    if (wallet.chainId !== base.id && wallet.chainId !== mainnet.id) {
      showNotice(
        "Switch to Base or Ethereum before paying for this name.",
        "error",
      );
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

      const receipt = await paymentClient.waitForTransactionReceipt({
        hash: txHash,
        timeout: 120_000,
      });
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

      showNotice(`Claimed ${fqdn}. Opening the next step...`, "success");
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
    syncTimers.forEach((timer) => window.clearTimeout(timer));
    syncTimers.clear();
    freeButton?.removeEventListener("click", onFreeClick);
    paidButton?.removeEventListener("click", onPaidClick);
  };
}
