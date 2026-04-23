import {
  PrivyProvider,
  type PrivyClientConfig,
  useIdentityToken,
  usePrivy,
  useUser,
} from "@privy-io/react-auth";
import React from "react";
import { createRoot, type Root } from "react-dom/client";

import {
  getLinkedWalletAddressesFromPrivyUser,
  usePrivyWalletClient,
} from "./privy";
import {
  getPrivyDisplayName,
  parseConfig,
  privyDebugLog,
  redactWalletForDebug,
} from "./shared";
import {
  createWalletBridgeDispatchKey,
  emitWalletBridgeState,
  resetWalletBridgeState,
  setWalletBridgeState,
} from "./wallet_runtime";
import type { WalletBridgeState } from "./wallet_bridge_state";

const bridgeRoots = new WeakMap<Element, Root>();
const DASHBOARD_PRIVY_CONFIG: PrivyClientConfig = {
  loginMethods: ["wallet"],
  appearance: {
    walletChainType: "ethereum-only",
    walletList: ["metamask", "coinbase_wallet", "rainbow", "wallet_connect"],
  },
};

let lastWalletBridgeDispatchKey: string | null = null;

function DashboardPrivyBridge() {
  const { ready, authenticated, isModalOpen, login, linkWallet, logout, user } =
    usePrivy();
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
      isModalOpen,
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

    setWalletBridgeState(nextWalletBridgeState);

    const nextDispatchKey = createWalletBridgeDispatchKey(
      nextWalletBridgeState,
    );

    if (nextDispatchKey === lastWalletBridgeDispatchKey) {
      return;
    }

    lastWalletBridgeDispatchKey = nextDispatchKey;

    privyDebugLog("info", "bridge-state", {
      ready,
      authenticated,
      isModalOpen,
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
    isModalOpen,
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
    resetWalletBridgeState();
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
