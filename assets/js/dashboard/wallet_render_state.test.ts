import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  createWalletRenderState,
  walletReadyForSession,
} from "./wallet_render_state.ts";

describe("walletReadyForSession", () => {
  it("returns true when the wallet matches one of the linked addresses", () => {
    assert.equal(
      walletReadyForSession(
        ["0x1111111111111111111111111111111111111111"],
        "0x1111111111111111111111111111111111111111",
      ),
      true,
    );
  });

  it("returns false when the wallet is missing from the linked addresses", () => {
    assert.equal(
      walletReadyForSession(
        ["0x1111111111111111111111111111111111111111"],
        "0x2222222222222222222222222222222222222222",
      ),
      false,
    );
  });
});

describe("createWalletRenderState", () => {
  it("keeps showing the server wallet while that server sign-in is still active", () => {
    assert.deepEqual(
      createWalletRenderState({
        privyReady: true,
        authenticated: true,
        detailAccount: "0x2222222222222222222222222222222222222222",
        bridgeAccount: "0x2222222222222222222222222222222222222222",
        linkedWalletAddresses: ["0x2222222222222222222222222222222222222222"],
        serverSignedIn: true,
        serverAddress: "0x1111111111111111111111111111111111111111",
      }),
      {
        privyReady: true,
        authenticated: true,
        connected: true,
        connectedAddress: "0x1111111111111111111111111111111111111111",
      },
    );
  });

  it("shows the linked local wallet once the page is relying on local wallet state", () => {
    assert.deepEqual(
      createWalletRenderState({
        privyReady: true,
        authenticated: true,
        detailAccount: "0x2222222222222222222222222222222222222222",
        bridgeAccount: "0x2222222222222222222222222222222222222222",
        linkedWalletAddresses: ["0x2222222222222222222222222222222222222222"],
        serverSignedIn: false,
        serverAddress: "0x1111111111111111111111111111111111111111",
      }),
      {
        privyReady: true,
        authenticated: true,
        connected: true,
        connectedAddress: "0x2222222222222222222222222222222222222222",
      },
    );
  });
});
