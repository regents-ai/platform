import os from "node:os";
import path from "node:path";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";

const DEFAULT_ORIGIN = "https://regents.sh";
const DEFAULT_IDENTITY_TOKEN_ENV = "REGENT_PLATFORM_IDENTITY_TOKEN";
const DEFAULT_SESSION_FILE = path.join(os.homedir(), ".regent", "platform", "session.json");

interface PlatformBaseCommand {
  origin: string | null;
  sessionFile: string;
}

export interface PlatformAuthLoginCommand extends PlatformBaseCommand {
  kind: "platform-auth-login";
  identityToken: string;
  display_name: string | null;
}

export interface PlatformAuthStatusCommand extends PlatformBaseCommand {
  kind: "platform-auth-status";
}

export interface PlatformAuthLogoutCommand extends PlatformBaseCommand {
  kind: "platform-auth-logout";
}

export interface PlatformFormationStatusCommand extends PlatformBaseCommand {
  kind: "platform-formation-status";
}

export interface PlatformBillingAccountCommand extends PlatformBaseCommand {
  kind: "platform-billing-account";
}

export interface PlatformBillingUsageCommand extends PlatformBaseCommand {
  kind: "platform-billing-usage";
}

export interface PlatformBillingSetupCommand extends PlatformBaseCommand {
  kind: "platform-billing-setup";
  claimedLabel: string | null;
}

export interface PlatformBillingTopupCommand extends PlatformBaseCommand {
  kind: "platform-billing-topup";
  amountUsdCents: number;
}

export interface PlatformCompanyCreateCommand extends PlatformBaseCommand {
  kind: "platform-company-create";
  claimedLabel: string;
}

export interface PlatformCompanyRuntimeCommand extends PlatformBaseCommand {
  kind: "platform-company-runtime";
  slug: string;
}

export interface PlatformSpritePauseCommand extends PlatformBaseCommand {
  kind: "platform-sprite-pause";
  slug: string;
}

export interface PlatformSpriteResumeCommand extends PlatformBaseCommand {
  kind: "platform-sprite-resume";
  slug: string;
}

export type PlatformCommand =
  | PlatformAuthLoginCommand
  | PlatformAuthStatusCommand
  | PlatformAuthLogoutCommand
  | PlatformFormationStatusCommand
  | PlatformBillingAccountCommand
  | PlatformBillingUsageCommand
  | PlatformBillingSetupCommand
  | PlatformBillingTopupCommand
  | PlatformCompanyCreateCommand
  | PlatformCompanyRuntimeCommand
  | PlatformSpritePauseCommand
  | PlatformSpriteResumeCommand;

interface PlatformSessionState {
  version: 1;
  origin: string;
  cookie: string;
  csrfToken: string;
  savedAt: string;
}

interface JsonObject {
  [key: string]: unknown;
}

type FetchLike = typeof fetch;

export function platformUsageLines() {
  return [
    "regent platform auth login [--identity-token <token> | --identity-token-env REGENT_PLATFORM_IDENTITY_TOKEN] [--display-name \"Regent Operator\"] [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform auth status [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform auth logout [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform formation status [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform billing account [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform billing usage [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform billing setup [--claimed-label tempo] [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform billing topup --amount-usd-cents 800 [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform company create --claimed-label tempo [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform company runtime --slug tempo [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform sprite pause --slug tempo [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
    "regent platform sprite resume --slug tempo [--origin https://regents.sh] [--session-file ~/.regent/platform/session.json]",
  ];
}

export function parsePlatformCommand(
  command: string | undefined,
  args: readonly string[],
  cwd: string,
  fullUsageText: string,
): PlatformCommand {
  if (command === "auth") {
    const [authCommand, ...rest] = args;
    return parsePlatformAuthCommand(authCommand, rest, cwd, fullUsageText);
  }

  if (command === "formation") {
    const [group, ...rest] = args;

    if (group !== "status") {
      throw new Error(`Unknown platform formation command "${group ?? ""}".\n${fullUsageText}`);
    }

    return {
      kind: "platform-formation-status",
      ...parseCommonOnlyPlatformOptions(rest, cwd, "regent platform formation status"),
    };
  }

  if (command === "billing") {
    const [billingCommand, ...rest] = args;
    return parsePlatformBillingCommand(billingCommand, rest, cwd, fullUsageText);
  }

  if (command === "company") {
    const [companyCommand, ...rest] = args;
    return parsePlatformCompanyCommand(companyCommand, rest, cwd, fullUsageText);
  }

  if (command === "sprite") {
    const [spriteCommand, ...rest] = args;
    return parsePlatformSpriteCommand(spriteCommand, rest, cwd, fullUsageText);
  }

  throw new Error(`Unknown platform command "${command ?? ""}".\n${fullUsageText}`);
}

function parsePlatformAuthCommand(
  command: string | undefined,
  args: readonly string[],
  cwd: string,
  fullUsageText: string,
): PlatformCommand {
  if (command === "status") {
    return {
      kind: "platform-auth-status",
      ...parseCommonOnlyPlatformOptions(args, cwd, "regent platform auth status"),
    };
  }

  if (command === "logout") {
    return {
      kind: "platform-auth-logout",
      ...parseCommonOnlyPlatformOptions(args, cwd, "regent platform auth logout"),
    };
  }

  if (command !== "login") {
    throw new Error(`Unknown platform auth command "${command ?? ""}".\n${fullUsageText}`);
  }

  const base = parsePlatformOptions(args, cwd);
  let identityToken: string | null = process.env[DEFAULT_IDENTITY_TOKEN_ENV] ?? null;
  let display_name: string | null = null;

  for (let index = 0; index < args.length; index += 1) {
    const token = args[index]!;
    const commonFlagWidth = consumeCommonPlatformFlag(token, args[index + 1], base, cwd);

    if (commonFlagWidth > 0) {
      index += commonFlagWidth;
      continue;
    }

    if (token === "--identity-token") {
      identityToken = requireStringFlag(args[index + 1], "--identity-token");
      index += 1;
      continue;
    }

    if (token === "--identity-token-env") {
      const envName = requireStringFlag(args[index + 1], "--identity-token-env");
      identityToken = process.env[envName] ?? null;

      if (!identityToken) {
        throw new Error(`Environment variable "${envName}" is empty or missing.`);
      }

      index += 1;
      continue;
    }

    if (token === "--display-name") {
      display_name = requireStringFlag(args[index + 1], "--display-name");
      index += 1;
      continue;
    }

    throw new Error(`Unknown flag "${token}" for regent platform auth login.`);
  }

  if (!identityToken) {
    throw new Error(
      `Provide --identity-token, --identity-token-env, or set ${DEFAULT_IDENTITY_TOKEN_ENV}.`,
    );
  }

  return {
    kind: "platform-auth-login",
    ...base,
    identityToken,
    display_name,
  };
}

function parsePlatformBillingCommand(
  command: string | undefined,
  args: readonly string[],
  cwd: string,
  fullUsageText: string,
): PlatformCommand {
  if (command === "account") {
    return {
      kind: "platform-billing-account",
      ...parseCommonOnlyPlatformOptions(args, cwd, "regent platform billing account"),
    };
  }

  if (command === "usage") {
    return {
      kind: "platform-billing-usage",
      ...parseCommonOnlyPlatformOptions(args, cwd, "regent platform billing usage"),
    };
  }

  if (command === "setup") {
    const base = parsePlatformOptions(args, cwd);
    let claimedLabel: string | null = null;

    for (let index = 0; index < args.length; index += 1) {
      const token = args[index]!;
      const commonFlagWidth = consumeCommonPlatformFlag(token, args[index + 1], base, cwd);

      if (commonFlagWidth > 0) {
        index += commonFlagWidth;
        continue;
      }

      if (token === "--claimed-label") {
        claimedLabel = requireStringFlag(args[index + 1], "--claimed-label");
        index += 1;
        continue;
      }

      throw new Error(`Unknown flag "${token}" for regent platform billing setup.`);
    }

    return {
      kind: "platform-billing-setup",
      ...base,
      claimedLabel,
    };
  }

  if (command === "topup") {
    const base = parsePlatformOptions(args, cwd);
    let amountUsdCents: number | null = null;

    for (let index = 0; index < args.length; index += 1) {
      const token = args[index]!;
      const commonFlagWidth = consumeCommonPlatformFlag(token, args[index + 1], base, cwd);

      if (commonFlagWidth > 0) {
        index += commonFlagWidth;
        continue;
      }

      if (token === "--amount-usd-cents") {
        amountUsdCents = parsePositiveInteger(args[index + 1], "--amount-usd-cents");
        index += 1;
        continue;
      }

      throw new Error(`Unknown flag "${token}" for regent platform billing topup.`);
    }

    if (amountUsdCents === null) {
      throw new Error("Missing required --amount-usd-cents for regent platform billing topup.");
    }

    return {
      kind: "platform-billing-topup",
      ...base,
      amountUsdCents,
    };
  }

  throw new Error(`Unknown platform billing command "${command ?? ""}".\n${fullUsageText}`);
}

function parsePlatformCompanyCommand(
  command: string | undefined,
  args: readonly string[],
  cwd: string,
  fullUsageText: string,
): PlatformCommand {
  if (command === "create") {
    const base = parsePlatformOptions(args, cwd);
    let claimedLabel: string | null = null;

    for (let index = 0; index < args.length; index += 1) {
      const token = args[index]!;
      const commonFlagWidth = consumeCommonPlatformFlag(token, args[index + 1], base, cwd);

      if (commonFlagWidth > 0) {
        index += commonFlagWidth;
        continue;
      }

      if (token === "--claimed-label") {
        claimedLabel = requireStringFlag(args[index + 1], "--claimed-label");
        index += 1;
        continue;
      }

      throw new Error(`Unknown flag "${token}" for regent platform company create.`);
    }

    if (!claimedLabel) {
      throw new Error("Missing required --claimed-label for regent platform company create.");
    }

    return {
      kind: "platform-company-create",
      ...base,
      claimedLabel,
    };
  }

  if (command === "runtime") {
    const base = parsePlatformOptions(args, cwd);
    let slug: string | null = null;

    for (let index = 0; index < args.length; index += 1) {
      const token = args[index]!;
      const commonFlagWidth = consumeCommonPlatformFlag(token, args[index + 1], base, cwd);

      if (commonFlagWidth > 0) {
        index += commonFlagWidth;
        continue;
      }

      if (token === "--slug") {
        slug = requireStringFlag(args[index + 1], "--slug");
        index += 1;
        continue;
      }

      throw new Error(`Unknown flag "${token}" for regent platform company runtime.`);
    }

    if (!slug) {
      throw new Error("Missing required --slug for regent platform company runtime.");
    }

    return {
      kind: "platform-company-runtime",
      ...base,
      slug,
    };
  }

  throw new Error(`Unknown platform company command "${command ?? ""}".\n${fullUsageText}`);
}

function parsePlatformSpriteCommand(
  command: string | undefined,
  args: readonly string[],
  cwd: string,
  fullUsageText: string,
): PlatformCommand {
  if (!command) {
    throw new Error(`Unknown platform sprite command "${command ?? ""}".\n${fullUsageText}`);
  }

  const base = parsePlatformOptions(args, cwd);
  let slug: string | null = null;

  for (let index = 0; index < args.length; index += 1) {
    const token = args[index]!;
    const commonFlagWidth = consumeCommonPlatformFlag(token, args[index + 1], base, cwd);

    if (commonFlagWidth > 0) {
      index += commonFlagWidth;
      continue;
    }

    if (token === "--slug") {
      slug = requireStringFlag(args[index + 1], "--slug");
      index += 1;
      continue;
    }

    throw new Error(`Unknown flag "${token}" for regent platform sprite ${command}.`);
  }

  if (!slug) {
    throw new Error(`Missing required --slug for regent platform sprite ${command}.`);
  }

  if (command === "pause") {
    return {
      kind: "platform-sprite-pause",
      ...base,
      slug,
    };
  }

  if (command === "resume") {
    return {
      kind: "platform-sprite-resume",
      ...base,
      slug,
    };
  }

  throw new Error(`Unknown platform sprite command "${command}".\n${fullUsageText}`);
}

function parsePlatformOptions(args: readonly string[], cwd: string): PlatformBaseCommand {
  const base: PlatformBaseCommand = {
    origin: null,
    sessionFile: DEFAULT_SESSION_FILE,
  };

  for (let index = 0; index < args.length; index += 1) {
    const token = args[index]!;
    const commonFlagWidth = consumeCommonPlatformFlag(token, args[index + 1], base, cwd);

    if (commonFlagWidth > 0) {
      index += commonFlagWidth;
    }
  }

  return base;
}

function parseCommonOnlyPlatformOptions(
  args: readonly string[],
  cwd: string,
  label: string,
): PlatformBaseCommand {
  const base: PlatformBaseCommand = {
    origin: null,
    sessionFile: DEFAULT_SESSION_FILE,
  };

  for (let index = 0; index < args.length; index += 1) {
    const token = args[index]!;
    const commonFlagWidth = consumeCommonPlatformFlag(token, args[index + 1], base, cwd);

    if (commonFlagWidth === 0) {
      throw new Error(`Unknown flag "${token}" for ${label}.`);
    }

    index += commonFlagWidth;
  }

  return base;
}

function consumeCommonPlatformFlag(
  token: string,
  next: string | undefined,
  base: PlatformBaseCommand,
  cwd: string,
): number {
  if (token === "--origin") {
    base.origin = normalizeOrigin(requireStringFlag(next, "--origin"));
    return 1;
  }

  if (token === "--session-file") {
    base.sessionFile = path.resolve(cwd, requireStringFlag(next, "--session-file"));
    return 1;
  }

  return 0;
}

function requireStringFlag(rawValue: string | undefined, flag: string) {
  if (!rawValue) {
    throw new Error(`Missing value after ${flag}.`);
  }

  return rawValue;
}

function parsePositiveInteger(rawValue: string | undefined, flag: string) {
  const value = requireStringFlag(rawValue, flag);
  const parsed = Number.parseInt(value, 10);

  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`${flag} must be a positive integer.`);
  }

  return parsed;
}

export async function executePlatformCommand(
  command: PlatformCommand,
  fetchImpl: FetchLike = fetch,
): Promise<JsonObject> {
  switch (command.kind) {
    case "platform-auth-login":
      return login(command, fetchImpl);
    case "platform-auth-status":
      return readProfile(command, fetchImpl);
    case "platform-auth-logout":
      return logout(command, fetchImpl);
    case "platform-formation-status":
      return readFormation(command, fetchImpl);
    case "platform-billing-account":
      return readBillingAccount(command, fetchImpl);
    case "platform-billing-usage":
      return readBillingUsage(command, fetchImpl);
    case "platform-billing-setup":
      return startBillingSetup(command, fetchImpl);
    case "platform-billing-topup":
      return startBillingTopup(command, fetchImpl);
    case "platform-company-create":
      return createCompany(command, fetchImpl);
    case "platform-company-runtime":
      return readCompanyRuntime(command, fetchImpl);
    case "platform-sprite-pause":
      return pauseSprite(command, fetchImpl);
    case "platform-sprite-resume":
      return resumeSprite(command, fetchImpl);
  }
}

async function login(command: PlatformAuthLoginCommand, fetchImpl: FetchLike): Promise<JsonObject> {
  const origin = resolveExplicitOrigin(command.origin);
  const bootstrap = await bootstrapCsrf(origin, fetchImpl);
  const { data, session } = await requestJson({
    origin,
    path: "/api/auth/privy/session",
    method: "POST",
    fetchImpl,
    session: bootstrap,
    body: command.display_name ? { display_name: command.display_name } : {},
    authorization: `Bearer ${command.identityToken}`,
  });

  await saveSession(command.sessionFile, session);

  return {
    ok: true,
    command: "regent platform auth login",
    origin,
    sessionFile: command.sessionFile,
    profile: data,
  };
}

async function readProfile(
  command: PlatformAuthStatusCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command, false);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: "/api/auth/privy/profile",
    method: "GET",
    fetchImpl,
    session: resolved.session,
  });

  return {
    ok: true,
    command: "regent platform auth status",
    origin: resolved.origin,
    sessionFile: command.sessionFile,
    profile: data,
  };
}

async function logout(
  command: PlatformAuthLogoutCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command, false);

  await requestJson({
    origin: resolved.origin,
    path: "/api/auth/privy/session",
    method: "DELETE",
    fetchImpl,
    session: resolved.session,
  });

  await rm(command.sessionFile, { force: true });

  return {
    ok: true,
    command: "regent platform auth logout",
    origin: resolved.origin,
    sessionFile: command.sessionFile,
  };
}

async function readFormation(
  command: PlatformFormationStatusCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: "/api/agent-platform/formation",
    method: "GET",
    fetchImpl,
    session: resolved.session,
  });

  return {
    ok: true,
    command: "regent platform formation status",
    origin: resolved.origin,
    formation: data,
  };
}

async function readBillingAccount(
  command: PlatformBillingAccountCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: "/api/agent-platform/billing/account",
    method: "GET",
    fetchImpl,
    session: resolved.session,
  });

  return {
    ok: true,
    command: "regent platform billing account",
    origin: resolved.origin,
    billing: data,
  };
}

async function readBillingUsage(
  command: PlatformBillingUsageCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: "/api/agent-platform/billing/usage",
    method: "GET",
    fetchImpl,
    session: resolved.session,
  });

  return {
    ok: true,
    command: "regent platform billing usage",
    origin: resolved.origin,
    usage: data,
  };
}

async function startBillingSetup(
  command: PlatformBillingSetupCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const body = command.claimedLabel ? { claimedLabel: command.claimedLabel } : {};
  const { data } = await requestJson({
    origin: resolved.origin,
    path: "/api/agent-platform/billing/setup/checkout",
    method: "POST",
    fetchImpl,
    session: resolved.session,
    body,
  });

  return {
    ok: true,
    command: "regent platform billing setup",
    origin: resolved.origin,
    checkout: data,
  };
}

async function startBillingTopup(
  command: PlatformBillingTopupCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: "/api/agent-platform/billing/topups/checkout",
    method: "POST",
    fetchImpl,
    session: resolved.session,
    body: { amountUsdCents: command.amountUsdCents },
  });

  return {
    ok: true,
    command: "regent platform billing topup",
    origin: resolved.origin,
    checkout: data,
  };
}

async function createCompany(
  command: PlatformCompanyCreateCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: "/api/agent-platform/formation/companies",
    method: "POST",
    fetchImpl,
    session: resolved.session,
    body: { claimedLabel: command.claimedLabel },
  });

  return {
    ok: true,
    command: "regent platform company create",
    origin: resolved.origin,
    company: data,
  };
}

async function readCompanyRuntime(
  command: PlatformCompanyRuntimeCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: `/api/agent-platform/agents/${encodeURIComponent(command.slug)}/runtime`,
    method: "GET",
    fetchImpl,
    session: resolved.session,
  });

  return {
    ok: true,
    command: "regent platform company runtime",
    origin: resolved.origin,
    runtime: data,
  };
}

async function pauseSprite(
  command: PlatformSpritePauseCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: `/api/agent-platform/sprites/${encodeURIComponent(command.slug)}/pause`,
    method: "POST",
    fetchImpl,
    session: resolved.session,
    body: {},
  });

  return {
    ok: true,
    command: "regent platform sprite pause",
    origin: resolved.origin,
    sprite: data,
  };
}

async function resumeSprite(
  command: PlatformSpriteResumeCommand,
  fetchImpl: FetchLike,
): Promise<JsonObject> {
  const resolved = await loadResolvedSession(command);
  const { data } = await requestJson({
    origin: resolved.origin,
    path: `/api/agent-platform/sprites/${encodeURIComponent(command.slug)}/resume`,
    method: "POST",
    fetchImpl,
    session: resolved.session,
    body: {},
  });

  return {
    ok: true,
    command: "regent platform sprite resume",
    origin: resolved.origin,
    sprite: data,
  };
}

async function bootstrapCsrf(origin: string, fetchImpl: FetchLike): Promise<PlatformSessionState> {
  const response = await fetchImpl(`${origin}/api/auth/privy/csrf`, {
    headers: { accept: "application/json" },
  });

  const data = (await parseJsonResponse(response)) as JsonObject;

  if (!response.ok) {
    throw new Error(extractErrorMessage(data, response.status));
  }

  const csrfToken = typeof data.csrf_token === "string" ? data.csrf_token : null;
  const cookie = readCookieHeader(response);

  if (!csrfToken || !cookie) {
    throw new Error("Platform session bootstrap did not return a usable request-protection token.");
  }

  return {
    version: 1,
    origin,
    cookie,
    csrfToken,
    savedAt: new Date().toISOString(),
  };
}

async function requestJson({
  origin,
  path,
  method,
  fetchImpl,
  session,
  body,
  authorization,
}: {
  origin: string;
  path: string;
  method: "GET" | "POST" | "DELETE";
  fetchImpl: FetchLike;
  session: PlatformSessionState;
  body?: JsonObject;
  authorization?: string;
}) {
  const headers = new Headers({
    accept: "application/json",
    cookie: session.cookie,
  });

  if (authorization) {
    headers.set("authorization", authorization);
  }

  if (method !== "GET") {
    headers.set("content-type", "application/json");
    headers.set("x-csrf-token", session.csrfToken);
  }

  const response = await fetchImpl(`${origin}${path}`, {
    method,
    headers,
    body: method === "GET" ? undefined : JSON.stringify(body ?? {}),
  });

  const data = (await parseJsonResponse(response)) as JsonObject;

  if (!response.ok) {
    throw new Error(extractErrorMessage(data, response.status));
  }

  const updatedCookie = readCookieHeader(response) ?? session.cookie;

  return {
    data,
    session: {
      ...session,
      origin,
      cookie: updatedCookie,
      savedAt: new Date().toISOString(),
    } satisfies PlatformSessionState,
  };
}

async function loadResolvedSession(
  command: PlatformBaseCommand,
  allowOriginOverride = true,
): Promise<{ origin: string; session: PlatformSessionState }> {
  const session = await loadSession(command.sessionFile);
  const explicitOrigin = command.origin ? normalizeOrigin(command.origin) : null;

  if (explicitOrigin && session.origin !== explicitOrigin && !allowOriginOverride) {
    throw new Error(
      `Saved platform session belongs to ${session.origin}. Use a matching --origin or sign in again.`,
    );
  }

  if (explicitOrigin && session.origin !== explicitOrigin) {
    throw new Error(
      `Saved platform session belongs to ${session.origin}. Use a matching --origin or sign in again.`,
    );
  }

  return {
    origin: explicitOrigin ?? session.origin,
    session,
  };
}

async function loadSession(sessionFile: string): Promise<PlatformSessionState> {
  let raw: string;

  try {
    raw = await readFile(sessionFile, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      throw new Error(`No saved platform session found at ${sessionFile}. Run regent platform auth login first.`);
    }

    throw error;
  }

  let parsed: unknown;

  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`Saved platform session at ${sessionFile} is not valid JSON.`);
  }

  if (!isPlatformSessionState(parsed)) {
    throw new Error(`Saved platform session at ${sessionFile} is not usable.`);
  }

  return parsed;
}

async function saveSession(sessionFile: string, session: PlatformSessionState) {
  await mkdir(path.dirname(sessionFile), { recursive: true });
  await writeFile(sessionFile, `${JSON.stringify(session, null, 2)}\n`, "utf8");
}

function isPlatformSessionState(value: unknown): value is PlatformSessionState {
  if (!value || typeof value !== "object") {
    return false;
  }

  const session = value as Record<string, unknown>;

  return (
    session.version === 1 &&
    typeof session.origin === "string" &&
    typeof session.cookie === "string" &&
    typeof session.csrfToken === "string" &&
    typeof session.savedAt === "string"
  );
}

async function parseJsonResponse(response: Response): Promise<unknown> {
  const text = await response.text();

  if (text === "") {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`Platform returned a non-JSON response with status ${response.status}.`);
  }
}

function extractErrorMessage(data: JsonObject, status: number) {
  if (typeof data.error === "string" && data.error !== "") {
    return data.error;
  }

  if (typeof data.message === "string" && data.message !== "") {
    return data.message;
  }

  return `Platform request failed with status ${status}.`;
}

function readCookieHeader(response: Response) {
  const maybeHeaders = response.headers as Headers & {
    getSetCookie?: () => string[];
  };

  const setCookie =
    (typeof maybeHeaders.getSetCookie === "function" ? maybeHeaders.getSetCookie()[0] : null) ??
    response.headers.get("set-cookie");

  if (!setCookie) {
    return null;
  }

  const [cookie] = setCookie.split(";", 1);
  return cookie?.trim() || null;
}

function resolveExplicitOrigin(origin: string | null) {
  return normalizeOrigin(origin ?? process.env.REGENT_PLATFORM_ORIGIN ?? DEFAULT_ORIGIN);
}

function normalizeOrigin(origin: string) {
  return origin.replace(/\/+$/u, "");
}
