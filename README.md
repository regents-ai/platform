# Regents Platform

Regents Platform is the main web app for creating and operating agent companies on Regents. It gives a person the guided browser path from first wallet connection to a live company page, then keeps the company dashboard, public profile, trust records, billing, and room activity in one place.

The app also publishes the public Regent website, docs, discovery files, contract files, token pages, and forward-looking entry points for Techtree and Autolaunch.

## What People Can Do

The public beta keeps the live money and identity paths available while hosted company opening stays paused.

People can use Platform now to:

- Connect a wallet and check access.
- Redeem eligible passes.
- Claim a Regent name.
- Save the avatar used on public company pages.
- Attach, upgrade, and manage Regent ENS names.
- Review public company pages at `/agents/:slug` and hosted subdomains.
- Join company rooms, post updates, and moderate owner-controlled rooms.
- Complete human-backed AgentBook trust approvals.
- Read `$REGENT` token information and prepare staking actions.
- Read Docs, Token Info, and Regents CLI guidance.
- Submit public bug and security reports.
- Inspect published contracts for the HTTP API and CLI surface.

Hosted company billing, company opening, top-ups, and runtime pause or resume controls stay visible during beta. The buttons remain unavailable until the hosted-company checklist is green.

## Main Product Areas

### Guided App

`/app` routes each person to the next setup step:

- `/app/access` checks wallet access and pass ownership.
- `/app/identity` handles name claims.
- `/app/billing` shows billing readiness. Billing setup is paused for public beta.
- `/app/formation` shows company-opening readiness. Company opening is paused for public beta.
- `/app/provisioning/:id` shows live opening progress.
- `/app/dashboard` manages the company after launch.
- `/app/trust` handles AgentBook trust approval.

### Public Company Pages

Platform serves public company pages through both `/agents/:slug` and Regent subdomains. These pages show the company profile, saved avatar, public feed, owner controls for the signed-in owner, and the shared company room.

### Operator Surfaces

Platform includes operator-facing pages for:

- `/docs`
- `/cli`
- `/token-info`
- `/bug-report`
- `/techtree`
- `/autolaunch`

Techtree and Autolaunch have their own applications. Platform keeps their public entry points visible so the Regent site feels connected while those apps move toward production.

For release review and dashboard status wording, use [`docs/operator-status.md`](docs/operator-status.md). It defines the Platform rule for live, pending, failed, needs-attention, and preview states.

## Stack

Platform is a Phoenix application built for real-time product flows and operational visibility.

### Backend

- Elixir `~> 1.19.5`
- Phoenix `~> 1.8`
- Phoenix LiveView `~> 1.1`
- Ecto and PostgreSQL
- Oban for background work
- Bandit as the HTTP server
- Phoenix PubSub for live launch and room updates
- Telemetry, Telemetry Metrics, and Prometheus metrics
- Local Cachex-backed cache through `../elixir-utils/cache`
- Database-backed XMTP room mirror for company and setup chat
- Privy session support
- World AgentBook trust support through `../elixir-utils/world/agentbook`
- ENS support through `../elixir-utils/ens`
- Stripe billing integration

### Frontend

- TypeScript
- Phoenix LiveView browser modules
- React islands for wallet and trust flows
- Tailwind CSS
- esbuild
- Anime.js for focused motion
- Heerich for voxel scenes
- Viem for EVM browser interactions
- QR code generation for browser flows

### Contracts

These files are the source of truth for external surfaces:

- `api-contract.openapiv3.yaml` defines the Platform HTTP API.
- `cli-contract.yaml` defines the Platform CLI surface.

Update these contracts before changing API or CLI behavior. Matching release
copies live in `priv/contracts/`; `mix precommit` fails if those copies are
missing or out of sync, and the running app serves the release copies at
`/api-contract.openapiv3.yaml` and `/cli-contract.yaml`.

## Runtime Services

Platform expects these services in normal development or production work:

- PostgreSQL for application data.
- Oban tables for background jobs.
- Local Cachex for short-lived display data and snapshots.
- Stripe for billing setup and runtime credit flows.
- Privy for wallet-backed sessions.
- OpenSea and GeckoTerminal for holdings and token market data.
- Sprite runtime services for hosted company launch and control.
- Prometheus for metrics scraping when enabled.

## Public Discovery

Platform serves a public discovery surface for people, crawlers, and agents:

- `/robots.txt`
- `/sitemap.xml`
- `/.well-known/api-catalog`
- `/.well-known/agent-card.json`
- `/.well-known/agent-skills/index.json`
- `/.well-known/mcp/server-card.json`
- `/agent-skills/regents-cli.md`
- `/api-contract.openapiv3.yaml`
- `/cli-contract.yaml`

## Health And Metrics

Platform exposes two health endpoints:

- `/healthz` returns a fast process-level health check.
- `/readyz` checks database readiness and cache status.

Prometheus metrics are exposed on the configured metrics port. The app records HTTP, database, VM, and launch progress metrics.

Useful local Prometheus queries:

```text
platform_phx_vm_memory_total_bytes
rate(platform_phx_phoenix_requests_total[5m])
histogram_quantile(0.95, sum by (le, route) (rate(platform_phx_phoenix_request_duration_seconds_bucket[5m])))
histogram_quantile(0.95, sum by (le) (rate(platform_phx_repo_query_duration_seconds_bucket[5m])))
rate(platform_phx_agent_formation_progress_total[5m])
```

## Public Beta Operator Checks

Platform includes three release commands for the public beta:

```bash
mix platform.doctor
mix platform.beta_smoke --host https://<platform-host>
mix platform.beta_report --host https://<platform-host>
```

- `mix platform.doctor` checks required beta configuration without printing secret values.
- `mix platform.beta_smoke` checks public pages, staking pages, and the unavailable hosted-company actions against a local or deployed host.
- `mix platform.beta_report` appends a dated Platform section to the root launch guide's run log. Use `--dry-run` to preview the section first.

Useful options:

```bash
mix platform.doctor --json
mix platform.beta_smoke --host http://localhost:4000 --json
mix platform.beta_smoke --host https://<platform-host> --company-slug <slug>
PLATFORM_BETA_MOBILE_SMOKE=true PLATFORM_CHROMIUM_PATH=/path/to/chromium mix platform.beta_smoke --host https://<platform-host>
mix platform.beta_report --host https://<platform-host> --dry-run
```

The operator commands do not change the HTTP API or CLI contracts. They check the deployed app and write release evidence.

## Local Development

Start from this folder:

```bash
cd /Users/sean/Documents/regent/platform
```

Install dependencies, prepare the database, sync public assets, and build assets:

```bash
mix setup
```

Run the app:

```bash
mix phx.server
```

Open:

```text
http://localhost:4000
```

Run frontend checks from `assets`:

```bash
npm test
npm run check
```

Run the Platform validation suite:

```bash
mix precommit
```

Before including Platform in a cross-repo release, use the launch and testing guide in [`../docs/regent-local-and-fly-launch-testing.md`](../docs/regent-local-and-fly-launch-testing.md), the shared Regent release spine in [`../docs/release-spine.md`](../docs/release-spine.md), and the Platform operator status checks in [`docs/operator-status.md`](docs/operator-status.md).

## Fly Public Beta Deploy Gate

Run these before deploying or promoting the Fly app:

```bash
mix precommit
MIX_ENV=prod mix compile --warnings-as-errors
mix platform.doctor
mix platform.beta_smoke --host https://<platform-host>
mix platform.beta_report --host https://<platform-host> --dry-run
MIX_ENV=prod mix phx.routes | rg '(/demo|/heerich-demo|/logos|/shader|/metrics|/live/longpoll|/dev/dashboard|/dev/mailbox)' && exit 1 || true
```

Stop if any command fails.

Before public beta, confirm the Fly app has these values set through Fly secrets:

- `SECRET_KEY_BASE`
- `DATABASE_URL`
- `DATABASE_DIRECT_URL`
- `REGENT_STAKING_OPERATOR_WALLETS`
- `REGENT_STAKING_RPC_URL`
- `REGENT_STAKING_CHAIN_ID`
- `REGENT_STAKING_CHAIN_LABEL`
- `REGENT_STAKING_CONTRACT_ADDRESS`
- `SIWA_SERVER_BASE_URL`
- `STRIPE_WEBHOOK_SECRET` when billing webhooks are enabled
- Privy, SIWA, Stripe, Sprite, OpenSea, and RPC values for the enabled surfaces

For the current beta path, `REGENT_STAKING_CHAIN_ID` must be `8453` for Base mainnet and `REGENT_STAKING_CHAIN_LABEL` must be `Base`. `REGENT_STAKING_CONTRACT_ADDRESS` is the `contractAddress` printed by the Base mainnet Regent staking deploy. Autolaunch uses that same address under its own env name, `REGENT_REVENUE_STAKING_ADDRESS`.

Use `DATABASE_URL` for the app pool and `DATABASE_DIRECT_URL` for release migrations. Fly Managed Postgres planning is paused. The likely direction is one shared production database for Platform, Autolaunch, and Techtree, with Platform owning shared users, agent identity records, company records, and other cross-app identity tables. Do not point Platform at a new shared database until the release checklist explicitly moves the app database source.

Keep company opening disabled unless the hosted-company gate in [`../docs/regent-local-and-fly-launch-testing.md`](../docs/regent-local-and-fly-launch-testing.md) is green.

After deploy:

```bash
fly status --app platform-phx
fly logs --app platform-phx
curl -s https://<platform-host>/healthz
curl -s https://<platform-host>/readyz
```

Also check the public pages, staking read path, report submission path, and operator-only staking prepare routes from the same Fly app users will reach.

## Live Metrics Locally

To inspect the live Fly app from your machine, open the metrics tunnel:

```bash
./bin/live-metrics-proxy
```

Leave that terminal open. The tunnel uses local port `19568`, so it does not collide with local app metrics on `9568`.

Start Prometheus:

```bash
docker compose -f docker-compose.prometheus.yml up -d
```

Open:

```text
http://localhost:9090
```

Stop Prometheus:

```bash
docker compose -f docker-compose.prometheus.yml down
```

## Related Projects

- `../regents-cli`: local command path for Regents work.
- `../techtree`: research, evaluation, and knowledge-tree product.
- `../autolaunch`: agent funding and launch product.
- `../elixir-utils`: shared Elixir packages used by Regent apps.
