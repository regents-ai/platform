import express from "express";
import hermesAdapter from "hermes-paperclip-adapter";

const app = express();
app.use(express.json({ limit: "1mb" }));

const state = {
  adapterType: process.env.FORMATION_HERMES_ADAPTER_TYPE || "hermes_local",
  adapterRegistered: Boolean(hermesAdapter),
  deploymentMode: process.env.PAPERCLIP_DEPLOYMENT_MODE || "authenticated",
  port: Number(process.env.PAPERCLIP_HTTP_PORT || "3100"),
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
    toolsets: JSON.parse(process.env.FORMATION_HERMES_TOOLSETS || "[]"),
    runtime_plugins: JSON.parse(process.env.FORMATION_HERMES_RUNTIME_PLUGINS || "[]"),
    shared_skills: JSON.parse(process.env.FORMATION_HERMES_SHARED_SKILLS || "[]"),
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
