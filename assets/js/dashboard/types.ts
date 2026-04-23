export type DashboardConfig = {
  privyAppId: string | null;
  privyClientId: string | null;
  privySession?: string;
  basenamesMint?: string;
  baseRpcUrl?: string | null;
  redeemerAddress?: string | null;
};

export type BridgeEventDetail = {
  privyReady: boolean;
  authenticated: boolean;
  isModalOpen: boolean;
  account: `0x${string}` | null;
  chainId: number | null;
};

export type Cleanup = () => void;
