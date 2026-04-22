import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { createCleanupHook, type CleanupHookContext } from "./hook_cleanup.ts";

describe("createCleanupHook", () => {
  it("runs cleanup before remounting and when destroyed", () => {
    const calls: string[] = [];
    const hook = createCleanupHook("__exampleCleanup", () => {
      calls.push("mount");

      return () => {
        calls.push("cleanup");
      };
    });

    const context: CleanupHookContext<"__exampleCleanup"> = {
      el: {} as HTMLElement,
      __exampleCleanup: undefined,
    };

    hook.mounted?.call(context as any);
    assert.deepEqual(calls, ["mount"]);

    hook.updated?.call(context as any);
    assert.deepEqual(calls, ["mount", "cleanup", "mount"]);

    hook.destroyed?.call(context as any);
    assert.deepEqual(calls, ["mount", "cleanup", "mount", "cleanup"]);
    assert.equal(context.__exampleCleanup, undefined);
  });
});
