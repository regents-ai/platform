#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"

WORKSPACE_DIR="${FORMATION_WORKSPACE_INSTALL_DIR:-/app/hermes-workspace}"
RUNTIME_ENV_FILE="${FORMATION_WORKSPACE_RUNTIME_ENV_FILE:-$WORKSPACE_DIR/runtime.env}"
GATEWAY_PORT="${FORMATION_GATEWAY_PORT:-8642}"
WORKSPACE_PORT="${FORMATION_WORKSPACE_PORT:-3000}"

if [[ -f "$RUNTIME_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$RUNTIME_ENV_FILE"
  set +a
fi

gateway_pid=""
workspace_pid=""

cleanup() {
  if [[ -n "$workspace_pid" ]] && kill -0 "$workspace_pid" 2>/dev/null; then
    kill "$workspace_pid" 2>/dev/null || true
    wait "$workspace_pid" 2>/dev/null || true
  fi

  if [[ -n "$gateway_pid" ]] && kill -0 "$gateway_pid" 2>/dev/null; then
    kill "$gateway_pid" 2>/dev/null || true
    wait "$gateway_pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

cd "$WORKSPACE_DIR"

API_SERVER_ENABLED=true \
API_SERVER_HOST=127.0.0.1 \
API_SERVER_PORT="$GATEWAY_PORT" \
hermes gateway run &
gateway_pid="$!"

for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${GATEWAY_PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

curl -fsS "http://127.0.0.1:${GATEWAY_PORT}/health" >/dev/null

HOST="${HOST:-0.0.0.0}" \
PORT="${PORT:-$WORKSPACE_PORT}" \
pnpm start &
workspace_pid="$!"

wait -n "$workspace_pid" "$gateway_pid"
