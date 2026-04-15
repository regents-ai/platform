import assert from "node:assert/strict";
import test from "node:test";

import { animationFilename, tokenCardMediaLinks } from "./shader/token_card_media.ts";

test("token card media links use the hosted animation file and preview image", () => {
  const entry = {
    tokenId: 1,
    name: "Regents Club #1",
    shaderId: "radiant2",
    shaderTitle: "Radiant 2",
    defineValues: {},
    versionLabel: "0001.v1",
    imagePath: "/images/animata/cards/1.png",
    pagePath: "/cards/regents-club/1",
    animationPath: "/images/animata/cards/1.mp4",
  };

  assert.equal(animationFilename(entry), "regents-club-0001.mp4");
  assert.deepEqual(tokenCardMediaLinks(entry), {
    animationHref: "/images/animata/cards/1.mp4",
    animationDownloadName: "regents-club-0001.mp4",
    previewHref: "/images/animata/cards/1.png",
  });
});
