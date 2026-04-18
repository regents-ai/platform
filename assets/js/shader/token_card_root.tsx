import React from "react";
import { createRoot, type Root } from "react-dom/client";

import { TokenCardPage } from "./TokenCardPage.tsx";
import type { TokenCardManifestEntry } from "./token_card_types.ts";

type MountedTokenCardRoot = {
  root: Root;
};

const roots = new WeakMap<Element, MountedTokenCardRoot>();

function decodeBase64Url(raw: string): string {
  if (typeof Buffer !== "undefined") {
    return Buffer.from(raw, "base64url").toString("utf8");
  }

  const normalized = raw.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = globalThis.atob(padded);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function readEntry(el: Element): TokenCardManifestEntry {
  const payload = el.getAttribute("data-token-card-entry");

  if (!payload) {
    throw new Error("Token card page is missing its manifest payload.");
  }

  return JSON.parse(decodeBase64Url(payload)) as TokenCardManifestEntry;
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
