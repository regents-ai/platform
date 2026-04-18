export function parseSvgMarkup(markup: string, doc: Document = document): SVGSVGElement {
  const Parser = doc.defaultView?.DOMParser ?? DOMParser;
  const parsed = new Parser().parseFromString(markup, "image/svg+xml");
  const svg = parsed.documentElement;

  if (parsed.querySelector("parsererror") || svg.tagName.toLowerCase() !== "svg") {
    throw new Error("Expected generated SVG markup.");
  }

  return doc.importNode(svg, true) as unknown as SVGSVGElement;
}

export function mountSvgMarkup(container: Element, markup: string): SVGSVGElement {
  const doc = container.ownerDocument ?? document;
  const svg = parseSvgMarkup(markup, doc);
  container.replaceChildren(svg);
  return svg;
}

export function clearChildren(container: Element): void {
  container.replaceChildren();
}

export function mountSceneError(
  container: Element,
  title: string,
  lines: string[] = [],
): HTMLElement {
  const doc = container.ownerDocument ?? document;
  const wrapper = doc.createElement("div");
  wrapper.className = "rg-scene-error";

  const strong = doc.createElement("strong");
  strong.textContent = title;
  wrapper.append(strong);

  for (const line of lines) {
    const span = doc.createElement("span");
    span.textContent = line;
    wrapper.append(span);
  }

  container.replaceChildren(wrapper);
  return wrapper;
}
