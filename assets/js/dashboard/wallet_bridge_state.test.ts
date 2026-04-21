import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  disconnectFailureNotice,
  emptyWalletBridgeState,
} from "./wallet_bridge_state.ts";

describe("emptyWalletBridgeState", () => {
  it("returns a fully signed-out bridge state", () => {
    assert.deepEqual(emptyWalletBridgeState(), {
      privyReady: false,
      authenticated: false,
      isModalOpen: false,
      account: null,
      chainId: null,
      privyId: null,
      wallet: null,
      walletClient: null,
      displayName: null,
      identityToken: null,
      linkedWalletAddresses: [],
      login: null,
      linkWallet: null,
      logout: null,
      refreshUser: null,
    });
  });
});

describe("disconnectFailureNotice", () => {
  it("tells the truth when only the site sign-out succeeded", () => {
    assert.deepEqual(
      disconnectFailureNotice({
        clearedServerSession: true,
        fallbackMessage: "Could not disconnect this wallet.",
      }),
      {
        message:
          "Signed out here. Your wallet app is still connected, so disconnect it there if you want to fully close it.",
        tone: "info",
      },
    );
  });

  it("keeps the error path for a full disconnect failure", () => {
    assert.deepEqual(
      disconnectFailureNotice({
        clearedServerSession: false,
        fallbackMessage: "Could not disconnect this wallet.",
      }),
      {
        message: "Could not disconnect this wallet.",
        tone: "error",
      },
    );
  });
});
