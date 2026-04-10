import { promises as fs } from "node:fs";
import { execFile as execFileCallback } from "node:child_process";
import path from "node:path";
import { promisify } from "node:util";

const execFile = promisify(execFileCallback);
const DEFAULT_CARDS_DIR = path.resolve(
  process.cwd(),
  "priv/token_cards/images/animata/cards",
);

async function main() {
  const cardsDir = resolveCardsDir(process.argv.slice(2));
  const fileNames = (await fs.readdir(cardsDir))
    .filter((fileName) => /^\d+\.png$/i.test(fileName))
    .sort((left, right) => Number.parseInt(left, 10) - Number.parseInt(right, 10));

  if (fileNames.length === 0) {
    throw new Error(`No token PNGs were found in ${cardsDir}.`);
  }

  const rgbTokenIds: number[] = [];
  const rgbaTokenIds: number[] = [];
  const otherTokenIds: Array<{ tokenId: number; detail: string }> = [];

  for (const fileName of fileNames) {
    const tokenId = Number.parseInt(fileName, 10);
    const imagePath = path.join(cardsDir, fileName);
    const detail = await describePng(imagePath);

    if (detail.includes("RGBA")) {
      rgbaTokenIds.push(tokenId);
      continue;
    }

    if (/\bRGB\b/.test(detail) && !detail.includes("RGBA")) {
      rgbTokenIds.push(tokenId);
      continue;
    }

    otherTokenIds.push({ tokenId, detail });
  }

  const report = {
    ok: true,
    cardsDir,
    analyzed: fileNames.length,
    rgba: rgbaTokenIds.length,
    rgb: rgbTokenIds.length,
    other: otherTokenIds.length,
    rgbTokenIds,
    otherTokenIds,
  };

  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

function resolveCardsDir(args: string[]) {
  const cardsDirFlagIndex = args.indexOf("--cards-dir");

  if (cardsDirFlagIndex === -1) {
    return DEFAULT_CARDS_DIR;
  }

  const cardsDir = args[cardsDirFlagIndex + 1];
  if (!cardsDir) {
    throw new Error("--cards-dir requires a value.");
  }

  return path.resolve(process.cwd(), cardsDir);
}

async function describePng(imagePath: string) {
  const { stdout } = await execFile("file", [imagePath], { encoding: "utf8" });
  return stdout.trim();
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
});
