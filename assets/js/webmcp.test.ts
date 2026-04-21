import assert from "node:assert/strict";
import test from "node:test";

import { registerWebMCP } from "./webmcp.ts";

test("registerWebMCP publishes read-only navigation tools when the browser exposes modelContext", () => {
  const contexts: Array<{ tools: Array<{ name: string; execute: (input?: { openInNewTab?: boolean }) => { ok: true; url: string } }> }> = [];
  const assignedUrls: string[] = [];
  const openedUrls: string[] = [];

  const targetWindow = {
    __regentsWebMcpRegistered: false,
    navigator: {
      modelContext: {
        provideContext(context: { tools: Array<{ name: string; execute: (input?: { openInNewTab?: boolean }) => { ok: true; url: string } }> }) {
          contexts.push(context);
        },
      },
    },
    location: {
      origin: "https://regents.sh",
      assign(url: string) {
        assignedUrls.push(url);
      },
    },
    open(url: string) {
      openedUrls.push(url);
      return null;
    },
  } as unknown as Window & typeof globalThis;

  registerWebMCP(targetWindow);
  registerWebMCP(targetWindow);

  assert.equal(contexts.length, 1);
  assert.equal(contexts[0]?.tools.length, 5);

  const cliTool = contexts[0]?.tools.find((tool) => tool.name === "open_regents_cli");
  const docsTool = contexts[0]?.tools.find((tool) => tool.name === "open_regents_docs");
  assert.ok(cliTool);
  assert.ok(docsTool);
  assert.deepEqual(cliTool.execute(), { ok: true, url: "https://regents.sh/cli" });
  assert.deepEqual(docsTool.execute(), { ok: true, url: "https://regents.sh/docs" });
  assert.deepEqual(cliTool.execute({ openInNewTab: true }), {
    ok: true,
    url: "https://regents.sh/cli",
  });

  assert.deepEqual(assignedUrls, ["https://regents.sh/cli", "https://regents.sh/docs"]);
  assert.deepEqual(openedUrls, ["https://regents.sh/cli"]);
});

test("registerWebMCP does nothing when the browser does not expose modelContext", () => {
  const targetWindow = {
    navigator: {},
    location: {
      origin: "https://regents.sh",
      assign() {
        throw new Error("assign should not be called");
      },
    },
    open() {
      throw new Error("open should not be called");
    },
  } as unknown as Window & typeof globalThis;

  assert.doesNotThrow(() => registerWebMCP(targetWindow));
});
