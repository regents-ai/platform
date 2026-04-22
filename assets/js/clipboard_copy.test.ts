import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { JSDOM } from "jsdom";

import { mountClipboardCopy } from "./clipboard_copy.ts";

function flushPromises(): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, 0);
  });
}

describe("mountClipboardCopy", () => {
  it("copies the current button text and tears down cleanly", async () => {
    const dom = new JSDOM(
      `<button type="button" data-copy-text="first" data-copied="false">Copy</button>`,
    );
    const button = dom.window.document.querySelector("button");
    assert.ok(button);

    const copied: string[] = [];
    const timeouts: Array<() => void> = [];
    let timeoutId = 0;

    const cleanup = mountClipboardCopy(button, {
      navigator: {
        clipboard: {
          writeText(text: string) {
            copied.push(text);
            return Promise.resolve();
          },
        },
      } as Navigator,
      setTimeout: ((callback: TimerHandler) => {
        timeoutId += 1;
        timeouts.push(callback as () => void);
        return timeoutId;
      }) as typeof window.setTimeout,
      clearTimeout() {
        return undefined;
      },
    });

    button.dataset.copyText = "second";
    button.click();
    await flushPromises();

    assert.deepEqual(copied, ["second"]);
    assert.equal(button.dataset.copied, "true");

    timeouts[0]?.();
    assert.equal(button.dataset.copied, "false");

    cleanup();
    button.dataset.copyText = "third";
    button.click();
    await flushPromises();

    assert.deepEqual(copied, ["second"]);
  });
});
