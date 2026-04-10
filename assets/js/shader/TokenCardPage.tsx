import * as React from "react";

import { RegentTokenCard } from "./RegentTokenCard.tsx";
import { ShaderCanvas } from "./ShaderCanvas.tsx";
import { buildShaderFragmentSource, getShaderById } from "./lib/catalog.ts";
import type { TokenCardManifestEntry } from "./token_card_types.ts";

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
  const content = <TokenCardSurface entry={entry} active={active} layout={layout} />;

  if (layout === "embedded") {
    return content;
  }

  return <main className="rtc-page">{content}</main>;
}
