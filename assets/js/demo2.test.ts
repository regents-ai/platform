import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { JSDOM } from "jsdom";
import { Heerich } from "heerich";

import { mountDemo2Tunnel } from "./demo2.ts";

describe("mountDemo2Tunnel", () => {
  it("renders the tunnel study into the scene root", () => {
    const dom = new JSDOM(
      `<div id="root" data-demo2-variant="white-gate">
        <div data-demo2-scene></div>
        <div data-demo2-beam></div>
        <div data-demo2-beam></div>
        <div data-demo2-monolith>
          <span data-demo2-slit></span>
        </div>
      </div>`,
      { url: "https://regents.sh/demo2" },
    );

    const { window } = dom;
    const originalWindow = globalThis.window;
    const originalDocument = globalThis.document;
    const originalHTMLElement = globalThis.HTMLElement;
    const originalSVGElement = globalThis.SVGElement;
    const originalRequestAnimationFrame = globalThis.requestAnimationFrame;
    const originalCancelAnimationFrame = globalThis.cancelAnimationFrame;

    Object.defineProperty(window, "matchMedia", {
      value: () => ({ matches: true }),
      configurable: true,
    });

    const requestAnimationFrame = ((callback: FrameRequestCallback) => {
      callback(16);
      return 1;
    }) as typeof globalThis.requestAnimationFrame;

    const cancelAnimationFrame = (() => undefined) as typeof globalThis.cancelAnimationFrame;

    Object.assign(globalThis, {
      window,
      document: window.document,
      HTMLElement: window.HTMLElement,
      SVGElement: window.SVGElement,
      requestAnimationFrame,
      cancelAnimationFrame,
    });

    window.requestAnimationFrame = requestAnimationFrame;
    window.cancelAnimationFrame = cancelAnimationFrame;
    window.Heerich = Heerich as unknown as typeof window.Heerich;

    const root = window.document.getElementById("root");
    const sceneRoot = root?.querySelector<HTMLElement>("[data-demo2-scene]");

    assert.ok(root);
    assert.ok(sceneRoot);

    Object.defineProperty(sceneRoot, "clientWidth", {
      value: 1280,
      configurable: true,
    });

    const cleanup = mountDemo2Tunnel(root);

    assert.ok(sceneRoot.querySelector("svg"));
    assert.ok(sceneRoot.querySelector("[data-zone=\"left\"][data-part=\"ceiling\"]"));
    assert.ok(sceneRoot.querySelector("[data-zone=\"right\"][data-part=\"wall\"]"));
    assert.equal(root.style.getPropertyValue("--pp-demo2-beam-right"), "30%");

    cleanup();

    globalThis.window = originalWindow;
    globalThis.document = originalDocument;
    globalThis.HTMLElement = originalHTMLElement;
    globalThis.SVGElement = originalSVGElement;
    globalThis.requestAnimationFrame = originalRequestAnimationFrame;
    globalThis.cancelAnimationFrame = originalCancelAnimationFrame;
  });
});
