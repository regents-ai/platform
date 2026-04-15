import type { TokenCardManifestEntry } from "./token_card_types.ts";

export function animationFilename(entry: TokenCardManifestEntry) {
  const tokenId = String(entry.tokenId).padStart(4, "0");
  return `regents-club-${tokenId}.mp4`;
}

export function tokenCardMediaLinks(entry: TokenCardManifestEntry) {
  return {
    animationHref: entry.animationPath,
    animationDownloadName: animationFilename(entry),
    previewHref: entry.imagePath,
  };
}
