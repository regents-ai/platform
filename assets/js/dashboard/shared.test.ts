import assert from "node:assert/strict";
import { after, afterEach, describe, it } from "node:test";

import { fetchJson, HttpRequestError } from "./shared.ts";

const originalDocument = globalThis.document;
const originalFetch = globalThis.fetch;

globalThis.document = {
  querySelector() {
    return null;
  },
} as unknown as Document;

afterEach(() => {
  globalThis.fetch = originalFetch;
});

after(() => {
  globalThis.document = originalDocument;
  globalThis.fetch = originalFetch;
});

describe("fetchJson", () => {
  it("uses the product error message from failed API responses", async () => {
    globalThis.fetch = async () =>
      new Response(
        JSON.stringify({
          error: {
            message: "Choose a supported value",
          },
        }),
        { status: 400, headers: { "content-type": "application/json" } },
      );

    await assert.rejects(
      fetchJson("/api/test"),
      (error) =>
        error instanceof HttpRequestError &&
        error.status === 400 &&
        error.message === "Choose a supported value",
    );
  });
});
