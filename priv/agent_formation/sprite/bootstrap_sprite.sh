#!/usr/bin/env bash
set -euo pipefail

SPRITE_CLI="${SPRITE_CLI_PATH:-sprite}"
SLUG="${FORMATION_SLUG:?missing FORMATION_SLUG}"
SPRITE_NAME="${FORMATION_SPRITE_NAME:?missing FORMATION_SPRITE_NAME}"
SPRITE_HOSTNAME="${FORMATION_SPRITE_HOSTNAME:?missing FORMATION_SPRITE_HOSTNAME}"
PUBLIC_HOSTNAME="${FORMATION_PUBLIC_HOSTNAME:?missing FORMATION_PUBLIC_HOSTNAME}"
ALLOWED_HOSTNAME="${FORMATION_ALLOWED_HOSTNAME:?missing FORMATION_ALLOWED_HOSTNAME}"
PAPERCLIP_PORT="${FORMATION_PAPERCLIP_PORT:-3100}"
PAPERCLIP_MODE="${FORMATION_PAPERCLIP_MODE:-authenticated}"
HERMES_MODEL="${FORMATION_HERMES_MODEL:-glm-5.1}"
BUNDLE_DIR="${FORMATION_BUNDLE_DIR:?missing FORMATION_BUNDLE_DIR}"
LOG_PATH="${FORMATION_LOG_PATH:-}"

run() {
  echo "+ $*"
  "$@"
}

run "$SPRITE_CLI" create "$SPRITE_NAME"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- mkdir -p /app/paperclip-regents
run "$SPRITE_CLI" cp "$BUNDLE_DIR/paperclip-regents/." "$SPRITE_NAME:/app/paperclip-regents"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "cd /app/paperclip-regents && npm ci"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "cd /app/paperclip-regents && npm install hermes-paperclip-adapter"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "cat >/app/paperclip-regents/.env <<EOF
PAPERCLIP_DEPLOYMENT_MODE=$PAPERCLIP_MODE
PAPERCLIP_BIND_HOST=0.0.0.0
PAPERCLIP_ALLOWED_HOSTNAME=$ALLOWED_HOSTNAME
PAPERCLIP_HTTP_PORT=$PAPERCLIP_PORT
FORMATION_SLUG=$SLUG
FORMATION_PUBLIC_HOSTNAME=$PUBLIC_HOSTNAME
FORMATION_HERMES_MODEL=$HERMES_MODEL
FORMATION_HERMES_ADAPTER_TYPE=${FORMATION_HERMES_ADAPTER_TYPE:-hermes_local}
FORMATION_HERMES_PERSIST_SESSION=${FORMATION_HERMES_PERSIST_SESSION:-true}
FORMATION_HERMES_TOOLSETS=${FORMATION_HERMES_TOOLSETS:-[]}
FORMATION_HERMES_RUNTIME_PLUGINS=${FORMATION_HERMES_RUNTIME_PLUGINS:-[]}
FORMATION_HERMES_SHARED_SKILLS=${FORMATION_HERMES_SHARED_SKILLS:-[]}
FORMATION_STRIPE_CUSTOMER_ID=${FORMATION_STRIPE_CUSTOMER_ID:-}
FORMATION_STRIPE_SUBSCRIPTION_ID=${FORMATION_STRIPE_SUBSCRIPTION_ID:-}
EOF"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "cd /app/paperclip-regents && nohup node server.mjs >/tmp/paperclip-regents.log 2>&1 &"
run "$SPRITE_CLI" services create "$SPRITE_NAME" paperclip --http-port "$PAPERCLIP_PORT"
run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "until curl -fsS http://127.0.0.1:$PAPERCLIP_PORT/health >/dev/null; do sleep 2; done"
BOOTSTRAP_JSON="$(run "$SPRITE_CLI" exec "$SPRITE_NAME" -- sh -lc "cd /app/paperclip-regents && node bootstrap_company.mjs")"
CHECKPOINT_REF="$("$SPRITE_CLI" checkpoint create "$SPRITE_NAME" --comment "agent formation bootstrap" | tail -n 1)"

cat <<EOF
{"sprite_url":"https://$SPRITE_HOSTNAME","paperclip_url":"https://$SPRITE_HOSTNAME:$PAPERCLIP_PORT","paperclip_company_id":"${SLUG}-company","paperclip_agent_id":"${SLUG}-hermes","checkpoint_ref":"$CHECKPOINT_REF","bootstrap":"$BOOTSTRAP_JSON","log_path":"$LOG_PATH"}
EOF
