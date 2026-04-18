import { access, chmod, mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

function readJsonEnv(name, fallback) {
  const raw = process.env[name];

  if (!raw) {
    return fallback;
  }

  try {
    return JSON.parse(raw);
  } catch (_error) {
    return fallback;
  }
}

function bulletList(items, emptyLine) {
  if (!Array.isArray(items) || items.length === 0) {
    return `- ${emptyLine}`;
  }

  return items.map((item) => `- ${item}`).join("\n");
}

function serviceList(services) {
  if (!Array.isArray(services) || services.length === 0) {
    return "- No services were seeded during formation.";
  }

  return services
    .map((service) => {
      const name = service?.name || service?.slug || "Service";
      const summary = service?.summary || "No summary saved.";
      const price = service?.price_label ? ` (${service.price_label})` : "";
      return `- ${name}${price}: ${summary}`;
    })
    .join("\n");
}

function connectionList(connections) {
  if (!Array.isArray(connections) || connections.length === 0) {
    return "- No starter connections were seeded during formation.";
  }

  return connections
    .map((connection) => {
      const name = connection?.display_name || connection?.kind || "Connection";
      const status = connection?.status || "unknown";
      return `- ${name}: ${status}`;
    })
    .join("\n");
}

const slug = process.env.FORMATION_SLUG || "agent";
const workspacePath = process.env.FORMATION_WORKSPACE_PATH || "/app/company";
const workspaceSeedVersion =
  process.env.FORMATION_WORKSPACE_SEED_VERSION || "company-workspace-v1";
const hermesCommand = process.env.FORMATION_HERMES_COMMAND || "/app/bin/hermes-company";
const templateKey = process.env.FORMATION_TEMPLATE_KEY || "";
const templatePublicName = process.env.FORMATION_TEMPLATE_PUBLIC_NAME || "";
const templateSummary = process.env.FORMATION_TEMPLATE_SUMMARY || "";
const companyPurpose = process.env.FORMATION_TEMPLATE_COMPANY_PURPOSE || "";
const workerRole = process.env.FORMATION_TEMPLATE_WORKER_ROLE || "";
const services = readJsonEnv("FORMATION_TEMPLATE_SERVICES", []);
const connectionDefaults = readJsonEnv("FORMATION_TEMPLATE_CONNECTION_DEFAULTS", []);
const recommendedDomains = readJsonEnv("FORMATION_TEMPLATE_RECOMMENDED_NETWORK_DOMAINS", []);
const checkpointMoments = readJsonEnv("FORMATION_TEMPLATE_CHECKPOINT_MOMENTS", []);
const createdAt = new Date().toISOString();

const notesPath = path.join(workspacePath, "NOTES");
const runbooksPath = path.join(workspacePath, "RUNBOOKS");
const wrapperPath = hermesCommand;

await mkdir(workspacePath, { recursive: true });
await mkdir(notesPath, { recursive: true });
await mkdir(runbooksPath, { recursive: true });
await mkdir(path.dirname(wrapperPath), { recursive: true });

const workspaceTitle = `${slug} company workspace`;

const files = new Map([
  [
    path.join(workspacePath, "AGENTS.md"),
    `# Company Workspace Rules

This workspace is the durable home for the company worker created during platform formation.

## How to work here

- Start with [HOME.md](HOME.md) and [PLATFORM_CONTEXT.md](PLATFORM_CONTEXT.md).
- Treat this workspace as the durable record for the company.
- Add one-line queued work to [BACKLOG.md](BACKLOG.md).
- Append durable milestones and outcomes to [LOG.md](LOG.md).
- Record settled choices in [DECISIONS.md](DECISIONS.md).
- Keep rough work in [NOTES/](NOTES/README.md) until it proves worth keeping.
- Put repeatable operator procedures in [RUNBOOKS/](RUNBOOKS/README.md).
- Avoid creating extra top-level folders unless the work clearly needs a new durable home.
`,
  ],
  [
    path.join(workspacePath, "HOME.md"),
    `# ${workspaceTitle}

## Purpose

${companyPurpose || "This workspace holds the durable operating context for the company worker."}

## Main worker

${workerRole || "This worker handles the main company work for the selected template."}

## Start here

- Read [AGENTS.md](AGENTS.md) for local working rules.
- Read [PLATFORM_CONTEXT.md](PLATFORM_CONTEXT.md) for the template snapshot created during formation.
- Check [BACKLOG.md](BACKLOG.md) for one-line queued work.
- Check [DECISIONS.md](DECISIONS.md) for settled choices.
- Append durable progress to [LOG.md](LOG.md).
`,
  ],
  [
    path.join(workspacePath, "PLATFORM_CONTEXT.md"),
    `# Platform Context

## Formation snapshot

- Company slug: \`${slug}\`
- Template key: \`${templateKey || "unknown"}\`
- Template name: ${templatePublicName || "Unknown template"}
- Workspace path: \`${workspacePath}\`
- Hermes command: \`${hermesCommand}\`
- Seed version: \`${workspaceSeedVersion}\`

## Public summary

${templateSummary || "No summary was saved during formation."}

## Worker role

${workerRole || "No worker role was saved during formation."}

## Service menu

${serviceList(services)}

## Connection defaults

${connectionList(connectionDefaults)}

## Recommended network domains

${bulletList(recommendedDomains, "No recommended domains were saved during formation.")}

## Checkpoint moments

${bulletList(checkpointMoments, "No checkpoint moments were saved during formation.")}
`,
  ],
  [
    path.join(workspacePath, "INDEX.md"),
    `# Index

- [HOME.md](HOME.md): front door for this company workspace
- [AGENTS.md](AGENTS.md): local operating rules
- [PLATFORM_CONTEXT.md](PLATFORM_CONTEXT.md): formation snapshot and company context
- [LOG.md](LOG.md): append-only durable chronology
- [BACKLOG.md](BACKLOG.md): one-line pending work
- [DECISIONS.md](DECISIONS.md): settled choices
- [NOTES/README.md](NOTES/README.md): short-lived working notes
- [RUNBOOKS/README.md](RUNBOOKS/README.md): repeatable operator procedures
`,
  ],
  [
    path.join(workspacePath, "LOG.md"),
    `# Log

## [${createdAt}] workspace seeded
- Created the default company workspace.
- Seed version: \`${workspaceSeedVersion}\`
- Template key: \`${templateKey || "unknown"}\`
`,
  ],
  [
    path.join(workspacePath, "BACKLOG.md"),
    `# Backlog

- Add the first company task here in one line.
`,
  ],
  [
    path.join(workspacePath, "DECISIONS.md"),
    `# Decisions

- No settled decisions yet.
`,
  ],
  [
    path.join(notesPath, "README.md"),
    `# Notes

Use this folder for short-lived working notes. Promote durable outcomes into the main workspace files when they matter.
`,
  ],
  [
    path.join(runbooksPath, "README.md"),
    `# Runbooks

Use this folder for repeatable operator procedures that are worth keeping.
`,
  ],
]);

async function writeFileIfMissing(filePath, content) {
  try {
    await access(filePath);
    return false;
  } catch (_error) {
    await writeFile(filePath, content, "utf8");
    return true;
  }
}

const createdFiles = [];

for (const [filePath, content] of files.entries()) {
  if (await writeFileIfMissing(filePath, content)) {
    createdFiles.push(filePath);
  }
}

await writeFile(
  wrapperPath,
  `#!/usr/bin/env sh
set -eu
cd ${workspacePath}
exec hermes "$@"
`,
  "utf8",
);

await chmod(wrapperPath, 0o755);

console.log(
  JSON.stringify({
    ok: true,
    workspace_path: workspacePath,
    workspace_seed_version: workspaceSeedVersion,
    hermes_command: hermesCommand,
    files: Array.from(files.keys()),
    created_files: createdFiles,
  }),
);
