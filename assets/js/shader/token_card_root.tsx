import React from "react";
import { createRoot, type Root } from "react-dom/client";

import { TokenCardPage } from "./TokenCardPage.tsx";
import type { TokenCardManifestEntry } from "./token_card_types.ts";

type MountedTokenCardRoot = {
  root: Root;
};

const roots = new WeakMap<Element, MountedTokenCardRoot>();

function readEntry(el: Element): TokenCardManifestEntry {
  const container = el.closest("[data-token-card-page]") ?? el.parentElement;
  const script = container?.querySelector<HTMLScriptElement>("[data-token-card-json]");

  if (!script?.textContent) {
    throw new Error("Token card page is missing its manifest payload.");
  }

  return JSON.parse(script.textContent) as TokenCardManifestEntry;
}

function readLayout(el: Element): "page" | "embedded" {
  return el.getAttribute("data-token-card-layout") === "embedded" ? "embedded" : "page";
}

function readActive(el: Element): boolean {
  return el.getAttribute("data-token-card-active") !== "false";
}

function renderRoot(mounted: MountedTokenCardRoot, el: Element) {
  const entry = readEntry(el);
  const layout = readLayout(el);
  const active = readActive(el);

  mounted.root.render(
    <React.StrictMode>
      <TokenCardPage entry={entry} active={active} layout={layout} />
    </React.StrictMode>,
  );
}

export function mountTokenCardRoot(el: Element): void {
  const mounted = roots.get(el);
  if (mounted) {
    renderRoot(mounted, el);
    return;
  }

  const root = createRoot(el);
  const nextMounted = { root };
  roots.set(el, nextMounted);
  renderRoot(nextMounted, el);
}

export function updateTokenCardRoot(el: Element): void {
  const mounted = roots.get(el);

  if (!mounted) {
    mountTokenCardRoot(el);
    return;
  }

  renderRoot(mounted, el);
}

export function unmountTokenCardRoot(el: Element): void {
  const mounted = roots.get(el);
  if (!mounted) return;

  mounted.root.unmount();
  roots.delete(el);
}
