import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { mountBoundHook } from "./hook_lifecycle.ts";

describe("mountBoundHook", () => {
  it("runs the previous cleanup before rebinding the hook", () => {
    const cleanupCalls: string[] = [];
    const bindings: string[] = [];
    const context = {
      el: {} as HTMLElement,
      __dashboardCleanup: undefined as (() => void) | undefined,
    };

    const binder = (_el: HTMLElement) => {
      const label = `binding-${bindings.length + 1}`;
      bindings.push(label);

      return () => {
        cleanupCalls.push(label);
      };
    };

    mountBoundHook(context, binder);
    assert.deepEqual(bindings, ["binding-1"]);
    assert.deepEqual(cleanupCalls, []);

    mountBoundHook(context, binder);
    assert.deepEqual(bindings, ["binding-1", "binding-2"]);
    assert.deepEqual(cleanupCalls, ["binding-1"]);

    context.__dashboardCleanup?.();
    assert.deepEqual(cleanupCalls, ["binding-1", "binding-2"]);
  });
});
