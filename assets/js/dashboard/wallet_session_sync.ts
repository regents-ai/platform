export type WalletSessionSyncState = {
  authenticated: boolean;
  account: string | null;
  identityToken: string | null;
  linkedWalletAddresses: readonly string[];
};

export type WalletSessionSyncDecision = {
  shouldSync: boolean;
  attemptKey: string | null;
};

function normalizeWalletAddress(value: string | null | undefined): string | null {
  const trimmed = value?.trim();

  if (!trimmed) return null;
  if (!/^0x[0-9a-fA-F]{40}$/.test(trimmed)) return null;
  return trimmed.toLowerCase();
}

export function createWalletSessionSyncAttemptKey(
  state: WalletSessionSyncState,
): string | null {
  if (!state.authenticated) return null;

  const account = normalizeWalletAddress(state.account);
  if (!account) return null;

  const linkedWalletAddresses = state.linkedWalletAddresses
    .map((candidate) => normalizeWalletAddress(candidate))
    .filter((candidate): candidate is string => candidate !== null)
    .sort();

  if (!linkedWalletAddresses.includes(account)) {
    return null;
  }

  return JSON.stringify({
    account,
    identityToken: state.identityToken?.trim() ?? "",
    linkedWalletAddresses,
  });
}

export function decideWalletSessionSync(args: {
  serverSignedIn: boolean;
  pendingConnect: boolean;
  lastAttemptKey: string | null;
  cooldownUntilMs?: number;
  nowMs?: number;
  state: WalletSessionSyncState;
}): WalletSessionSyncDecision {
  const attemptKey = createWalletSessionSyncAttemptKey(args.state);
  const nowMs = args.nowMs ?? Date.now();

  if (!attemptKey) {
    return { shouldSync: false, attemptKey: null };
  }

  if ((args.cooldownUntilMs ?? 0) > nowMs) {
    return { shouldSync: false, attemptKey };
  }

  if (!(args.pendingConnect || !args.serverSignedIn)) {
    return { shouldSync: false, attemptKey };
  }

  if (args.lastAttemptKey === attemptKey) {
    return { shouldSync: false, attemptKey };
  }

  return { shouldSync: true, attemptKey };
}
