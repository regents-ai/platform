import "phoenix_html";
import { animate } from "animejs";
import { Socket } from "phoenix";
import { LiveSocket, type HooksOptions } from "phoenix_live_view";
import { Heerich } from "heerich";
import topbar from "../vendor/topbar.cjs";
import { mountBoundHook } from "./dashboard/hook_lifecycle";
import { DashboardXmtpRoomHook } from "./dashboard/xmtp_room";
import { TokenStakingHook } from "./token_staking";
import { mountClipboardCopy } from "./clipboard_copy";
import { createCleanupHook } from "./hook_cleanup";
import {
  hooks as regentHooks,
  installHeerich,
} from "../regent/js/regent";
import {
  mountBridgeReveal,
  mountDashboardReveal,
  mountDemoReveal,
  mountHomeReveal,
  revertAnimation,
} from "./animations";
import { FooterVoxelHook } from "./footer_voxel";
import { HomeRegentScene } from "./home_regent_scene";
import { mountDemo2Tunnel } from "./demo2";
import { mountProceduralHeerichDemo } from "./heerich_demo";
import { AnimatedHomeLogoSceneHook } from "./home_logo_scene";
import { LogoStudiesHook } from "./logos";
import { mountOverviewMode } from "./overview";
import { mountColorModeToggle } from "./color_mode";
import { VoxelBackgroundHook } from "./voxel_background";
import { registerWebMCP } from "./webmcp";

let dashboardIslandsPromise: Promise<typeof import("./dashboard/islands")> | undefined;
let shaderRootPromise: Promise<typeof import("./shader/root")> | undefined;
let tokenCardRootPromise: Promise<typeof import("./shader/token_card_root")> | undefined;
let agentbookTrustFlowPromise: Promise<typeof import("./agentbook_trust_flow")> | undefined;

function loadDashboardIslands() {
  dashboardIslandsPromise ??= import("./dashboard/islands");
  return dashboardIslandsPromise;
}

function loadShaderRoot() {
  shaderRootPromise ??= import("./shader/root");
  return shaderRootPromise;
}

function loadTokenCardRoot() {
  tokenCardRootPromise ??= import("./shader/token_card_root");
  return tokenCardRootPromise;
}

function loadAgentbookTrustFlow() {
  agentbookTrustFlowPromise ??= import("./agentbook_trust_flow");
  return agentbookTrustFlowPromise;
}

type HookContext = {
  el: Element;
  __regentAnimation?: ReturnType<typeof mountHomeReveal>;
  __dashboardCleanup?: () => void;
  __launchProgressCleanup?: () => void;
};

function resetReveal(context: HookContext): void {
  revertAnimation(context.__regentAnimation);
  context.__regentAnimation = undefined;
}

function createRevealHook(
  mountReveal: (root: HTMLElement) => ReturnType<typeof mountHomeReveal>,
) {
  return {
    mounted(this: HookContext) {
      resetReveal(this);
      this.__regentAnimation = mountReveal(this.el as HTMLElement);
    },
    destroyed(this: HookContext) {
      resetReveal(this);
    },
  };
}

const DashboardPrivyBridgeHook = {
  mounted(this: HookContext) {
    void loadDashboardIslands().then(({ mountDashboardPrivyBridge }) => {
      if (this.el.isConnected) mountDashboardPrivyBridge(this.el);
    });
  },
  destroyed(this: HookContext) {
    void loadDashboardIslands().then(({ unmountDashboardPrivyBridge }) => {
      unmountDashboardPrivyBridge(this.el);
    });
  },
};

const DashboardWalletHook = {
  mounted(this: HookContext) {
    void loadDashboardIslands().then(({ bindDashboardWallet }) => {
      if (this.el.isConnected) mountBoundHook(this, bindDashboardWallet);
    });
  },
  updated(this: HookContext) {
    void loadDashboardIslands().then(({ bindDashboardWallet }) => {
      if (this.el.isConnected) mountBoundHook(this, bindDashboardWallet);
    });
  },
  destroyed(this: HookContext) {
    this.__dashboardCleanup?.();
  },
};

const DashboardNameClaimHook = {
  mounted(this: HookContext) {
    void loadDashboardIslands().then(({ bindDashboardNameClaim }) => {
      if (this.el.isConnected) mountBoundHook(this, bindDashboardNameClaim);
    });
  },
  updated(this: HookContext) {
    void loadDashboardIslands().then(({ bindDashboardNameClaim }) => {
      if (this.el.isConnected) mountBoundHook(this, bindDashboardNameClaim);
    });
  },
  destroyed(this: HookContext) {
    this.__dashboardCleanup?.();
  },
};

const DashboardRedeemHook = {
  mounted(this: HookContext) {
    void loadDashboardIslands().then(({ bindDashboardRedeem }) => {
      if (this.el.isConnected) mountBoundHook(this, bindDashboardRedeem);
    });
  },
  updated(this: HookContext) {
    void loadDashboardIslands().then(({ bindDashboardRedeem }) => {
      if (this.el.isConnected) mountBoundHook(this, bindDashboardRedeem);
    });
  },
  destroyed(this: HookContext) {
    this.__dashboardCleanup?.();
  },
};

function mountLaunchProgress(root: HTMLElement): () => void {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return () => undefined;
  }

  const targets = Array.from(
    root.querySelectorAll<HTMLElement>(".pp-launch-progress-card, .pp-launch-progress-copy"),
  );

  if (targets.length === 0) {
    return () => undefined;
  }

  animate(targets, {
    opacity: [{ from: 0, to: 1 }],
    translateY: [{ from: 18, to: 0 }],
    delay: (_, index) => index * 70,
    duration: 520,
    ease: "outExpo",
  });

  return () => {
    targets.forEach((target) => {
      target.style.opacity = "";
      target.style.transform = "";
    });
  };
}

const LaunchProgressHook = {
  ...createCleanupHook("__launchProgressCleanup", mountLaunchProgress),
} satisfies HooksOptions[string];

const ShaderRootHook = {
  mounted(this: HookContext) {
    void loadShaderRoot().then(({ mountShaderRoot }) => {
      if (this.el.isConnected) mountShaderRoot(this.el);
    });
  },
  updated(this: HookContext) {
    void loadShaderRoot().then(({ mountShaderRoot }) => {
      if (this.el.isConnected) mountShaderRoot(this.el);
    });
  },
  destroyed(this: HookContext) {
    void loadShaderRoot().then(({ unmountShaderRoot }) => {
      unmountShaderRoot(this.el);
    });
  },
};
const HomeRevealHook = createRevealHook(mountHomeReveal);
const BridgeRevealHook = createRevealHook(mountBridgeReveal);
const DashboardRevealHook = createRevealHook(mountDashboardReveal);
const BugReportRevealHook = createRevealHook(mountBridgeReveal);
const DemoRevealHook = createRevealHook(mountDemoReveal);
const HeerichProceduralDemoHook = {
  mounted(this: HookContext) {
    mountProceduralHeerichDemo(this.el as HTMLElement);
  },
  updated(this: HookContext) {
    mountProceduralHeerichDemo(this.el as HTMLElement);
  },
};
const Demo2TunnelHook = {
  ...createCleanupHook("__demo2Cleanup", mountDemo2Tunnel),
} satisfies HooksOptions[string];
const ClipboardCopyHook = {
  ...createCleanupHook("__clipboardCopyCleanup", (root) =>
    mountClipboardCopy(root as HTMLButtonElement),
  ),
} satisfies HooksOptions[string];

type QuickSearchItem = {
  href: string;
  label: string;
};

type QuickSearchState = {
  activeIndex: number;
  cleanup: Array<() => void>;
  items: QuickSearchItem[];
  visibleItems: QuickSearchItem[];
};

function normalizeQuickSearchValue(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9/ ]+/g, " ")
    .replace(/\s+/g, " ");
}

function resolveQuickSearchTarget(
  value: string,
  items: QuickSearchItem[],
  fallback: string,
): string {
  const normalizedValue = normalizeQuickSearchValue(value);

  if (!normalizedValue) {
    return fallback;
  }

  const exactMatch = items.find((item) => {
    const normalizedLabel = normalizeQuickSearchValue(item.label);
    const normalizedHref = normalizeQuickSearchValue(item.href);

    return (
      normalizedValue === normalizedLabel ||
      normalizedValue === normalizedHref ||
      normalizedValue === normalizedLabel.replace(/\bpage\b/g, "").trim()
    );
  });

  if (exactMatch) {
    return exactMatch.href;
  }

  const fuzzyMatch = items.find((item) => {
    const normalizedLabel = normalizeQuickSearchValue(item.label);
    return (
      normalizedLabel.includes(normalizedValue) ||
      normalizedValue.includes(normalizedLabel)
    );
  });

  return fuzzyMatch?.href ?? fallback;
}

function quickSearchMatches(value: string, items: QuickSearchItem[]): QuickSearchItem[] {
  const normalizedValue = normalizeQuickSearchValue(value);

  if (!normalizedValue) return items.slice(0, 6);

  return items
    .map((item) => {
      const label = normalizeQuickSearchValue(item.label);
      const href = normalizeQuickSearchValue(item.href);
      const exact = label === normalizedValue || href === normalizedValue ? 0 : 1;
      const starts = label.startsWith(normalizedValue) ? 0 : 1;
      const contains = label.includes(normalizedValue) || href.includes(normalizedValue) ? 0 : 1;

      return { item, score: exact + starts + contains };
    })
    .filter(({ score }) => score < 3)
    .sort((left, right) => left.score - right.score)
    .map(({ item }) => item)
    .slice(0, 6);
}

function quickSearchNavigate(form: HTMLFormElement, href: string): void {
  form.ownerDocument.defaultView?.location.assign(href);
}

function renderQuickSearchResults(
  form: HTMLFormElement,
  resultsRoot: HTMLElement,
  state: QuickSearchState,
): void {
  resultsRoot.replaceChildren();

  state.visibleItems.forEach((item, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.dataset.quickSearchResult = item.href;
    button.dataset.active = String(index === state.activeIndex);
    button.className =
      "flex w-full items-center gap-3 rounded-[0.85rem] px-3 py-2.5 text-left text-sm transition duration-150 data-[active=true]:bg-[color:color-mix(in_oklch,var(--brand-ink)_10%,var(--background)_90%)] data-[active=true]:text-[color:var(--foreground)] text-[color:var(--muted-foreground)] hover:bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] hover:text-[color:var(--foreground)]";

    const icon = document.createElement("span");
    icon.className =
      "flex h-8 w-8 shrink-0 items-center justify-center rounded-[0.7rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)]";
    icon.textContent = ">";

    const label = document.createElement("span");
    label.className = "min-w-0 flex-1";

    const title = document.createElement("span");
    title.className = "block truncate text-[color:var(--foreground)]";
    title.textContent = item.label;

    const href = document.createElement("span");
    href.className =
      "mt-0.5 block truncate text-[0.72rem] text-[color:color-mix(in_oklch,var(--foreground)_48%,var(--muted-foreground)_52%)]";
    href.textContent = item.href;

    label.append(title, href);
    button.append(icon, label);
    button.addEventListener("mousedown", (event) => event.preventDefault());
    button.addEventListener("click", () => quickSearchNavigate(form, item.href));
    resultsRoot.append(button);
  });
}

function showQuickSearchPanel(panel: HTMLElement): void {
  if (!panel.hidden) return;

  panel.hidden = false;
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  animate(panel, {
    opacity: [0, 1],
    translateY: [-6, 0],
    duration: 180,
    ease: "outQuart",
  });
}

const QuickSearchHook = {
  mounted(
    this: HookContext & {
      __quickSearchState?: QuickSearchState;
      __quickSearchSubmit?: (event: Event) => void;
    },
  ) {
    const form = this.el as HTMLFormElement;
    const input = form.querySelector<HTMLInputElement>("input[name='search']");
    const panel = form.querySelector<HTMLElement>("[data-quick-search-panel]");
    const resultsRoot = form.querySelector<HTMLElement>("[data-quick-search-results]");
    const fallback = form.dataset.searchDefault ?? "/docs";
    const items = JSON.parse(form.dataset.searchItems ?? "[]") as QuickSearchItem[];
    const state: QuickSearchState = {
      activeIndex: 0,
      cleanup: [],
      items,
      visibleItems: quickSearchMatches("", items),
    };
    this.__quickSearchState = state;

    const sync = () => {
      if (!panel || !resultsRoot) return;
      state.visibleItems = quickSearchMatches(input?.value ?? "", state.items);
      state.activeIndex = Math.min(state.activeIndex, Math.max(state.visibleItems.length - 1, 0));
      renderQuickSearchResults(form, resultsRoot, state);
      showQuickSearchPanel(panel);
    };

    const close = () => {
      if (panel) panel.hidden = true;
    };

    this.__quickSearchSubmit = (event: Event) => {
      event.preventDefault();

      const target = state.visibleItems[state.activeIndex]?.href ??
        resolveQuickSearchTarget(input?.value ?? "", items, fallback);
      quickSearchNavigate(form, target);
    };

    const onInput = () => {
      state.activeIndex = 0;
      sync();
    };

    const onFocus = () => sync();

    const onKeydown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        close();
        input?.blur();
        return;
      }

      if (event.key === "ArrowDown") {
        event.preventDefault();
        state.activeIndex = Math.min(state.activeIndex + 1, state.visibleItems.length - 1);
        sync();
        return;
      }

      if (event.key === "ArrowUp") {
        event.preventDefault();
        state.activeIndex = Math.max(state.activeIndex - 1, 0);
        sync();
      }
    };

    const onDocumentKeydown = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        input?.focus();
        input?.select();
        sync();
      }
    };

    const onDocumentPointerDown = (event: PointerEvent) => {
      if (!form.contains(event.target as Node)) close();
    };

    form.addEventListener("submit", this.__quickSearchSubmit);
    input?.addEventListener("input", onInput);
    input?.addEventListener("focus", onFocus);
    input?.addEventListener("keydown", onKeydown);
    document.addEventListener("keydown", onDocumentKeydown);
    document.addEventListener("pointerdown", onDocumentPointerDown);

    state.cleanup.push(
      () => input?.removeEventListener("input", onInput),
      () => input?.removeEventListener("focus", onFocus),
      () => input?.removeEventListener("keydown", onKeydown),
      () => document.removeEventListener("keydown", onDocumentKeydown),
      () => document.removeEventListener("pointerdown", onDocumentPointerDown),
    );
  },
  destroyed(
    this: HookContext & {
      __quickSearchState?: QuickSearchState;
      __quickSearchSubmit?: (event: Event) => void;
    },
  ) {
    if (this.__quickSearchSubmit) {
      (this.el as HTMLFormElement).removeEventListener("submit", this.__quickSearchSubmit);
    }
    this.__quickSearchState?.cleanup.forEach((cleanup) => cleanup());
  },
};

function bugReportMotionReduced(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

const COLLAPSIBLE_CLOSE_MS = 240;

function openCollapsiblePanel(panel: HTMLDivElement): void {
  panel.hidden = false;
  panel.dataset.panelState = "closed";

  requestAnimationFrame(() => {
    panel.dataset.panelState = "open";
  });
}

function closeCollapsiblePanel(
  panel: HTMLDivElement,
  motionReduced: boolean,
  closeTimer?: number,
): number | undefined {
  if (closeTimer) window.clearTimeout(closeTimer);

  panel.dataset.panelState = "closed";

  if (motionReduced) {
    panel.hidden = true;
    return undefined;
  }

  return window.setTimeout(() => {
    if (panel.dataset.panelState === "closed") {
      panel.hidden = true;
    }
  }, COLLAPSIBLE_CLOSE_MS);
}

function setDisclosureButtonState(
  button: HTMLButtonElement,
  expanded: boolean,
  collapsedLabel = "Show details",
  expandedLabel = "Hide details",
): void {
  button.setAttribute("aria-expanded", expanded ? "true" : "false");
  const [label, icon] = button.querySelectorAll("span");
  if (label) label.textContent = expanded ? expandedLabel : collapsedLabel;
  if (icon) icon.textContent = expanded ? "↑" : "↓";
}

function mountDisclosurePanels(
  root: HTMLElement,
  selector: string,
  collapsedLabel = "Show details",
  expandedLabel = "Hide details",
): () => void {
  const cleanups: Array<() => void> = [];

  root.querySelectorAll<HTMLButtonElement>(selector).forEach((button) => {
    const panelId = button.dataset.targetId;
    if (!panelId) return;

    const panel = document.getElementById(panelId) as HTMLDivElement | null;
    if (!panel) return;

    setDisclosureButtonState(button, false, collapsedLabel, expandedLabel);
    panel.dataset.panelState = "closed";
    panel.hidden = true;
    let closeTimer: number | undefined;

    const toggle = () => {
      const expanded = button.getAttribute("aria-expanded") === "true";

      if (expanded) {
        setDisclosureButtonState(button, false, collapsedLabel, expandedLabel);
        closeTimer = closeCollapsiblePanel(panel, bugReportMotionReduced(), closeTimer);

        return;
      }

      setDisclosureButtonState(button, true, collapsedLabel, expandedLabel);
      if (closeTimer) {
        window.clearTimeout(closeTimer);
        closeTimer = undefined;
      }

      if (bugReportMotionReduced()) {
        panel.hidden = false;
        panel.dataset.panelState = "open";
        return;
      }

      openCollapsiblePanel(panel);
    };

    button.addEventListener("click", toggle);
    cleanups.push(() => button.removeEventListener("click", toggle));
  });

  return () => cleanups.forEach((cleanup) => cleanup());
}

function mountBugReportLedger(root: HTMLElement, pushEvent?: (event: string, payload: object) => void): () => void {
  const disclosureCleanup = mountDisclosurePanels(root, "[data-bug-report-toggle]");
  const sentinel = root.querySelector<HTMLElement>("[data-bug-report-sentinel]");

  if (!sentinel || typeof pushEvent !== "function") return disclosureCleanup;

  let loadLocked = false;
  const observer = new IntersectionObserver(
    (entries) => {
      const isVisible = entries.some((entry) => entry.isIntersecting);
      if (!isVisible || loadLocked) return;
      loadLocked = true;
      pushEvent("load-more", {});
      window.setTimeout(() => {
        loadLocked = false;
      }, 250);
    },
    {
      rootMargin: "0px 0px 320px 0px",
      threshold: 0.05,
    },
  );

  observer.observe(sentinel);

  return () => {
    observer.disconnect();
    disclosureCleanup();
  };
}

const BugReportLedgerHook = {
  mounted(this: HookContext & { __bugReportCleanup?: () => void; pushEvent?: (event: string, payload: object) => void }) {
    this.__bugReportCleanup = mountBugReportLedger(
      this.el as HTMLElement,
      this.pushEvent?.bind(this),
    );
  },
  updated(this: HookContext & { __bugReportCleanup?: () => void; pushEvent?: (event: string, payload: object) => void }) {
    this.__bugReportCleanup?.();
    this.__bugReportCleanup = mountBugReportLedger(
      this.el as HTMLElement,
      this.pushEvent?.bind(this),
    );
  },
  destroyed(this: HookContext & { __bugReportCleanup?: () => void }) {
    this.__bugReportCleanup?.();
  },
};

function mountRegentCliAtlas(root: HTMLElement): () => void {
  return mountDisclosurePanels(root, "[data-cli-command-toggle]", "Show details", "Hide details");
}

const RegentCliAtlasHook = {
  ...createCleanupHook("__regentCliCleanup", mountRegentCliAtlas),
} satisfies HooksOptions[string];

function mountFormationHistory(root: HTMLElement): () => void {
  return mountDisclosurePanels(root, "[data-formation-toggle]", "Expand", "Collapse");
}

const FormationHistoryHook = {
  ...createCleanupHook("__formationHistoryCleanup", mountFormationHistory),
} satisfies HooksOptions[string];

function mountFormationPassGallery(root: HTMLElement): () => void {
  const cardRoots = Array.from(root.querySelectorAll<HTMLElement>("[data-token-card-root]"));
  if (cardRoots.length === 0) return () => undefined;

  const budget = Math.max(1, Number.parseInt(root.dataset.tokenCardBudget ?? "10", 10) || 10);
  const chunkSize = Math.max(1, Number.parseInt(root.dataset.tokenCardChunk ?? "2", 10) || 2);
  let tokenCards: Awaited<ReturnType<typeof loadTokenCardRoot>> | undefined;
  let cancelled = false;
  let frameId = 0;

  const syncActiveWindow = () => {
    frameId = 0;
    if (!tokenCards) return;
    const activeTokenCards = tokenCards;

    const viewportTop = 0;
    const firstVisibleIndex = cardRoots.findIndex((cardRoot) => {
      const rect = cardRoot.getBoundingClientRect();
      return rect.bottom > viewportTop + 48;
    });

    const normalizedFirstVisible = firstVisibleIndex === -1 ? 0 : firstVisibleIndex;
    const maxStart = Math.max(0, cardRoots.length - budget);
    const windowStart = Math.min(maxStart, Math.floor(normalizedFirstVisible / chunkSize) * chunkSize);
    const windowEnd = windowStart + budget;

    cardRoots.forEach((cardRoot, index) => {
      const active = index >= windowStart && index < windowEnd;
      const nextValue = active ? "true" : "false";

      if (cardRoot.dataset.tokenCardActive === nextValue) return;

      cardRoot.dataset.tokenCardActive = nextValue;
      activeTokenCards.updateTokenCardRoot(cardRoot);
    });
  };

  const requestSync = () => {
    if (frameId) return;
    frameId = window.requestAnimationFrame(syncActiveWindow);
  };

  void loadTokenCardRoot().then((module) => {
    if (cancelled) return;
    tokenCards = module;

    cardRoots.forEach((cardRoot, index) => {
      cardRoot.dataset.tokenCardActive = index < budget ? "true" : "false";
      module.mountTokenCardRoot(cardRoot);
    });

    requestSync();
  });

  window.addEventListener("scroll", requestSync, { passive: true });
  window.addEventListener("resize", requestSync);

  return () => {
    cancelled = true;

    if (frameId) {
      window.cancelAnimationFrame(frameId);
    }

    window.removeEventListener("scroll", requestSync);
    window.removeEventListener("resize", requestSync);
    if (tokenCards) {
      cardRoots.forEach((cardRoot) => tokenCards?.unmountTokenCardRoot(cardRoot));
    }
  };
}

const FormationPassGalleryHook = {
  ...createCleanupHook("__formationPassGalleryCleanup", mountFormationPassGallery),
} satisfies HooksOptions[string];

function mountSidebarCommunity(root: HTMLElement): () => void {
  const button = root.querySelector<HTMLButtonElement>("[data-community-toggle]");
  const panel = root.querySelector<HTMLDivElement>("[data-community-panel]");
  const grid = panel?.querySelector<HTMLElement>(".pp-sidebar-community-grid") ?? null;
  const icon = root.querySelector<HTMLElement>("[data-community-icon]");

  if (!button || !panel) return () => undefined;

  const motionReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const closedOffset = 10;
  const openDuration = 260;
  const closeDuration = 220;
  const iconDuration = 220;
  let iconAnimation: ReturnType<typeof animate> | undefined;
  let gridAnimation: ReturnType<typeof animate> | undefined;
  let panelAnimation: ReturnType<typeof animate> | undefined;

  const syncExpanded = (expanded: boolean) => {
    button.setAttribute("aria-expanded", expanded ? "true" : "false");
    button.dataset.communityOpen = expanded ? "true" : "false";
  };

  const resetClosed = () => {
    panel.hidden = true;
    panel.dataset.panelState = "closed";
    panel.style.height = "0px";
  };

  const stopMotion = () => {
    iconAnimation?.cancel();
    gridAnimation?.cancel();
    panelAnimation?.cancel();
    iconAnimation = undefined;
    gridAnimation = undefined;
    panelAnimation = undefined;
  };

  const setIconRotation = (expanded: boolean) => {
    if (!icon) return;
    icon.style.transform = expanded ? "rotate(180deg)" : "rotate(0deg)";
  };

  const setGridState = (expanded: boolean) => {
    if (!grid) return;
    grid.style.opacity = expanded ? "1" : "0";
    grid.style.transform = expanded ? "translate3d(0, 0, 0)" : `translate3d(0, ${closedOffset}px, 0)`;
  };

  syncExpanded(false);
  setIconRotation(false);
  setGridState(false);
  resetClosed();

  const open = () => {
    syncExpanded(true);
    stopMotion();

    if (motionReduced) {
      panel.hidden = false;
      panel.dataset.panelState = "open";
      panel.style.height = "auto";
      setIconRotation(true);
      setGridState(true);
      return;
    }

    const startHeight = panel.hidden ? 0 : panel.getBoundingClientRect().height;
    panel.hidden = false;
    panel.style.height = `${startHeight}px`;
    panel.dataset.panelState = "opening";
    setIconRotation(false);
    setGridState(false);

    requestAnimationFrame(() => {
      const targetHeight = Math.max(panel.scrollHeight, grid?.scrollHeight ?? 0);

      panelAnimation = animate(panel, {
        height: [startHeight, targetHeight],
        duration: openDuration,
        ease: "outQuint",
        onComplete: () => {
          panel.style.height = "auto";
          panel.dataset.panelState = "open";
        },
      });

      if (icon) {
        iconAnimation = animate(icon, {
          rotate: "180deg",
          duration: iconDuration,
          ease: "outQuint",
        });
      }

      if (grid) {
        gridAnimation = animate(grid, {
          opacity: [0, 1],
          translateY: [closedOffset, 0],
          duration: openDuration - 10,
          ease: "outQuart",
        });
      }
    });
  };

  const close = () => {
    syncExpanded(false);

    stopMotion();

    if (motionReduced) {
      panel.dataset.panelState = "closed";
      setIconRotation(false);
      setGridState(false);
      panel.style.height = "0px";
      panel.hidden = true;
      return;
    }

    const startHeight = panel.getBoundingClientRect().height || panel.scrollHeight;

    panel.hidden = false;
    panel.style.height = `${startHeight}px`;
    panel.dataset.panelState = "closing";

    if (icon) {
      iconAnimation = animate(icon, {
        rotate: "0deg",
        duration: iconDuration,
        ease: "outQuart",
      });
    }

    if (grid) {
      gridAnimation = animate(grid, {
        opacity: [1, 0],
        translateY: [0, closedOffset],
        duration: closeDuration - 20,
        ease: "outQuart",
      });
    }

    requestAnimationFrame(() => {
      panelAnimation = animate(panel, {
        height: [startHeight, 0],
        duration: closeDuration,
        ease: "inOutQuart",
        onComplete: () => {
          panel.dataset.panelState = "closed";
          panel.style.height = "0px";
          panel.hidden = true;
        },
      });
    });
  };

  const toggle = () => {
    const expanded = button.getAttribute("aria-expanded") === "true";
    if (expanded) {
      close();
      return;
    }

    open();
  };

  button.addEventListener("click", toggle);

  return () => {
    stopMotion();
    button.removeEventListener("click", toggle);
  };
}

const SidebarCommunityHook = {
  ...createCleanupHook("__sidebarCommunityCleanup", mountSidebarCommunity),
} satisfies HooksOptions[string];

const OverviewModeHook = {
  ...createCleanupHook("__overviewModeCleanup", mountOverviewMode),
} satisfies HooksOptions[string];

const ColorModeToggleHook = {
  ...createCleanupHook("__colorModeCleanup", mountColorModeToggle),
} satisfies HooksOptions[string];

const AgentbookTrustFlowHook = {
  mounted(this: HookContext) {
    void loadAgentbookTrustFlow().then(({ AgentbookTrustFlow }) => {
      if (!this.el.isConnected) return;
      const mounted = AgentbookTrustFlow.mounted;
      if (mounted) (mounted as (this: HookContext) => void).call(this);
    });
  },
  updated(this: HookContext) {
    void loadAgentbookTrustFlow().then(({ AgentbookTrustFlow }) => {
      if (!this.el.isConnected) return;
      const updated = AgentbookTrustFlow.updated;
      if (updated) (updated as (this: HookContext) => void).call(this);
    });
  },
  destroyed(this: HookContext) {
    void loadAgentbookTrustFlow().then(({ AgentbookTrustFlow }) => {
      const destroyed = AgentbookTrustFlow.destroyed;
      if (destroyed) (destroyed as (this: HookContext) => void).call(this);
    });
  },
} satisfies HooksOptions[string];

function mountStaticTokenCardRoots() {
  const elements = Array.from(
    document.querySelectorAll("[data-token-card-root][data-token-card-autoload]"),
  );

  if (elements.length === 0) return;

  void loadTokenCardRoot().then(({ mountTokenCardRoot }) => {
    elements.forEach((el) => {
      if (el.isConnected) mountTokenCardRoot(el);
    });
  });
}

function unmountStaticTokenCardRoots() {
  const elements = Array.from(
    document.querySelectorAll("[data-token-card-root][data-token-card-autoload]"),
  );

  if (elements.length === 0) return;

  void loadTokenCardRoot().then(({ unmountTokenCardRoot }) => {
    elements.forEach((el) => unmountTokenCardRoot(el));
  });
}

const csrfToken =
  document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ?? "";

installHeerich(Heerich);
registerWebMCP(window);

const hooks: HooksOptions = {
  ...regentHooks,
  DashboardPrivyBridge: DashboardPrivyBridgeHook,
  DashboardWallet: DashboardWalletHook,
  DashboardNameClaim: DashboardNameClaimHook,
  DashboardRedeem: DashboardRedeemHook,
  TokenStaking: TokenStakingHook,
  DashboardXmtpRoom: DashboardXmtpRoomHook,
  LaunchProgress: LaunchProgressHook,
  ShaderRoot: ShaderRootHook,
  AnimatedHomeLogoScene: AnimatedHomeLogoSceneHook,
  HomeRegentScene,
  HomeReveal: HomeRevealHook,
  BridgeReveal: BridgeRevealHook,
  BugReportReveal: BugReportRevealHook,
  AutolaunchReveal: BridgeRevealHook,
  BugReportLedger: BugReportLedgerHook,
  RegentCliAtlas: RegentCliAtlasHook,
  FormationHistory: FormationHistoryHook,
  FormationPassGallery: FormationPassGalleryHook,
  SidebarCommunity: SidebarCommunityHook,
  DashboardReveal: DashboardRevealHook,
  DemoReveal: DemoRevealHook,
  Demo2Tunnel: Demo2TunnelHook,
  HeerichProceduralDemo: HeerichProceduralDemoHook,
  FooterVoxel: FooterVoxelHook,
  LogoStudies: LogoStudiesHook,
  ClipboardCopy: ClipboardCopyHook,
  QuickSearch: QuickSearchHook,
  OverviewMode: OverviewModeHook,
  ColorModeToggle: ColorModeToggleHook,
  VoxelBackground: VoxelBackgroundHook,
  AgentbookTrustFlow: AgentbookTrustFlowHook,
};

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks,
});

topbar.config({ barColors: { 0: "#034568" }, shadowColor: "rgba(0, 0, 0, .18)" });
window.addEventListener("phx:page-loading-start", () => topbar.show(200));
window.addEventListener("phx:page-loading-stop", () => topbar.hide());

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mountStaticTokenCardRoots, { once: true });
} else {
  mountStaticTokenCardRoots();
}

window.addEventListener("beforeunload", unmountStaticTokenCardRoots);

liveSocket.connect();

declare global {
  interface Window {
    liveSocket: typeof liveSocket;
  }
}

window.liveSocket = liveSocket;
