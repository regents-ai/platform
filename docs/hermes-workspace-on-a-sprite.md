# Run Hermes Workspace on a Sprite

The goal is simple: start one Sprite per company, keep the Hermes gateway private on the Sprite, expose Hermes Workspace on port `3000`, and let Sprite pause and resume control the cost.

## Done looks like this

- You can start from an empty Sprite and end with a working Workspace URL.
- The public entry point is Hermes Workspace on port `3000`.
- The Hermes gateway stays private on `127.0.0.1:8642`.
- Chat, files, memory, skills, and terminal all show up in the Workspace.
- The Sprite can sleep and wake without changing the setup.

## The shape of the runtime

- Hermes gateway: `127.0.0.1:8642`
- Hermes Workspace: `0.0.0.0:3000`
- Sprite service name: `hermes-workspace`
- Public URL: your Sprite hostname on port `3000`

Only the Workspace should be exposed. Do not expose the Hermes gateway directly.

## 1. Create the Sprite

```bash
sprite create hermes-workspace
sprite exec hermes-workspace -- mkdir -p /app/bootstrap /app/company /app/bin
```

## 2. Install stock Hermes and Hermes Workspace

Install Hermes with Nous's upstream installer:

```bash
sprite exec hermes-workspace -- sh -lc 'curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash'
```

Clone and build Hermes Workspace:

```bash
sprite exec hermes-workspace -- sh -lc '
  export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"
  corepack enable >/dev/null 2>&1 || true
  corepack prepare pnpm@latest --activate >/dev/null 2>&1 || npm install -g pnpm
  rm -rf /app/hermes-workspace
  git clone --depth 1 https://github.com/outsourc-e/hermes-workspace.git /app/hermes-workspace
  cd /app/hermes-workspace
  pnpm install --frozen-lockfile
  pnpm build
'
```

## 3. Choose a model

Run the normal Hermes setup flow inside the Sprite:

```bash
sprite exec hermes-workspace -- sh -lc '
  export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"
  hermes setup
'
```

That step should end with a working provider and model choice for the gateway.

## 4. Enable the private gateway

Set Hermes to run its gateway on loopback only:

```bash
sprite exec hermes-workspace -- sh -lc '
  export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"
  HERMES_ENV_PATH="$(hermes config env-path 2>/dev/null || true)"
  if [ -z "$HERMES_ENV_PATH" ]; then HERMES_ENV_PATH="$HOME/.hermes/.env"; fi
  mkdir -p "$(dirname "$HERMES_ENV_PATH")"
  touch "$HERMES_ENV_PATH"
  grep -vE "^API_SERVER_(ENABLED|HOST|PORT)=" "$HERMES_ENV_PATH" >"$HERMES_ENV_PATH.tmp" || true
  mv "$HERMES_ENV_PATH.tmp" "$HERMES_ENV_PATH"
  cat >>"$HERMES_ENV_PATH" <<EOF
API_SERVER_ENABLED=true
API_SERVER_HOST=127.0.0.1
API_SERVER_PORT=8642
EOF
'
```

## 5. Point the Workspace at the private gateway

Create the Workspace runtime file:

```bash
sprite exec hermes-workspace -- sh -lc 'cat >/app/hermes-workspace/runtime.env <<EOF
HERMES_API_URL=http://127.0.0.1:8642
HERMES_ALLOWED_HOSTS=hermes-workspace.sprites.dev
HOST=0.0.0.0
PORT=3000
FORMATION_WORKSPACE_INSTALL_DIR=/app/hermes-workspace
FORMATION_WORKSPACE_RUNTIME_ENV_FILE=/app/hermes-workspace/runtime.env
FORMATION_GATEWAY_PORT=8642
FORMATION_WORKSPACE_PORT=3000
EOF'
```

If you plan to make the Sprite URL public, add a password:

```bash
sprite exec hermes-workspace -- sh -lc 'printf "HERMES_PASSWORD=%s\n" "choose-a-real-password" >> /app/hermes-workspace/runtime.env'
```

Private-by-default access is the recommended path.

## 6. Add the launcher

Use a launcher that starts Hermes first, waits for health, then starts Hermes Workspace:

```bash
#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"

WORKSPACE_DIR="${FORMATION_WORKSPACE_INSTALL_DIR:-/app/hermes-workspace}"
RUNTIME_ENV_FILE="${FORMATION_WORKSPACE_RUNTIME_ENV_FILE:-$WORKSPACE_DIR/runtime.env}"
GATEWAY_PORT="${FORMATION_GATEWAY_PORT:-8642}"
WORKSPACE_PORT="${FORMATION_WORKSPACE_PORT:-3000}"

if [[ -f "$RUNTIME_ENV_FILE" ]]; then
  set -a
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
```

Inside this repo, the checked-in copy lives at:

- [`priv/agent_formation/hermes-workspace/launch_workspace.sh`](/Users/sean/Documents/regent/platform/priv/agent_formation/hermes-workspace/launch_workspace.sh)

## 7. Start the service

Run the launcher and register one public service on port `3000`:

```bash
sprite exec hermes-workspace -- sh -lc 'nohup /app/bootstrap/launch_workspace.sh >/tmp/hermes-workspace-service.log 2>&1 &'
sprite services create hermes-workspace hermes-workspace --http-port 3000
```

Do not register a second public service for the Hermes gateway.

## 8. Verify it locally on the Sprite

Check the gateway:

```bash
sprite exec hermes-workspace -- sh -lc 'curl http://127.0.0.1:8642/health'
```

Check the Workspace:

```bash
sprite exec hermes-workspace -- sh -lc 'curl -I http://127.0.0.1:3000'
```

Then open the Sprite URL and confirm the Workspace shows the full panes for memory, skills, and sessions. If those panes are missing, the app is not connected to the Hermes gateway in full mode yet.

## 9. Create a checkpoint

```bash
sprite checkpoint create hermes-workspace --comment "workspace ready"
```

That gives you a clean restore point after the install and build are complete.

## 10. Open the Workspace

Open your Sprite URL in the browser and finish the onboarding flow.

You should end up with one place for:

- chat
- files
- memory
- skills
- terminal

## What changes from local setup

- Use `pnpm build` and `pnpm start`, not `pnpm dev`.
- Keep the Hermes gateway private on loopback.
- Use the Sprite URL instead of `http://localhost:3000`.
- Register one managed Sprite service for the Workspace only.

## Mobile use

Open the Sprite URL on your phone, then install it as an app from the browser menu.

- On iPhone and iPad, use “Add to Home Screen.”
- On Android, use “Add to Home screen.”

For a Sprite-hosted setup, the Sprite URL is the main path. Tailscale is not the primary recommendation here.

## Why a Sprite fits this well

- Checkpoints let you save a clean restore point after setup.
- Pause and resume let you control runtime cost without rebuilding the workspace.
- Hardware isolation keeps each company separate.
- Network policy lets you keep the Hermes gateway private.
- Persistent disk keeps the company workspace and Hermes state in place across restarts.
