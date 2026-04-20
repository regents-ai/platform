export type WalletRenderState = {
  privyReady: boolean;
  authenticated: boolean;
  connected: boolean;
  connectedAddress: string | null;
};

export function walletReadyForSession(
  linkedWalletAddresses: readonly string[],
  address: string | null | undefined,
): boolean {
  if (linkedWalletAddresses.length === 0) return false;
  if (!address) return false;

  return linkedWalletAddresses.some(
    (candidate) => candidate.toLowerCase() === address.toLowerCase(),
  );
}

export function createWalletRenderState(args: {
  privyReady: boolean;
  authenticated: boolean;
  detailAccount: string | null;
  bridgeAccount: string | null;
  linkedWalletAddresses: readonly string[];
  serverSignedIn: boolean;
  serverAddress: string | null;
}): WalletRenderState {
  const bridgeConnectedAddress =
    args.detailAccount ?? args.bridgeAccount ?? args.serverAddress;

  return {
    privyReady: args.privyReady,
    authenticated: args.authenticated,
    connected:
      args.serverSignedIn ||
      (args.authenticated &&
        walletReadyForSession(args.linkedWalletAddresses, bridgeConnectedAddress)),
    connectedAddress:
      args.serverSignedIn && args.serverAddress
        ? args.serverAddress
        : bridgeConnectedAddress,
  };
}
