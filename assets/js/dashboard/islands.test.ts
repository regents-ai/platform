import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  createWalletSessionSyncAttemptKey,
  decideWalletSessionSync,
} from "./wallet_session_sync.ts";

const linkedWallet = "0x1111111111111111111111111111111111111111" as const;
const otherWallet = "0x2222222222222222222222222222222222222222" as const;

describe("createWalletSessionSyncAttemptKey", () => {
  it("returns null when the connected wallet is not linked to the authenticated person", () => {
    assert.equal(
      createWalletSessionSyncAttemptKey({
        authenticated: true,
        account: linkedWallet,
        identityToken: "token-a",
        linkedWalletAddresses: [otherWallet],
      }),
      null,
    );
  });

  it("changes when the identity token changes", () => {
    const first = createWalletSessionSyncAttemptKey({
      authenticated: true,
      account: linkedWallet,
      identityToken: "token-a",
      linkedWalletAddresses: [linkedWallet],
    });
    const second = createWalletSessionSyncAttemptKey({
      authenticated: true,
      account: linkedWallet,
      identityToken: "token-b",
      linkedWalletAddresses: [linkedWallet],
    });

    assert.notEqual(first, null);
    assert.notEqual(second, null);
    assert.notEqual(first, second);
  });
});

describe("decideWalletSessionSync", () => {
  it("allows the first sync attempt for a signed-out page once the wallet is ready", () => {
    assert.deepEqual(
      decideWalletSessionSync({
        serverSignedIn: false,
        pendingConnect: false,
        lastAttemptKey: null,
        state: {
          authenticated: true,
          account: linkedWallet,
          identityToken: "token-a",
          linkedWalletAddresses: [linkedWallet],
        },
      }).shouldSync,
      true,
    );
  });

  it("blocks repeated attempts for the same wallet state", () => {
    const attemptKey = createWalletSessionSyncAttemptKey({
      authenticated: true,
      account: linkedWallet,
      identityToken: "token-a",
      linkedWalletAddresses: [linkedWallet],
    });

    assert.notEqual(attemptKey, null);

    assert.deepEqual(
      decideWalletSessionSync({
        serverSignedIn: false,
        pendingConnect: false,
        lastAttemptKey: attemptKey,
        state: {
          authenticated: true,
          account: linkedWallet,
          identityToken: "token-a",
          linkedWalletAddresses: [linkedWallet],
        },
      }),
      {
        shouldSync: false,
        attemptKey,
      },
    );
  });

  it("allows another attempt after the wallet state materially changes", () => {
    const previousAttemptKey = createWalletSessionSyncAttemptKey({
      authenticated: true,
      account: linkedWallet,
      identityToken: "token-a",
      linkedWalletAddresses: [linkedWallet],
    });

    assert.notEqual(previousAttemptKey, null);

    assert.deepEqual(
      decideWalletSessionSync({
        serverSignedIn: false,
        pendingConnect: false,
        lastAttemptKey: previousAttemptKey,
        state: {
          authenticated: true,
          account: linkedWallet,
          identityToken: "token-b",
          linkedWalletAddresses: [linkedWallet],
        },
      }).shouldSync,
      true,
    );
  });

  it("blocks retries during the cooldown window even when the wallet state changes", () => {
    const previousAttemptKey = createWalletSessionSyncAttemptKey({
      authenticated: true,
      account: linkedWallet,
      identityToken: "token-a",
      linkedWalletAddresses: [linkedWallet],
    });

    assert.notEqual(previousAttemptKey, null);

    assert.deepEqual(
      decideWalletSessionSync({
        serverSignedIn: false,
        pendingConnect: true,
        lastAttemptKey: previousAttemptKey,
        cooldownUntilMs: 2_000,
        nowMs: 1_000,
        state: {
          authenticated: true,
          account: linkedWallet,
          identityToken: "token-b",
          linkedWalletAddresses: [linkedWallet],
        },
      }).shouldSync,
      false,
    );
  });

  it("allows retries again after the cooldown expires", () => {
    const previousAttemptKey = createWalletSessionSyncAttemptKey({
      authenticated: true,
      account: linkedWallet,
      identityToken: "token-a",
      linkedWalletAddresses: [linkedWallet],
    });

    assert.notEqual(previousAttemptKey, null);

    assert.deepEqual(
      decideWalletSessionSync({
        serverSignedIn: false,
        pendingConnect: true,
        lastAttemptKey: previousAttemptKey,
        cooldownUntilMs: 2_000,
        nowMs: 2_001,
        state: {
          authenticated: true,
          account: linkedWallet,
          identityToken: "token-b",
          linkedWalletAddresses: [linkedWallet],
        },
      }).shouldSync,
      true,
    );
  });
});
