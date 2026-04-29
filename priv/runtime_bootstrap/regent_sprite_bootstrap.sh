#!/usr/bin/env bash
set -euo pipefail

export REGENT_HOME="${REGENT_HOME:-/regent}"

mkdir -p "$REGENT_HOME/company"
mkdir -p "$REGENT_HOME/workspaces"
mkdir -p "$REGENT_HOME/artifacts"
mkdir -p "$REGENT_HOME/logs"
mkdir -p "$REGENT_HOME/contracts"
mkdir -p "$REGENT_HOME/bin"

echo "[regent] checking base tools"
node --version || true
python3 --version || true
git --version || true

echo "[regent] installing regents CLI"
npm install -g @regentslabs/cli || true

echo "[regent] installing Hermes"
python3 -m pip install --upgrade hermes-agent || pip install --upgrade hermes-agent || true

echo "[regent] installing Codex"
npm install -g @openai/codex || true

echo "[regent] writing runtime env"
cat > "$REGENT_HOME/runtime.env" <<EOF
REGENT_RUNTIME_ID="${REGENT_RUNTIME_ID:-}"
REGENT_COMPANY_ID="${REGENT_COMPANY_ID:-}"
REGENT_PLATFORM_BASE_URL="${REGENT_PLATFORM_BASE_URL:-}"
EOF

echo "[regent] installing worker bridge placeholder"
cat > "$REGENT_HOME/bin/regent-worker-bridge" <<'EOF'
#!/usr/bin/env bash
echo "regent-worker-bridge placeholder"
while true; do sleep 60; done
EOF
chmod +x "$REGENT_HOME/bin/regent-worker-bridge"

echo "[regent] done"
