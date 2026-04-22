#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"

WORKSPACE_DIR="${FORMATION_WORKSPACE_INSTALL_DIR:-/app/hermes-workspace}"
RUNTIME_ENV_FILE="${FORMATION_WORKSPACE_RUNTIME_ENV_FILE:-$WORKSPACE_DIR/runtime.env}"
LAUNCH_SCRIPT_PATH="${FORMATION_WORKSPACE_LAUNCH_SCRIPT:-/app/bootstrap/launch_workspace.sh}"
SERVICE_LOG_PATH="${FORMATION_WORKSPACE_SERVICE_LOG:-/tmp/hermes-workspace-service.log}"
HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
SESSION_STORE_PATH="${FORMATION_WORKSPACE_SESSION_STORE:-$HERMES_HOME_DIR/workspace-sessions.json}"
GATEWAY_PORT="${FORMATION_GATEWAY_PORT:-8642}"
WORKSPACE_PORT="${FORMATION_WORKSPACE_PORT:-3000}"
NEW_PASSWORD="${1:-${FORMATION_WORKSPACE_PASSWORD_NEW:-}}"

usage() {
  echo "Usage: $0 <new-password>" >&2
  exit 64
}

if [[ -z "$NEW_PASSWORD" ]]; then
  usage
fi

if [[ ! -f "$RUNTIME_ENV_FILE" ]]; then
  echo "Runtime settings file not found: $RUNTIME_ENV_FILE" >&2
  exit 1
fi

if [[ ! -x "$LAUNCH_SCRIPT_PATH" ]]; then
  echo "Launcher not found or not executable: $LAUNCH_SCRIPT_PATH" >&2
  exit 1
fi

tmp_env="$(mktemp)"
trap 'rm -f "$tmp_env"' EXIT

grep -vE '^HERMES_PASSWORD=' "$RUNTIME_ENV_FILE" >"$tmp_env" || true
printf 'HERMES_PASSWORD=%s\n' "$NEW_PASSWORD" >>"$tmp_env"
mv "$tmp_env" "$RUNTIME_ENV_FILE"
chmod 600 "$RUNTIME_ENV_FILE" 2>/dev/null || true

rm -f "$SESSION_STORE_PATH"

if pgrep -f "$LAUNCH_SCRIPT_PATH" >/dev/null 2>&1; then
  pkill -f "$LAUNCH_SCRIPT_PATH" >/dev/null 2>&1 || true
  sleep 2
fi

nohup "$LAUNCH_SCRIPT_PATH" >"$SERVICE_LOG_PATH" 2>&1 &

if command -v curl >/dev/null 2>&1; then
  for _ in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:${GATEWAY_PORT}/health" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  curl -fsS "http://127.0.0.1:${GATEWAY_PORT}/health" >/dev/null

  for _ in $(seq 1 60); do
    if curl -fsSI "http://127.0.0.1:${WORKSPACE_PORT}/" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  curl -fsSI "http://127.0.0.1:${WORKSPACE_PORT}/" >/dev/null
fi

cat <<EOF
Workspace password updated.
Saved settings: $RUNTIME_ENV_FILE
Cleared sessions: $SESSION_STORE_PATH
Restarted launcher: $LAUNCH_SCRIPT_PATH
EOF
