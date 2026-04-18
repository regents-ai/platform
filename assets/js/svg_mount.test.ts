import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { JSDOM } from "jsdom";

import { mountSceneError, mountSvgMarkup, parseSvgMarkup } from "./svg_mount.ts";

function withDom(assertion: (doc: Document) => void): void {
  const dom = new JSDOM("<!doctype html><div id=\"root\"></div>");
  const previousDOMParser = globalThis.DOMParser;

  Object.assign(globalThis, {
    DOMParser: dom.window.DOMParser,
  });

  try {
    assertion(dom.window.document);
  } finally {
    globalThis.DOMParser = previousDOMParser;
  }
}

describe("svg_mount", () => {
  it("mounts generated svg markup as an svg element", () => {
    withDom((doc) => {
      const root = doc.getElementById("root");

      assert.ok(root);

      const svg = mountSvgMarkup(
        root,
        "<svg viewBox=\"0 0 8 8\"><g data-shape=\"voxel\"></g></svg>",
      );

      assert.equal(svg.tagName.toLowerCase(), "svg");
      assert.equal(root.firstElementChild?.tagName.toLowerCase(), "svg");
      assert.ok(root.querySelector("[data-shape=\"voxel\"]"));
    });
  });

  it("rejects markup that does not parse to an svg root", () => {
    withDom((doc) => {
      assert.throws(() => parseSvgMarkup("<div>bad</div>", doc));
    });
  });

  it("renders scene errors as text nodes instead of html strings", () => {
    withDom((doc) => {
      const root = doc.getElementById("root");

      assert.ok(root);

      mountSceneError(root, "Could not render scene.", [
        "</script><script>alert('xss')</script>",
      ]);

      assert.equal(root.querySelector("strong")?.textContent, "Could not render scene.");
      assert.equal(
        root.querySelector("span")?.textContent,
        "</script><script>alert('xss')</script>",
      );
      assert.equal(root.querySelector("script"), null);
    });
  });
});
