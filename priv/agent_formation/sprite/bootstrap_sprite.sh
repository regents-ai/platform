#!/usr/bin/env bash
set -euo pipefail

SPRITE_CLI="${SPRITE_CLI_PATH:-sprite}"
SLUG="${FORMATION_SLUG:?missing FORMATION_SLUG}"
SPRITE_NAME="${FORMATION_SPRITE_NAME:?missing FORMATION_SPRITE_NAME}"
SPRITE_HOSTNAME="${FORMATION_SPRITE_HOSTNAME:?missing FORMATION_SPRITE_HOSTNAME}"
PUBLIC_HOSTNAME="${FORMATION_PUBLIC_HOSTNAME:?missing FORMATION_PUBLIC_HOSTNAME}"
ALLOWED_HOSTS="${FORMATION_ALLOWED_HOSTS:?missing FORMATION_ALLOWED_HOSTS}"
WORKSPACE_PORT="${FORMATION_WORKSPACE_PORT:-3000}"
GATEWAY_PORT="${FORMATION_GATEWAY_PORT:-8642}"
HERMES_MODEL="${FORMATION_HERMES_MODEL:-glm-5.1}"
BUNDLE_DIR="${FORMATION_BUNDLE_DIR:?missing FORMATION_BUNDLE_DIR}"
LOG_PATH="${FORMATION_LOG_PATH:-}"
WORKSPACE_REPO="${FORMATION_WORKSPACE_REPO:-https://github.com/outsourc-e/hermes-workspace.git}"
WORKSPACE_REF="${FORMATION_WORKSPACE_REF:-main}"

run() {
  echo "+ $*"
  "$@"
}

run "$SPRITE_CLI" create "$SPRITE_NAME"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- mkdir -p /app/bin /app/company /app/bootstrap
run "$SPRITE_CLI" cp "$BUNDLE_DIR/hermes-workspace/seed_company_workspace.mjs" "$SPRITE_NAME:/app/bootstrap/seed_company_workspace.mjs"
run "$SPRITE_CLI" cp "$BUNDLE_DIR/hermes-workspace/launch_workspace.sh" "$SPRITE_NAME:/app/bootstrap/launch_workspace.sh"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "chmod +x /app/bootstrap/launch_workspace.sh"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "export PATH=\"\$HOME/.hermes/bin:\$HOME/.local/bin:\$PATH\"; if ! command -v pnpm >/dev/null 2>&1; then corepack enable >/dev/null 2>&1 || true; corepack prepare pnpm@latest --activate >/dev/null 2>&1 || npm install -g pnpm; fi; if ! command -v hermes >/dev/null 2>&1; then curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash; export PATH=\"\$HOME/.hermes/bin:\$HOME/.local/bin:\$PATH\"; fi; rm -rf /app/hermes-workspace; git clone --depth 1 '$WORKSPACE_REPO' /app/hermes-workspace; git -C /app/hermes-workspace checkout '$WORKSPACE_REF'; cd /app/hermes-workspace; pnpm install --frozen-lockfile; pnpm build"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "HERMES_ENV_PATH=\"\$(hermes config env-path 2>/dev/null || true)\"; if [ -z \"\$HERMES_ENV_PATH\" ]; then HERMES_ENV_PATH=\"\$HOME/.hermes/.env\"; fi; mkdir -p \"\$(dirname \"\$HERMES_ENV_PATH\")\"; touch \"\$HERMES_ENV_PATH\"; grep -vE '^API_SERVER_(ENABLED|HOST|PORT)=' \"\$HERMES_ENV_PATH\" >\"\$HERMES_ENV_PATH.tmp\" || true; mv \"\$HERMES_ENV_PATH.tmp\" \"\$HERMES_ENV_PATH\"; cat >>\"\$HERMES_ENV_PATH\" <<EOF
API_SERVER_ENABLED=true
API_SERVER_HOST=127.0.0.1
API_SERVER_PORT=$GATEWAY_PORT
EOF"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "cat >/app/hermes-workspace/runtime.env <<EOF
HERMES_API_URL=http://127.0.0.1:$GATEWAY_PORT
HERMES_ALLOWED_HOSTS=$ALLOWED_HOSTS
PORT=$WORKSPACE_PORT
HOST=0.0.0.0
FORMATION_WORKSPACE_INSTALL_DIR=/app/hermes-workspace
FORMATION_WORKSPACE_RUNTIME_ENV_FILE=/app/hermes-workspace/runtime.env
FORMATION_GATEWAY_PORT=$GATEWAY_PORT
FORMATION_WORKSPACE_PORT=$WORKSPACE_PORT
EOF
if [ -n \"${FORMATION_WORKSPACE_PASSWORD:-}\" ]; then
  printf 'HERMES_PASSWORD=%s\n' \"${FORMATION_WORKSPACE_PASSWORD}\" >>/app/hermes-workspace/runtime.env
fi"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "FORMATION_SLUG='$SLUG' FORMATION_PUBLIC_HOSTNAME='$PUBLIC_HOSTNAME' FORMATION_HERMES_MODEL='$HERMES_MODEL' FORMATION_HERMES_ADAPTER_TYPE='${FORMATION_HERMES_ADAPTER_TYPE:-stock}' FORMATION_HERMES_PERSIST_SESSION='${FORMATION_HERMES_PERSIST_SESSION:-true}' FORMATION_HERMES_TOOLSETS='${FORMATION_HERMES_TOOLSETS:-[]}' FORMATION_HERMES_RUNTIME_PLUGINS='${FORMATION_HERMES_RUNTIME_PLUGINS:-[]}' FORMATION_HERMES_SHARED_SKILLS='${FORMATION_HERMES_SHARED_SKILLS:-[]}' FORMATION_HERMES_COMMAND='${FORMATION_HERMES_COMMAND:-/app/bin/hermes-company}' FORMATION_HERMES_PROMPT_TEMPLATE_VERSION='${FORMATION_HERMES_PROMPT_TEMPLATE_VERSION:-company-workspace-prompt-v1}' FORMATION_HERMES_PROMPT_TEMPLATE_JSON='${FORMATION_HERMES_PROMPT_TEMPLATE_JSON:-\"\"}' FORMATION_WORKSPACE_PATH='${FORMATION_WORKSPACE_PATH:-/app/company}' FORMATION_WORKSPACE_SEED_VERSION='${FORMATION_WORKSPACE_SEED_VERSION:-company-workspace-v1}' FORMATION_TEMPLATE_KEY='${FORMATION_TEMPLATE_KEY:-}' FORMATION_TEMPLATE_PUBLIC_NAME='${FORMATION_TEMPLATE_PUBLIC_NAME:-}' FORMATION_TEMPLATE_SUMMARY=\"$(printf '%s' "${FORMATION_TEMPLATE_SUMMARY:-}" | tr '\n' ' ')\" FORMATION_TEMPLATE_COMPANY_PURPOSE=\"$(printf '%s' "${FORMATION_TEMPLATE_COMPANY_PURPOSE:-}" | tr '\n' ' ')\" FORMATION_TEMPLATE_WORKER_ROLE=\"$(printf '%s' "${FORMATION_TEMPLATE_WORKER_ROLE:-}" | tr '\n' ' ')\" FORMATION_TEMPLATE_SERVICES='${FORMATION_TEMPLATE_SERVICES:-[]}' FORMATION_TEMPLATE_CONNECTION_DEFAULTS='${FORMATION_TEMPLATE_CONNECTION_DEFAULTS:-[]}' FORMATION_TEMPLATE_RECOMMENDED_NETWORK_DOMAINS='${FORMATION_TEMPLATE_RECOMMENDED_NETWORK_DOMAINS:-[]}' FORMATION_TEMPLATE_CHECKPOINT_MOMENTS='${FORMATION_TEMPLATE_CHECKPOINT_MOMENTS:-[]}' node /app/bootstrap/seed_company_workspace.mjs"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "nohup /app/bootstrap/launch_workspace.sh >/tmp/hermes-workspace-service.log 2>&1 &"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "until curl -fsS http://127.0.0.1:$GATEWAY_PORT/health >/dev/null; do sleep 2; done"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "until curl -fsSI http://127.0.0.1:$WORKSPACE_PORT/ >/dev/null; do sleep 2; done"
run "$SPRITE_CLI" services create "$SPRITE_NAME" hermes-workspace --http-port "$WORKSPACE_PORT"
CHECKPOINT_REF="$("$SPRITE_CLI" checkpoint create "$SPRITE_NAME" --comment "agent formation bootstrap" | tail -n 1)"

cat <<EOF
{"sprite_url":"https://$SPRITE_HOSTNAME","workspace_url":"https://$SPRITE_HOSTNAME","checkpoint_ref":"$CHECKPOINT_REF","workspace_path":"${FORMATION_WORKSPACE_PATH:-/app/company}","workspace_seed_version":"${FORMATION_WORKSPACE_SEED_VERSION:-company-workspace-v1}","hermes_command":"${FORMATION_HERMES_COMMAND:-/app/bin/hermes-company}","prompt_template_version":"${FORMATION_HERMES_PROMPT_TEMPLATE_VERSION:-company-workspace-prompt-v1}","log_path":"$LOG_PATH"}
EOF
