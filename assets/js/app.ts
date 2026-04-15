import "phoenix_html";
import { animate } from "animejs";
import { Socket } from "phoenix";
import { LiveSocket, type HooksOptions } from "phoenix_live_view";
import { Heerich } from "heerich";
import topbar from "../vendor/topbar.cjs";
import {
  bindDashboardNameClaim,
  bindDashboardRedeem,
  bindDashboardWallet,
  mountDashboardPrivyBridge,
  unmountDashboardPrivyBridge,
} from "./dashboard/islands";
import { DashboardXmtpRoomHook } from "./dashboard/xmtp_room";
import { mountShaderRoot, unmountShaderRoot } from "./shader/root";
import { mountTokenCardRoot, unmountTokenCardRoot, updateTokenCardRoot } from "./shader/token_card_root";
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
import { mountProceduralHeerichDemo } from "./heerich_demo";
import { AnimatedHomeLogoSceneHook } from "./home_logo_scene";
import { LogoStudiesHook } from "./logos";
import { mountOverviewMode } from "./overview";
import { mountColorModeToggle } from "./color_mode";
import { VoxelBackgroundHook } from "./voxel_background";

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

function mountDashboardHook(
  context: HookContext,
  binder: (el: HTMLElement) => () => void,
) {
  context.__dashboardCleanup?.();
  context.__dashboardCleanup = binder(context.el as HTMLElement);
}

const DashboardPrivyBridgeHook = {
  mounted(this: HookContext) {
    mountDashboardPrivyBridge(this.el);
  },
  destroyed(this: HookContext) {
    unmountDashboardPrivyBridge(this.el);
  },
};

const DashboardWalletHook = {
  mounted(this: HookContext) {
    mountDashboardHook(this, bindDashboardWallet);
  },
  updated(this: HookContext) {
    mountDashboardHook(this, bindDashboardWallet);
  },
  destroyed(this: HookContext) {
    this.__dashboardCleanup?.();
  },
};

const DashboardNameClaimHook = {
  mounted(this: HookContext) {
    mountDashboardHook(this, bindDashboardNameClaim);
  },
  updated(this: HookContext) {
    mountDashboardHook(this, bindDashboardNameClaim);
  },
  destroyed(this: HookContext) {
    this.__dashboardCleanup?.();
  },
};

const DashboardRedeemHook = {
  mounted(this: HookContext) {
    mountDashboardHook(this, bindDashboardRedeem);
  },
  updated(this: HookContext) {
    mountDashboardHook(this, bindDashboardRedeem);
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
  mounted(this: HookContext) {
    this.__launchProgressCleanup?.();
    this.__launchProgressCleanup = mountLaunchProgress(this.el as HTMLElement);
  },
  updated(this: HookContext) {
    this.__launchProgressCleanup?.();
    this.__launchProgressCleanup = mountLaunchProgress(this.el as HTMLElement);
  },
  destroyed(this: HookContext) {
    this.__launchProgressCleanup?.();
  },
};

const ShaderRootHook = {
  mounted(this: HookContext) {
    mountShaderRoot(this.el);
  },
  updated(this: HookContext) {
    mountShaderRoot(this.el);
  },
  destroyed(this: HookContext) {
    unmountShaderRoot(this.el);
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
const ClipboardCopyHook = {
  mounted(this: HookContext & { __copyReset?: number }) {
    const button = this.el as HTMLButtonElement;
    const copyText = button.dataset.copyText ?? "";

    const resetCopied = () => {
      button.dataset.copied = "false";
      delete this.__copyReset;
    };

    button.addEventListener("click", () => {
      if (!copyText) return;

      void navigator.clipboard.writeText(copyText).then(() => {
        if (this.__copyReset) window.clearTimeout(this.__copyReset);
        button.dataset.copied = "true";
        this.__copyReset = window.setTimeout(resetCopied, 1400);
      });
    });
  },
  destroyed(this: HookContext & { __copyReset?: number }) {
    if (this.__copyReset) window.clearTimeout(this.__copyReset);
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
    this.__bugReportCleanup = mountBugReportLedger(this.el as HTMLElement, this.pushEvent?.bind(this));
  },
  updated(this: HookContext & { __bugReportCleanup?: () => void; pushEvent?: (event: string, payload: object) => void }) {
    this.__bugReportCleanup?.();
    this.__bugReportCleanup = mountBugReportLedger(this.el as HTMLElement, this.pushEvent?.bind(this));
  },
  destroyed(this: HookContext & { __bugReportCleanup?: () => void }) {
    this.__bugReportCleanup?.();
  },
};

function mountRegentCliAtlas(root: HTMLElement): () => void {
  return mountDisclosurePanels(root, "[data-cli-command-toggle]", "Show details", "Hide details");
}

const RegentCliAtlasHook = {
  mounted(this: HookContext & { __regentCliCleanup?: () => void }) {
    this.__regentCliCleanup = mountRegentCliAtlas(this.el as HTMLElement);
  },
  updated(this: HookContext & { __regentCliCleanup?: () => void }) {
    this.__regentCliCleanup?.();
    this.__regentCliCleanup = mountRegentCliAtlas(this.el as HTMLElement);
  },
  destroyed(this: HookContext & { __regentCliCleanup?: () => void }) {
    this.__regentCliCleanup?.();
  },
};

function mountFormationHistory(root: HTMLElement): () => void {
  return mountDisclosurePanels(root, "[data-formation-toggle]", "Expand", "Collapse");
}

const FormationHistoryHook = {
  mounted(this: HookContext & { __formationHistoryCleanup?: () => void }) {
    this.__formationHistoryCleanup = mountFormationHistory(this.el as HTMLElement);
  },
  updated(this: HookContext & { __formationHistoryCleanup?: () => void }) {
    this.__formationHistoryCleanup?.();
    this.__formationHistoryCleanup = mountFormationHistory(this.el as HTMLElement);
  },
  destroyed(this: HookContext & { __formationHistoryCleanup?: () => void }) {
    this.__formationHistoryCleanup?.();
  },
};

function mountFormationPassGallery(root: HTMLElement): () => void {
  const cardRoots = Array.from(root.querySelectorAll<HTMLElement>("[data-token-card-root]"));
  if (cardRoots.length === 0) return () => undefined;

  const budget = Math.max(1, Number.parseInt(root.dataset.tokenCardBudget ?? "10", 10) || 10);
  const chunkSize = Math.max(1, Number.parseInt(root.dataset.tokenCardChunk ?? "2", 10) || 2);
  let frameId = 0;

  const syncActiveWindow = () => {
    frameId = 0;

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
      updateTokenCardRoot(cardRoot);
    });
  };

  const requestSync = () => {
    if (frameId) return;
    frameId = window.requestAnimationFrame(syncActiveWindow);
  };

  cardRoots.forEach((cardRoot, index) => {
    cardRoot.dataset.tokenCardActive = index < budget ? "true" : "false";
    mountTokenCardRoot(cardRoot);
  });

  requestSync();
  window.addEventListener("scroll", requestSync, { passive: true });
  window.addEventListener("resize", requestSync);

  return () => {
    if (frameId) {
      window.cancelAnimationFrame(frameId);
    }

    window.removeEventListener("scroll", requestSync);
    window.removeEventListener("resize", requestSync);
    cardRoots.forEach((cardRoot) => unmountTokenCardRoot(cardRoot));
  };
}

const FormationPassGalleryHook = {
  mounted(this: HookContext & { __formationPassGalleryCleanup?: () => void }) {
    this.__formationPassGalleryCleanup = mountFormationPassGallery(this.el as HTMLElement);
  },
  updated(this: HookContext & { __formationPassGalleryCleanup?: () => void }) {
    this.__formationPassGalleryCleanup?.();
    this.__formationPassGalleryCleanup = mountFormationPassGallery(this.el as HTMLElement);
  },
  destroyed(this: HookContext & { __formationPassGalleryCleanup?: () => void }) {
    this.__formationPassGalleryCleanup?.();
  },
};

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
  mounted(this: HookContext & { __sidebarCommunityCleanup?: () => void }) {
    this.__sidebarCommunityCleanup = mountSidebarCommunity(this.el as HTMLElement);
  },
  updated(this: HookContext & { __sidebarCommunityCleanup?: () => void }) {
    this.__sidebarCommunityCleanup?.();
    this.__sidebarCommunityCleanup = mountSidebarCommunity(this.el as HTMLElement);
  },
  destroyed(this: HookContext & { __sidebarCommunityCleanup?: () => void }) {
    this.__sidebarCommunityCleanup?.();
  },
};

const OverviewModeHook = {
  mounted(this: HookContext & { __overviewModeCleanup?: () => void }) {
    this.__overviewModeCleanup = mountOverviewMode(this.el as HTMLElement);
  },
  updated(this: HookContext & { __overviewModeCleanup?: () => void }) {
    this.__overviewModeCleanup?.();
    this.__overviewModeCleanup = mountOverviewMode(this.el as HTMLElement);
  },
  destroyed(this: HookContext & { __overviewModeCleanup?: () => void }) {
    this.__overviewModeCleanup?.();
  },
};

const ColorModeToggleHook = {
  mounted(this: HookContext & { __colorModeCleanup?: () => void }) {
    this.__colorModeCleanup = mountColorModeToggle(this.el as HTMLElement);
  },
  updated(this: HookContext & { __colorModeCleanup?: () => void }) {
    this.__colorModeCleanup?.();
    this.__colorModeCleanup = mountColorModeToggle(this.el as HTMLElement);
  },
  destroyed(this: HookContext & { __colorModeCleanup?: () => void }) {
    this.__colorModeCleanup?.();
  },
};

function mountStaticTokenCardRoots() {
  document.querySelectorAll("[data-token-card-root][data-token-card-autoload]").forEach((el) => {
    mountTokenCardRoot(el);
  });
}

function unmountStaticTokenCardRoots() {
  document.querySelectorAll("[data-token-card-root][data-token-card-autoload]").forEach((el) => {
    unmountTokenCardRoot(el);
  });
}

const csrfToken =
  document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ?? "";

installHeerich(Heerich);

const hooks: HooksOptions = {
  ...regentHooks,
  DashboardPrivyBridge: DashboardPrivyBridgeHook,
  DashboardWallet: DashboardWalletHook,
  DashboardNameClaim: DashboardNameClaimHook,
  DashboardRedeem: DashboardRedeemHook,
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
  HeerichProceduralDemo: HeerichProceduralDemoHook,
  FooterVoxel: FooterVoxelHook,
  LogoStudies: LogoStudiesHook,
  ClipboardCopy: ClipboardCopyHook,
  OverviewMode: OverviewModeHook,
  ColorModeToggle: ColorModeToggleHook,
  VoxelBackground: VoxelBackgroundHook,
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
