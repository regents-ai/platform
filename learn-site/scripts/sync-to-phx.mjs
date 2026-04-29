import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dist = path.join(root, "dist");
const staticRoot = path.resolve(root, "..", "priv", "static");

const entries = [
  "learn",
  "glossary",
  "source",
  "updates",
  "pagefind",
  "_astro",
  "llms.txt",
  "ai-index.md",
  "regents-facts.json"
];

const generatedRootPatterns = [
  /^llms(?:-[0-9a-f]+)?\.txt$/,
  /^ai-index(?:-[0-9a-f]+)?\.md$/,
  /^regents-facts(?:-[0-9a-f]+)?\.json$/
];

for (const entry of fs.readdirSync(staticRoot)) {
  if (generatedRootPatterns.some((pattern) => pattern.test(entry))) {
    fs.rmSync(path.join(staticRoot, entry), { recursive: true, force: true });
  }
}

for (const entry of entries) {
  const source = path.join(dist, entry);
  const destination = path.join(staticRoot, entry);

  if (!fs.existsSync(source)) {
    throw new Error(`Expected generated corpus entry missing: ${source}`);
  }

  fs.rmSync(destination, { recursive: true, force: true });
  fs.cpSync(source, destination, { recursive: true });
}

console.log(`Synced Regents corpus assets into ${staticRoot}`);
