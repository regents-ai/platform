import express from "express";
import hermesAdapter from "hermes-paperclip-adapter";

const app = express();
app.use(express.json({ limit: "1mb" }));

function parseJsonEnv(name, fallback) {
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

const state = {
  adapterType: process.env.FORMATION_HERMES_ADAPTER_TYPE || "hermes_local",
  adapterRegistered: Boolean(hermesAdapter),
  deploymentMode: process.env.PAPERCLIP_DEPLOYMENT_MODE || "authenticated",
  port: Number(process.env.PAPERCLIP_HTTP_PORT || "3100"),
  workspacePath: process.env.FORMATION_WORKSPACE_PATH || "/app/company",
  workspaceSeedVersion:
    process.env.FORMATION_WORKSPACE_SEED_VERSION || "company-workspace-v1",
  hermesCommand: process.env.FORMATION_HERMES_COMMAND || "/app/bin/hermes-company",
  promptTemplateVersion:
    process.env.FORMATION_HERMES_PROMPT_TEMPLATE_VERSION || "company-workspace-prompt-v1",
  promptTemplate:
    parseJsonEnv("FORMATION_HERMES_PROMPT_TEMPLATE_JSON", null) ||
    process.env.FORMATION_HERMES_PROMPT_TEMPLATE ||
    "",
};

app.get("/health", (_req, res) => {
  res.json({ ok: true, state });
});

app.post("/internal/bootstrap-company", (req, res) => {
  const slug = process.env.FORMATION_SLUG || "agent";

  res.json({
    ok: true,
    company_id: `${slug}-company`,
    agent_id: `${slug}-hermes`,
    adapter_type: state.adapterType,
    model: process.env.FORMATION_HERMES_MODEL || "glm-5.1",
    persist_session: process.env.FORMATION_HERMES_PERSIST_SESSION !== "false",
    toolsets: parseJsonEnv("FORMATION_HERMES_TOOLSETS", []),
    runtime_plugins: parseJsonEnv("FORMATION_HERMES_RUNTIME_PLUGINS", []),
    shared_skills: parseJsonEnv("FORMATION_HERMES_SHARED_SKILLS", []),
    workspace_path: state.workspacePath,
    workspace_seed_version: state.workspaceSeedVersion,
    hermes_command: state.hermesCommand,
    prompt_template_version: state.promptTemplateVersion,
    prompt_template: state.promptTemplate,
    request: req.body ?? {},
  });
});

app.listen(state.port, "0.0.0.0", () => {
  console.log(
    JSON.stringify({
      ok: true,
      service: "paperclip-regents",
      adapter_registered: state.adapterRegistered,
      adapter_type: state.adapterType,
      port: state.port,
    }),
  );
});
