import { animate } from "animejs";
import * as React from "react";

import { RegentTokenCard } from "./RegentTokenCard.tsx";
import { ShaderCanvas } from "./ShaderCanvas.tsx";
import { buildShaderFragmentSource, getShaderById } from "./lib/catalog.ts";
import { tokenCardMediaLinks } from "./token_card_media.ts";
import type { TokenCardManifestEntry } from "./token_card_types.ts";

function pulseElement(element: HTMLElement | null) {
  if (!element) return;

  animate(element, {
    scale: [1, 0.98, 1],
    duration: 260,
    ease: "outQuart",
  });
}

function revealElement(element: HTMLElement | null) {
  if (!element) return;

  animate(element, {
    opacity: [0, 1],
    translateY: [14, 0],
    duration: 320,
    ease: "outQuart",
  });
}

function TokenCardSurface({
  entry,
  active = true,
  layout = "page",
}: {
  entry: TokenCardManifestEntry;
  active?: boolean;
  layout?: "page" | "embedded";
}) {
  const shader = getShaderById(entry.shaderId);
  const stageClassName = layout === "embedded" ? "rtc-stage rtc-stage--embedded" : "rtc-stage";

  if (!shader) {
    return (
      <section className={stageClassName} aria-label="Regents Club token card">
        <RegentTokenCard
          entry={entry}
          media={
            <div className="flex h-full items-center justify-center bg-black text-center text-xs uppercase tracking-[0.24em] text-white/70">
              Unknown shader
            </div>
          }
        />
      </section>
    );
  }

  const renderableShader = {
    ...shader,
    fragmentSource: buildShaderFragmentSource(shader, entry.defineValues),
  };

  return (
    <section className={stageClassName} aria-label={entry.name}>
      <RegentTokenCard
        entry={entry}
        media={
          <ShaderCanvas
            shader={renderableShader}
            className="h-full w-full"
            ariaLabel={`${entry.name} animated shader card`}
            devicePixelRatioCap={1.2}
            fallbackSrc={entry.imagePath}
            paused={!active}
            runtimeMode={layout === "embedded" ? "when-active" : "always"}
          />
        }
      />
    </section>
  );
}

export function TokenCardPage({
  entry,
  active = true,
  layout = "page",
}: {
  entry: TokenCardManifestEntry;
  active?: boolean;
  layout?: "page" | "embedded";
}) {
  const previewRef = React.useRef<HTMLDivElement | null>(null);
  const primaryActionRef = React.useRef<HTMLAnchorElement | null>(null);

  React.useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      revealElement(previewRef.current);
      pulseElement(primaryActionRef.current);
    });

    return () => window.cancelAnimationFrame(frame);
  }, []);

  const content = <TokenCardSurface entry={entry} active={active} layout={layout} />;
  const mediaLinks = tokenCardMediaLinks(entry);

  if (layout === "embedded") {
    return content;
  }

  return (
    <main className="rtc-page">
      <div className="flex w-full max-w-6xl flex-col items-center justify-center gap-6 lg:flex-row lg:items-start lg:gap-8">
        <div>{content}</div>

        <section
          className="w-full max-w-md rounded-[1.6rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--card)_94%,var(--background)_6%)] p-5 shadow-[0_26px_70px_-42px_color-mix(in_oklch,var(--brand-charcoal,#315569)_40%,transparent)]"
          aria-label="Token card saves"
        >
          <div className="grid gap-3">
            <div className="grid gap-2">
              <p
                className="text-[0.7rem] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]"
                style={{ fontFamily: "\"GeistPixel Square\", sans-serif" }}
              >
                Animated Card
              </p>

              <h2
                className="text-[1.55rem] leading-[1.1] text-[color:var(--foreground)]"
                style={{ fontFamily: "\"GeistPixel Circle\", sans-serif" }}
              >
                Save the moving version
              </h2>

              <p
                className="text-sm leading-6 text-[color:var(--muted-foreground)]"
                style={{ fontFamily: "\"GeistPixel Square\", sans-serif" }}
              >
                This page keeps the motion file ready beside the live card, so you can watch it,
                open it in a new tab, or save it directly.
              </p>
            </div>

            <div ref={previewRef} className="grid gap-3 opacity-0">
              <div className="overflow-hidden rounded-[1.15rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-black">
                <video
                  src={mediaLinks.animationHref}
                  controls
                  loop
                  autoPlay
                  muted
                  playsInline
                  preload="metadata"
                  poster={mediaLinks.previewHref}
                  className="block aspect-square w-full object-cover"
                />
              </div>

              <div className="grid gap-3 sm:grid-cols-2">
                <a
                  ref={primaryActionRef}
                  href={mediaLinks.animationHref}
                  download={mediaLinks.animationDownloadName}
                  className="inline-flex min-h-11 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--brand-paper,#fbf4de)_34%,transparent)] bg-[color:color-mix(in_oklch,var(--brand-gold,#d4a756)_24%,var(--card)_76%)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:-translate-y-[1px] hover:border-[color:var(--brand-gold,#d4a756)]"
                  style={{ fontFamily: "\"GeistPixel Square\", sans-serif" }}
                >
                  Download animation
                </a>

                <a
                  href={mediaLinks.animationHref}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex min-h-11 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_45%,transparent)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:-translate-y-[1px] hover:border-[color:var(--ring)]"
                  style={{ fontFamily: "\"GeistPixel Square\", sans-serif" }}
                >
                  Open animation
                </a>
              </div>

              <a
                href={mediaLinks.previewHref}
                target="_blank"
                rel="noreferrer"
                className="inline-flex min-h-11 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_45%,transparent)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:-translate-y-[1px] hover:border-[color:var(--ring)]"
                style={{ fontFamily: "\"GeistPixel Square\", sans-serif" }}
              >
                Open preview image
              </a>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
