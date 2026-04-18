export type BoundHookContext = {
  el: Element;
  __dashboardCleanup?: () => void;
};

export function mountBoundHook(
  context: BoundHookContext,
  binder: (el: HTMLElement) => () => void,
): void {
  context.__dashboardCleanup?.();
  context.__dashboardCleanup = binder(context.el as HTMLElement);
}
