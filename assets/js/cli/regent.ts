#!/usr/bin/env node
import process from "node:process";

import { executeRegentCommand, parseRegentCommand, usageText } from "./regent_cli.ts";

async function main() {
  const command = parseRegentCommand(process.argv.slice(2), process.cwd());

  if (command.kind === "help") {
    process.stdout.write(`${usageText()}\n`);
    return;
  }

  writeJson(await executeRegentCommand(command));
}

function writeJson(value: unknown) {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

void main().catch((error) => {
  const message = error instanceof Error ? error.message : "Command failed.";
  process.stderr.write(`${JSON.stringify({ ok: false, error: message }, null, 2)}\n`);
  process.exitCode = 1;
});
