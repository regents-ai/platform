import { sendDashboardWalletTransaction } from "./dashboard/islands";

type HookContext = {
  el: HTMLElement;
  handleEvent: (event: string, callback: (payload: any) => void) => void;
  pushEvent: (event: string, payload: Record<string, unknown>) => void;
};

function getErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error) {
    const message = error.message.trim();
    return message.length > 0 ? message : fallback;
  }

  return fallback;
}

export const TokenStakingHook = {
  mounted(this: HookContext) {
    const baseRpcUrl = this.el.dataset.baseRpcUrl ?? undefined;
    const baseSepoliaRpcUrl = this.el.dataset.baseSepoliaRpcUrl ?? undefined;

    this.handleEvent("regent-staking:wallet-action", async (payload) => {
      try {
        const walletAction = payload.wallet_action;
        const txHash = await sendDashboardWalletTransaction(
          {
            chain_id: walletAction.chain_id,
            to: walletAction.to,
            value: walletAction.value,
            data: walletAction.data,
          },
          {
          baseRpcUrl,
          baseSepoliaRpcUrl,
          }
        );

        this.pushEvent("staking_tx_complete", { tx_hash: txHash, action: payload.action });
      } catch (error) {
        this.pushEvent("staking_tx_failed", {
          action: payload.action,
          message: getErrorMessage(error, "The staking transaction did not finish."),
        });
      }
    });
  },
};
