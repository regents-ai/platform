import { animate } from "animejs";
import type { HeerichInstance } from "../regent/js/heerich_types";

type MotionRefs = {
  sceneRoot: HTMLElement;
  beams: HTMLElement[];
  monolith: HTMLElement | null;
  slit: HTMLElement | null;
};

type TunnelVariantId =
  | "ember-hall"
  | "split-spine"
  | "low-orbit"
  | "white-gate"
  | "redline";

type TunnelVariantSpec = {
  scene: {
    chamberWidth: { compact: number; wide: number };
    height: { compact: number; wide: number };
    depth: { compact: number; wide: number };
    gap: { compact: number; wide: number };
    tile: { compact: number; wide: number };
    cameraX: number;
    cameraY: { compact: number; wide: number };
    cameraDistance: { compact: number; wide: number };
    ceilingHue: { near: number; far: number };
    wallHue: { near: number; far: number };
    glowHue: { near: number; far: number };
    ceilingLight: { near: number; far: number };
    wallLight: { near: number; far: number };
  };
  presentation: {
    frameTop: string;
    frameBottom: string;
    halo: string;
    haze: string;
    beamLeft: string;
    beamRight: string;
    beamOpacity: string;
    beamColor: string;
    slitTop: string;
    slitBottom: string;
    monolithWidth: string;
  };
};

const variantSpecs: Record<TunnelVariantId, TunnelVariantSpec> = {
  "ember-hall": {
    scene: {
      chamberWidth: { compact: 12, wide: 15 },
      height: { compact: 7, wide: 8 },
      depth: { compact: 26, wide: 34 },
      gap: { compact: 4, wide: 5 },
      tile: { compact: 28, wide: 36 },
      cameraX: 0,
      cameraY: { compact: -5.8, wide: -7.2 },
      cameraDistance: { compact: 9.6, wide: 11.2 },
      ceilingHue: { near: 31, far: 20 },
      wallHue: { near: 18, far: 14 },
      glowHue: { near: 86, far: 50 },
      ceilingLight: { near: 0.42, far: 0.29 },
      wallLight: { near: 0.3, far: 0.21 },
    },
    presentation: {
      frameTop: "rgba(43, 10, 18, 0.94)",
      frameBottom: "rgba(9, 7, 14, 0.98)",
      halo: "rgba(255, 246, 216, 0.08)",
      haze: "rgba(255, 236, 203, 0.14)",
      beamLeft: "36%",
      beamRight: "36%",
      beamOpacity: "0.24",
      beamColor: "rgba(255, 244, 212, 0.74)",
      slitTop: "rgba(210, 247, 255, 0.96)",
      slitBottom: "rgba(133, 236, 255, 0.58)",
      monolithWidth: "clamp(13rem, 20vw, 22rem)",
    },
  },
  "split-spine": {
    scene: {
      chamberWidth: { compact: 13, wide: 17 },
      height: { compact: 8, wide: 9 },
      depth: { compact: 24, wide: 31 },
      gap: { compact: 6, wide: 7 },
      tile: { compact: 28, wide: 34 },
      cameraX: 0.2,
      cameraY: { compact: -6.2, wide: -7.7 },
      cameraDistance: { compact: 9.8, wide: 11.6 },
      ceilingHue: { near: 28, far: 18 },
      wallHue: { near: 14, far: 10 },
      glowHue: { near: 84, far: 42 },
      ceilingLight: { near: 0.41, far: 0.27 },
      wallLight: { near: 0.28, far: 0.19 },
    },
    presentation: {
      frameTop: "rgba(49, 8, 16, 0.95)",
      frameBottom: "rgba(11, 5, 11, 0.98)",
      halo: "rgba(255, 220, 172, 0.1)",
      haze: "rgba(255, 224, 190, 0.16)",
      beamLeft: "33%",
      beamRight: "33%",
      beamOpacity: "0.28",
      beamColor: "rgba(255, 230, 186, 0.8)",
      slitTop: "rgba(240, 252, 255, 0.94)",
      slitBottom: "rgba(160, 236, 255, 0.6)",
      monolithWidth: "clamp(12rem, 18vw, 19rem)",
    },
  },
  "low-orbit": {
    scene: {
      chamberWidth: { compact: 11, wide: 14 },
      height: { compact: 8, wide: 10 },
      depth: { compact: 22, wide: 28 },
      gap: { compact: 4, wide: 5 },
      tile: { compact: 30, wide: 38 },
      cameraX: -0.6,
      cameraY: { compact: -4.8, wide: -5.8 },
      cameraDistance: { compact: 8.6, wide: 10.1 },
      ceilingHue: { near: 23, far: 12 },
      wallHue: { near: 16, far: 8 },
      glowHue: { near: 72, far: 34 },
      ceilingLight: { near: 0.38, far: 0.23 },
      wallLight: { near: 0.26, far: 0.17 },
    },
    presentation: {
      frameTop: "rgba(33, 7, 12, 0.96)",
      frameBottom: "rgba(8, 5, 10, 0.99)",
      halo: "rgba(255, 214, 160, 0.08)",
      haze: "rgba(246, 216, 182, 0.12)",
      beamLeft: "29%",
      beamRight: "38%",
      beamOpacity: "0.2",
      beamColor: "rgba(255, 225, 176, 0.7)",
      slitTop: "rgba(241, 252, 255, 0.84)",
      slitBottom: "rgba(111, 221, 255, 0.48)",
      monolithWidth: "clamp(14rem, 24vw, 24rem)",
    },
  },
  "white-gate": {
    scene: {
      chamberWidth: { compact: 12, wide: 16 },
      height: { compact: 7, wide: 8 },
      depth: { compact: 28, wide: 36 },
      gap: { compact: 5, wide: 6 },
      tile: { compact: 27, wide: 35 },
      cameraX: 0.9,
      cameraY: { compact: -5.9, wide: -7.1 },
      cameraDistance: { compact: 9.5, wide: 11.0 },
      ceilingHue: { near: 34, far: 18 },
      wallHue: { near: 24, far: 12 },
      glowHue: { near: 102, far: 62 },
      ceilingLight: { near: 0.45, far: 0.3 },
      wallLight: { near: 0.32, far: 0.21 },
    },
    presentation: {
      frameTop: "rgba(35, 10, 16, 0.93)",
      frameBottom: "rgba(10, 8, 15, 0.98)",
      halo: "rgba(255, 249, 229, 0.1)",
      haze: "rgba(255, 246, 227, 0.18)",
      beamLeft: "35%",
      beamRight: "30%",
      beamOpacity: "0.26",
      beamColor: "rgba(255, 250, 232, 0.84)",
      slitTop: "rgba(255, 255, 255, 0.98)",
      slitBottom: "rgba(191, 247, 255, 0.7)",
      monolithWidth: "clamp(12.5rem, 18vw, 18rem)",
    },
  },
  redline: {
    scene: {
      chamberWidth: { compact: 11, wide: 15 },
      height: { compact: 7, wide: 8 },
      depth: { compact: 30, wide: 40 },
      gap: { compact: 3, wide: 4 },
      tile: { compact: 27, wide: 34 },
      cameraX: -0.2,
      cameraY: { compact: -6.0, wide: -7.4 },
      cameraDistance: { compact: 9.4, wide: 11.3 },
      ceilingHue: { near: 18, far: 7 },
      wallHue: { near: 14, far: 6 },
      glowHue: { near: 74, far: 18 },
      ceilingLight: { near: 0.39, far: 0.24 },
      wallLight: { near: 0.27, far: 0.16 },
    },
    presentation: {
      frameTop: "rgba(51, 7, 12, 0.96)",
      frameBottom: "rgba(9, 4, 8, 0.99)",
      halo: "rgba(255, 204, 160, 0.1)",
      haze: "rgba(255, 216, 186, 0.14)",
      beamLeft: "38%",
      beamRight: "38%",
      beamOpacity: "0.22",
      beamColor: "rgba(255, 227, 185, 0.78)",
      slitTop: "rgba(255, 247, 224, 0.94)",
      slitBottom: "rgba(255, 201, 115, 0.54)",
      monolithWidth: "clamp(13rem, 19vw, 20rem)",
    },
  },
};

function buildGlowDefs(): string {
  return `
    <defs>
      <filter id="demo2-glow-soft" x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="1.4" result="blur"></feGaussianBlur>
        <feMerge>
          <feMergeNode in="blur"></feMergeNode>
          <feMergeNode in="SourceGraphic"></feMergeNode>
        </feMerge>
      </filter>
    </defs>
  `;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function mixValue(near: number, far: number, depthIndex: number, depth: number): number {
  const mix = clamp(depthIndex / Math.max(depth - 1, 1), 0, 1);
  return near + (far - near) * mix;
}

function glowColor(
  depthIndex: number,
  depth: number,
  spec: TunnelVariantSpec,
  extraHeat = 0,
): string {
  const mix = clamp(depthIndex / Math.max(depth - 1, 1), 0, 1);
  const lightness = 0.94 - mix * 0.16 + extraHeat * 0.03;
  const chroma = 0.07 + (1 - mix) * 0.16 + extraHeat * 0.02;
  const hue = mixValue(spec.scene.glowHue.near, spec.scene.glowHue.far, depthIndex, depth);
  return `oklch(${lightness.toFixed(3)} ${chroma.toFixed(3)} ${hue.toFixed(1)})`;
}

function ceilingFill(depthIndex: number, depth: number, spec: TunnelVariantSpec): string {
  const mix = clamp(depthIndex / Math.max(depth - 1, 1), 0, 1);
  const lightness = mixValue(
    spec.scene.ceilingLight.near,
    spec.scene.ceilingLight.far,
    depthIndex,
    depth,
  );
  const chroma = 0.11 + (1 - mix) * 0.06;
  const hue = mixValue(spec.scene.ceilingHue.near, spec.scene.ceilingHue.far, depthIndex, depth);
  return `oklch(${lightness.toFixed(3)} ${chroma.toFixed(3)} ${hue.toFixed(1)})`;
}

function wallFill(depthIndex: number, depth: number, spec: TunnelVariantSpec): string {
  const mix = clamp(depthIndex / Math.max(depth - 1, 1), 0, 1);
  const lightness = mixValue(spec.scene.wallLight.near, spec.scene.wallLight.far, depthIndex, depth);
  const chroma = 0.08 + (1 - mix) * 0.05;
  const hue = mixValue(spec.scene.wallHue.near, spec.scene.wallHue.far, depthIndex, depth);
  return `oklch(${lightness.toFixed(3)} ${chroma.toFixed(3)} ${hue.toFixed(1)})`;
}

function defaultEdgeStroke(depthIndex: number, depth: number, spec: TunnelVariantSpec): string {
  const mix = clamp(depthIndex / Math.max(depth - 1, 1), 0, 1);
  const green = Math.round(118 + (1 - mix) * 52);
  const blue = Math.round(18 + mixValue(spec.scene.glowHue.near, spec.scene.glowHue.far, depthIndex, depth) / 7);
  const alpha = 0.16 + (1 - mix) * 0.1;
  return `rgba(255, ${green}, ${blue}, ${alpha.toFixed(3)})`;
}

function addTunnelChamber(
  engine: HeerichInstance,
  spec: TunnelVariantSpec,
  zone: "left" | "right",
  chamberWidth: number,
  height: number,
  depth: number,
  gap: number,
): void {
  const startX = zone === "left" ? -(gap + chamberWidth) : gap;
  const wallX = zone === "left" ? startX : startX + chamberWidth - 1;
  const litWallFace = zone === "left" ? "right" : "left";

  engine.addGeometry({
    type: "box",
    position: [startX, 0, 0],
    size: [chamberWidth, 1, depth],
    meta: { zone, part: "ceiling" },
    style: {
      default: (_x: number, _y: number, z: number) => ({
        fill: ceilingFill(z, depth, spec),
        stroke: defaultEdgeStroke(z, depth, spec),
        strokeWidth: 0.42,
      }),
      top: (_x: number, _y: number, z: number) => ({
        fill: ceilingFill(z, depth, spec),
        stroke: glowColor(z, depth, spec, 0.18),
        strokeWidth: 0.72,
        filter: "url(#demo2-glow-soft)",
      }),
    },
  });

  engine.addGeometry({
    type: "box",
    position: [wallX, 1, 0],
    size: [1, height, depth],
    meta: { zone, part: "wall" },
    style: {
      default: (_x: number, _y: number, z: number) => ({
        fill: wallFill(z, depth, spec),
        stroke: defaultEdgeStroke(z, depth, spec),
        strokeWidth: 0.42,
      }),
      [litWallFace]: (_x: number, y: number, z: number) => ({
        fill: wallFill(z, depth, spec),
        stroke: glowColor(z + y * 0.45, depth, spec, 0.1),
        strokeWidth: 0.72,
        filter: "url(#demo2-glow-soft)",
      }),
    },
  });

  engine.addGeometry({
    type: "box",
    position: [startX, 1, depth - 1],
    size: [chamberWidth, height, 1],
    meta: { zone, part: "back" },
    style: {
      default: {
        fill: "rgba(19, 16, 28, 0.96)",
        stroke: "rgba(255, 255, 255, 0.24)",
        strokeWidth: 0.48,
      },
      front: {
        fill: "rgba(248, 250, 255, 0.06)",
        stroke: "rgba(255, 255, 255, 0.72)",
        strokeWidth: 0.66,
        filter: "url(#demo2-glow-soft)",
      },
    },
  });
}

function resolveVariant(root: HTMLElement): TunnelVariantSpec {
  const variantId = (root.dataset.demo2Variant ?? "ember-hall") as TunnelVariantId;
  return variantSpecs[variantId] ?? variantSpecs["ember-hall"];
}

function applyVariantPresentation(root: HTMLElement, spec: TunnelVariantSpec): void {
  root.style.setProperty("--pp-demo2-frame-top", spec.presentation.frameTop);
  root.style.setProperty("--pp-demo2-frame-bottom", spec.presentation.frameBottom);
  root.style.setProperty("--pp-demo2-halo", spec.presentation.halo);
  root.style.setProperty("--pp-demo2-haze-center", spec.presentation.haze);
  root.style.setProperty("--pp-demo2-beam-left", spec.presentation.beamLeft);
  root.style.setProperty("--pp-demo2-beam-right", spec.presentation.beamRight);
  root.style.setProperty("--pp-demo2-beam-opacity", spec.presentation.beamOpacity);
  root.style.setProperty("--pp-demo2-beam-color", spec.presentation.beamColor);
  root.style.setProperty("--pp-demo2-slit-top", spec.presentation.slitTop);
  root.style.setProperty("--pp-demo2-slit-bottom", spec.presentation.slitBottom);
  root.style.setProperty("--pp-demo2-monolith-width", spec.presentation.monolithWidth);
}

function renderTunnelScene(root: HTMLElement, sceneRoot: HTMLElement): void {
  if (!window.Heerich) {
    sceneRoot.innerHTML = `<div class="rg-scene-error"><strong>Heerich is unavailable.</strong></div>`;
    return;
  }

  const spec = resolveVariant(root);
  const compact = sceneRoot.clientWidth < 900;
  const chamberWidth = compact ? spec.scene.chamberWidth.compact : spec.scene.chamberWidth.wide;
  const height = compact ? spec.scene.height.compact : spec.scene.height.wide;
  const depth = compact ? spec.scene.depth.compact : spec.scene.depth.wide;
  const gap = compact ? spec.scene.gap.compact : spec.scene.gap.wide;

  applyVariantPresentation(root, spec);

  const tile = compact ? spec.scene.tile.compact : spec.scene.tile.wide;

  const engine = new window.Heerich({
    tile: [tile, tile],
    camera: {
      type: "perspective",
      position: [spec.scene.cameraX, compact ? spec.scene.cameraY.compact : spec.scene.cameraY.wide],
      distance: compact ? spec.scene.cameraDistance.compact : spec.scene.cameraDistance.wide,
    },
    style: {
      fill: "rgba(30, 11, 17, 0.96)",
      stroke: "rgba(255, 153, 34, 0.46)",
      strokeWidth: compact ? 0.58 : 0.64,
    },
  }) as HeerichInstance;

  addTunnelChamber(engine, spec, "left", chamberWidth, height, depth, gap);
  addTunnelChamber(engine, spec, "right", chamberWidth, height, depth, gap);

  sceneRoot.innerHTML = engine.toSVG({
    padding: compact ? 16 : 24,
    prepend: buildGlowDefs(),
  });
}

function mountAmbientMotion(root: HTMLElement, refs: MotionRefs): Array<ReturnType<typeof animate>> {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    root.style.setProperty("--pp-demo2-glow", "0.22");
    return [];
  }

  const sceneAnimation = animate(refs.sceneRoot, {
    translateY: [0, -8],
    scale: [1, 1.012],
    duration: 3200,
    alternate: true,
    loop: true,
    ease: "inOutSine",
  });

  const glowState = { value: 0.18 };
  const glowAnimation = animate(glowState, {
    value: [0.18, 0.38],
    duration: 2800,
    alternate: true,
    loop: true,
    ease: "inOutSine",
    onUpdate: () => {
      root.style.setProperty("--pp-demo2-glow", glowState.value.toFixed(3));
    },
  });

  const beamAnimation =
    refs.beams.length === 0
      ? undefined
      : animate(refs.beams, {
          opacity: [
            { from: 0.18, to: 0.44 },
            { from: 0.44, to: 0.24 },
          ],
          translateY: [
            { from: -18, to: 8 },
            { from: 8, to: -10 },
          ],
          scaleY: [0.94, 1.04],
          duration: 3600,
          delay: (_target, index) => index * 160,
          alternate: true,
          loop: true,
          ease: "inOutSine",
        });

  const monolithAnimation = refs.monolith
    ? animate(refs.monolith, {
        translateY: [0, -5],
        scale: [1, 1.01],
        duration: 3000,
        alternate: true,
        loop: true,
        ease: "inOutSine",
      })
    : undefined;

  const slitAnimation = refs.slit
    ? animate(refs.slit, {
        opacity: [0.58, 0.96],
        scaleY: [0.96, 1.08],
        duration: 2100,
        alternate: true,
        loop: true,
        ease: "inOutQuad",
      })
    : undefined;

  return [sceneAnimation, glowAnimation, beamAnimation, monolithAnimation, slitAnimation].filter(
    (animation): animation is ReturnType<typeof animate> => Boolean(animation),
  );
}

export function mountDemo2Tunnel(root: HTMLElement): () => void {
  const sceneRoot = root.querySelector<HTMLElement>("[data-demo2-scene]");
  if (!sceneRoot) return () => undefined;

  const refs: MotionRefs = {
    sceneRoot,
    beams: Array.from(root.querySelectorAll<HTMLElement>("[data-demo2-beam]")),
    monolith: root.querySelector<HTMLElement>("[data-demo2-monolith]"),
    slit: root.querySelector<HTMLElement>("[data-demo2-slit]"),
  };

  let frame = 0;

  const render = () => {
    if (frame) window.cancelAnimationFrame(frame);
    frame = window.requestAnimationFrame(() => {
      frame = 0;
      renderTunnelScene(root, sceneRoot);
    });
  };

  render();

  const animations = mountAmbientMotion(root, refs);
  const resizeObserver =
    typeof ResizeObserver === "undefined"
      ? null
      : new ResizeObserver(() => {
          render();
        });

  resizeObserver?.observe(root);

  return () => {
    if (frame) window.cancelAnimationFrame(frame);
    resizeObserver?.disconnect();
    animations.forEach((animation) => animation.cancel());
    refs.sceneRoot.style.transform = "";
    refs.sceneRoot.style.opacity = "";
    refs.beams.forEach((beam) => {
      beam.style.opacity = "";
      beam.style.transform = "";
    });
    refs.monolith?.style.removeProperty("transform");
    refs.slit?.style.removeProperty("opacity");
    refs.slit?.style.removeProperty("transform");
  };
}
