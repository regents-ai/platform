import assert from "node:assert/strict";
import { access, mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { executeRegentCommand, parseRegentCommand, usageText } from "./regents_cli.ts";
import {
  executePlatformCommand,
  type PlatformCommand,
} from "./platform_cli.ts";

test("usage text mentions shader and platform commands", () => {
  const help = usageText();
  assert.match(help, /regent shader list/);
  assert.match(help, /regent shader export/);
  assert.match(help, /regent platform auth login/);
  assert.match(help, /regent platform company create/);
});

test("shader list command still parses usage filter", () => {
  const command = parseRegentCommand(["shader", "list", "--usage", "avatar"], "/tmp/regents-cli");
  assert.deepEqual(command, {
    kind: "shader-list",
    usage: "avatar",
  });
});

test("platform auth login can read the identity token from the default environment variable", () => {
  const previousToken = process.env.REGENT_PLATFORM_IDENTITY_TOKEN;
  process.env.REGENT_PLATFORM_IDENTITY_TOKEN = "env-token";

  try {
    const command = parseRegentCommand(
      [
        "platform",
        "auth",
        "login",
        "--display-name",
        "Regent Operator",
        "--session-file",
        "./platform-session.json",
      ],
      "/tmp/regents-cli",
    );

    assert.equal(command.kind, "platform-auth-login");
    if (command.kind !== "platform-auth-login") return;

    assert.equal(command.identityToken, "env-token");
    assert.equal(command.display_name, "Regent Operator");
    assert.equal(command.sessionFile, "/tmp/regents-cli/platform-session.json");
  } finally {
    if (previousToken === undefined) {
      delete process.env.REGENT_PLATFORM_IDENTITY_TOKEN;
    } else {
      process.env.REGENT_PLATFORM_IDENTITY_TOKEN = previousToken;
    }
  }
});

test("platform CLI signs in, reuses the saved session, performs a write action, and logs out", async (t) => {
  const tempDir = await mkdtemp(path.join(os.tmpdir(), "regents-cli-"));
  const sessionFile = path.join(tempDir, "platform-session.json");
  const requests: Array<{ method: string; url: string; cookie: string | null; csrf: string | null; body: string }> = [];
  const origin = "http://127.0.0.1:40111";

  t.after(async () => {
    await rm(tempDir, { recursive: true, force: true });
  });

  const fetchImpl: typeof fetch = async (input, init) => {
    const requestUrl = new URL(
      typeof input === "string"
        ? input
        : input instanceof URL
          ? input.toString()
          : input.url,
    );
    const method = init?.method ?? "GET";
    const headers = new Headers(init?.headers);
    const body = typeof init?.body === "string" ? init.body : "";

    requests.push({
      method,
      url: requestUrl.pathname,
      cookie: headers.get("cookie"),
      csrf: headers.get("x-csrf-token"),
      body,
    });

    if (method === "GET" && requestUrl.pathname === "/api/auth/privy/csrf") {
      return jsonResponse(
        200,
        { ok: true, csrf_token: "csrf-123" },
        { "set-cookie": "_platform_phx_key=bootstrap; path=/; HttpOnly" },
      );
    }

    if (method === "POST" && requestUrl.pathname === "/api/auth/privy/session") {
      assert.equal(headers.get("authorization"), "Bearer good-token");
      assert.equal(headers.get("cookie"), "_platform_phx_key=bootstrap");
      assert.equal(headers.get("x-csrf-token"), "csrf-123");
      assert.deepEqual(JSON.parse(body), { display_name: "Regent Operator" });

      return jsonResponse(
        200,
        {
          ok: true,
          authenticated: true,
          human: {
            id: 7,
            privy_user_id: "did:privy:test-user",
            wallet_address: "0x1111111111111111111111111111111111111111",
            wallet_addresses: ["0x1111111111111111111111111111111111111111"],
            display_name: "Regent Operator",
            billing_account: {
              status: "active",
              connected: true,
              provider: "stripe",
              customer_id: "cus_test",
              subscription_id: "sub_test",
              model_default: "glm-5.1",
              margin_bps: 0,
              runtime_credit_balance_usd_cents: 500,
              paid_companies: 0,
              paused_companies: 0,
              trialing_companies: 0,
              welcome_credit: null,
            },
          },
          claimed_names: [],
          agents: [],
        },
        { "set-cookie": "_platform_phx_key=signed-in; path=/; HttpOnly" },
      );
    }

    if (method === "GET" && requestUrl.pathname === "/api/auth/privy/profile") {
      assert.equal(headers.get("cookie"), "_platform_phx_key=signed-in");

      return jsonResponse(
        200,
        {
          ok: true,
          authenticated: true,
          human: {
            id: 7,
            privy_user_id: "did:privy:test-user",
            wallet_address: "0x1111111111111111111111111111111111111111",
            wallet_addresses: ["0x1111111111111111111111111111111111111111"],
            display_name: "Regent Operator",
            billing_account: {
              status: "active",
              connected: true,
              provider: "stripe",
              customer_id: "cus_test",
              subscription_id: "sub_test",
              model_default: "glm-5.1",
              margin_bps: 0,
              runtime_credit_balance_usd_cents: 500,
              paid_companies: 0,
              paused_companies: 0,
              trialing_companies: 0,
              welcome_credit: null,
            },
          },
          claimed_names: [],
          agents: [],
        },
      );
    }

    if (method === "POST" && requestUrl.pathname === "/api/agent-platform/formation/companies") {
      assert.equal(headers.get("cookie"), "_platform_phx_key=signed-in");
      assert.equal(headers.get("x-csrf-token"), "csrf-123");
      assert.deepEqual(JSON.parse(body), { claimedLabel: "startline" });

      return jsonResponse(
        202,
        {
          ok: true,
          agent: { slug: "startline", status: "forming" },
          formation: { id: 11, status: "queued", current_step: "reserve_claim", attempt_count: 0 },
        },
      );
    }

    if (method === "DELETE" && requestUrl.pathname === "/api/auth/privy/session") {
      assert.equal(headers.get("cookie"), "_platform_phx_key=signed-in");
      assert.equal(headers.get("x-csrf-token"), "csrf-123");

      return jsonResponse(200, { ok: true });
    }

    return jsonResponse(404, { error: `Unexpected route ${method} ${requestUrl.pathname}` });
  };

  const login = await executeParsedPlatformCommand(
    [
      "platform",
      "auth",
      "login",
      "--origin",
      origin,
      "--identity-token",
      "good-token",
      "--display-name",
      "Regent Operator",
      "--session-file",
      "./platform-session.json",
    ],
    tempDir,
    fetchImpl,
  ) as {
    ok: boolean;
    command: string;
    origin: string;
  };

  assert.equal(login.ok, true);
  assert.equal(login.command, "regent platform auth login");
  assert.equal(login.origin, origin);

  const savedSession = JSON.parse(await readFile(sessionFile, "utf8"));
  assert.equal(savedSession.origin, origin);
  assert.equal(savedSession.cookie, "_platform_phx_key=signed-in");
  assert.equal(savedSession.csrfToken, "csrf-123");

  const status = await executeParsedPlatformCommand(
    ["platform", "auth", "status", "--session-file", "./platform-session.json"],
    tempDir,
    fetchImpl,
  ) as {
    ok: boolean;
    command: string;
    origin: string;
    profile: { authenticated: boolean };
  };

  assert.equal(status.ok, true);
  assert.equal(status.command, "regent platform auth status");
  assert.equal(status.origin, origin);
  assert.equal(status.profile.authenticated, true);

  const company = await executeParsedPlatformCommand(
    [
      "platform",
      "company",
      "create",
      "--claimed-label",
      "startline",
      "--session-file",
      "./platform-session.json",
    ],
    tempDir,
    fetchImpl,
  ) as {
    ok: boolean;
    command: string;
    company: { agent: { slug: string } };
  };

  assert.equal(company.ok, true);
  assert.equal(company.command, "regent platform company create");
  assert.equal(company.company.agent.slug, "startline");

  const logout = await executeParsedPlatformCommand(
    ["platform", "auth", "logout", "--session-file", "./platform-session.json"],
    tempDir,
    fetchImpl,
  );

  assert.equal(logout.ok, true);
  assert.equal(logout.command, "regent platform auth logout");
  await assert.rejects(() => access(sessionFile));

  assert.deepEqual(
    requests.map((request) => `${request.method} ${request.url}`),
    [
      "GET /api/auth/privy/csrf",
      "POST /api/auth/privy/session",
      "GET /api/auth/privy/profile",
      "POST /api/agent-platform/formation/companies",
      "DELETE /api/auth/privy/session",
    ],
  );
});

async function executeParsedPlatformCommand(
  argv: readonly string[],
  cwd: string,
  fetchImpl: typeof fetch,
) {
  const command = parseRegentCommand(argv, cwd);

  assert.notEqual(command.kind, "help");
  assert.match(command.kind, /^platform-/);

  return executePlatformCommand(command as PlatformCommand, fetchImpl);
}

function jsonResponse(
  status: number,
  payload: unknown,
  extraHeaders: Record<string, string> = {},
) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "content-type": "application/json",
      ...extraHeaders,
    },
  });
}
