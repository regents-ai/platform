import type { Hook } from "phoenix_live_view";

type CleanupFn = () => void;
type CleanupKey = `__${string}Cleanup`;

export type CleanupHookContext<K extends CleanupKey> = {
  el: Element;
} & Record<K, CleanupFn | undefined>;

export function remountCleanup<K extends CleanupKey>(
  context: CleanupHookContext<K>,
  key: K,
  mount: (root: HTMLElement) => CleanupFn,
): void {
  const cleanup = context[key] as CleanupFn | undefined;
  cleanup?.();

  (context as Record<string, CleanupFn | undefined>)[key] = mount(
    context.el as HTMLElement,
  );
}

export function destroyCleanup<K extends CleanupKey>(
  context: CleanupHookContext<K>,
  key: K,
): void {
  const cleanup = context[key] as CleanupFn | undefined;
  cleanup?.();

  (context as Record<string, CleanupFn | undefined>)[key] = undefined;
}

export function createCleanupHook<K extends CleanupKey>(
  key: K,
  mount: (root: HTMLElement) => CleanupFn,
): Hook {
  return {
    mounted() {
      remountCleanup(this as CleanupHookContext<K>, key, mount);
    },
    updated() {
      remountCleanup(this as CleanupHookContext<K>, key, mount);
    },
    destroyed() {
      destroyCleanup(this as CleanupHookContext<K>, key);
    },
  };
}
