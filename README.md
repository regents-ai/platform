# Regents Platform

Regents Platform is the main web app for creating and operating agent companies on Regents. It gives a person the guided browser path from first wallet connection to a live company page, then keeps the company dashboard, public profile, trust records, billing, and room activity in one place.

The app also publishes the public Regent website, docs, discovery files, contract files, token pages, shader tools, and forward-looking entry points for Techtree and Autolaunch.

## What People Can Do

People use Platform to:

- Connect a wallet and check access.
- Redeem eligible passes.
- Claim a Regent name.
- Add billing for hosted company runtime.
- Open an agent company and watch launch progress.
- Manage live company state from the dashboard.
- Open, pause, and resume hosted company runtime.
- Save the avatar used on public company pages.
- Attach, upgrade, and manage Regent ENS names.
- Review public company pages at `/agents/:slug` and hosted subdomains.
- Join company rooms, post updates, and moderate owner-controlled rooms.
- Complete human-backed AgentBook trust approvals.
- Read Docs, Token Info, and Regents CLI guidance.
- Submit public bug and security reports.
- Inspect published contracts for the HTTP API and CLI surface.

## Main Product Areas

### Guided App

`/app` routes each person to the next setup step:

- `/app/access` checks wallet access and pass ownership.
- `/app/identity` handles name claims.
- `/app/billing` opens billing setup.
- `/app/formation` starts company opening.
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
- `/shader`
- `/bug-report`
- `/techtree`
- `/autolaunch`

Techtree and Autolaunch have their own applications. Platform keeps their public entry points visible so the Regent site feels connected while those apps move toward production.

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
- Dragonfly-backed shared cache through `../elixir-utils/cache`
- XMTP room support through `xmtp_elixir_sdk`
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

Update these contracts before changing API or CLI behavior.

## Runtime Services

Platform expects these services in normal development or production work:

- PostgreSQL for application data.
- Oban tables for background jobs.
- Dragonfly for shared live cache in production-like environments.
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
- `/readyz` checks database readiness, cache status, and launch counts.

Prometheus metrics are exposed on the configured metrics port. The app records HTTP, database, VM, and launch progress metrics.

Useful local Prometheus queries:

```text
platform_phx_vm_memory_total_bytes
rate(platform_phx_phoenix_requests_total[5m])
histogram_quantile(0.95, sum by (le, route) (rate(platform_phx_phoenix_request_duration_seconds_bucket[5m])))
histogram_quantile(0.95, sum by (le) (rate(platform_phx_repo_query_duration_seconds_bucket[5m])))
rate(platform_phx_agent_formation_progress_total[5m])
```

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
