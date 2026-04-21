# Platform

This app is the Regent website for guided account setup, company launch, and public company pages.

It covers the guided website path in one place:

1. Open `/app` and check access.
2. Redeem passes and claim names when needed.
3. Add billing, open the company, and follow launch progress.
4. Manage the live company and public page after launch.

## What The Site Is For

Use this app when a person needs the guided Regent path in the browser.

Today that mostly means:

- connecting a wallet
- redeeming eligible Animata passes
- claiming an agent name
- adding billing and opening the company
- opening the public page and operator surfaces for a hosted agent business

The goal is simple: finish the guided website setup here, then move to the right next place. That may be the hosted company dashboard in the app, or Regents CLI when local work is next.

## App

`/app` is the main guided entry.

It routes people into the next step:

- `/app/access` for wallet access and pass checks
- `/app/identity` for name claims
- `/app/billing` for billing setup
- `/app/formation` for opening the company
- `/app/dashboard` for the hosted company after launch

The goal is simple: keep the full company-opening path in one place, then come back to the hosted dashboard once the company is live.

## Which Path To Use

Use the website when the task is guided company setup or hosted company control.

- `/app` is where a person checks access, redeems passes, claims names, adds billing, opens the company, and comes back to the dashboard later.
- `/docs` is the short reference page for the website path and the CLI path.

Use the CLI when direct local work is next.

- Operators and agents should use [`regents-cli`](../regents-cli) for Techtree work, Autolaunch work, automation, and repeatable terminal runs.
- `regent techtree start` is the best first Regents CLI command for most Techtree operators.
- OpenClaw and Hermes agents that already have an EVM wallet, such as OWS or Bankr, should use `regents-cli` for Autolaunch.

This keeps the paths clear:

- people use the website for guided company setup and hosted company control
- operators and agents use `regents-cli` for direct local work

## Related Projects

- [`../regents-cli`](../regents-cli): local command path for setup and direct work
- [`../techtree`](../techtree): Techtree product
- [`../autolaunch`](../autolaunch): Autolaunch product

## Public Discovery Files

The site now publishes a small public discovery surface for crawlers and agents:

- `/robots.txt`: crawl rules, AI usage preferences, and the sitemap location
- `/sitemap.xml`: the public entry pages plus live company home pages
- `/.well-known/api-catalog`: API discovery catalog
- `/.well-known/agent-card.json`: site agent discovery card
- `/.well-known/agent-skills/index.json`: published skill index
- `/.well-known/mcp/server-card.json`: public MCP-related discovery card
- `/agent-skills/regents-cli.md`: published Regents CLI skill
- `/api-contract.openapiv3.yaml` and `/cli-contract.yaml`: the live source-of-truth contracts served from the app

## Local Development

Start from this folder:

```bash
cd /Users/sean/Documents/regent/platform
```

Install dependencies:

```bash
mix setup
```

Run the app:

```bash
mix phx.server
```

Then open [http://localhost:4000](http://localhost:4000).

Before you wrap up work, run:

```bash
mix precommit
```

## Live Metrics In Prometheus

To graph the live Fly app locally, run two things from this repo.

First, open a tunnel from your laptop to the live app metrics port:

```bash
./bin/live-metrics-proxy
```

Leave that terminal open.

This uses local port `19568` so it does not collide with your own app metrics on `9568`.

Second, start Prometheus:

```bash
docker compose -f docker-compose.prometheus.yml up -d
```

Make sure Docker Desktop is running first.

Then open [http://localhost:9090](http://localhost:9090).

Useful first queries:

```text
platform_phx_vm_memory_total_bytes
rate(platform_phx_phoenix_requests_total[5m])
histogram_quantile(0.95, sum by (le, route) (rate(platform_phx_phoenix_request_duration_seconds_bucket[5m])))
histogram_quantile(0.95, sum by (le) (rate(platform_phx_repo_query_duration_seconds_bucket[5m])))
```

When you are done:

```bash
docker compose -f docker-compose.prometheus.yml down
```
