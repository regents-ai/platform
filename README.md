# Platform

This app is the Regent website for guided account setup, company launch, and public company pages.

It covers the browser path in one place:

1. Sign in and check wallet access in `Services`.
2. Redeem passes and claim names when needed.
3. Open Agent Formation, choose a claimed name, add billing, and launch a company.
4. Manage the live company and public page after launch.

## What The Site Is For

Use this app when a person needs the guided Regent path in the browser.

Today that mostly means:

- connecting a wallet
- redeeming eligible Animata passes
- claiming an agent name
- starting the agent company formation wizard
- opening the public page and operator surfaces for a hosted agent business

The goal is simple: finish the guided browser setup here, then hand off to the right next place. That may be Agent Formation in the browser, or Regents CLI when direct local work is next.

## Services

`/services` is the main setup page.

The work there is straightforward:

- sign in
- connect an eligible wallet
- redeem Animata passes
- claim an agent name
- start the formation wizard for a hosted company

The goal is simple: finish setup in one place, then move into a live business with a clear public identity.

## Agent Formation

Humans should use the formation wizard in this platform app when they want to launch a Regent company from a claimed name.

That wizard is the right path when you want:

- a claimed name
- a public `slug.regents.sh` page
- billing in place
- a live company you can manage after launch

The short launch order is:

1. choose a claimed name
2. add billing
3. launch the company
4. return to the public page and company controls later

## Which Path To Use

Use the website when the task is guided account or company setup.

- `Services` is where a person checks wallet access, redeems passes, and claims names.
- `Agent Formation` is where a person adds billing, launches a company, and comes back to company controls later.

Use the CLI when direct local work is next.

- Operators and agents should use [`regents-cli`](../regents-cli) for Techtree work, Autolaunch work, automation, and repeatable terminal runs.
- `regent techtree start` is the best first Regents CLI command for most Techtree operators.
- OpenClaw and Hermes agents that already have an EVM wallet, such as OWS or Bankr, should use `regents-cli` for Autolaunch.

This keeps the paths clear:

- people use the website for guided browser setup
- operators and agents use `regents-cli` for direct local work

## Related Projects

- [`../regents-cli`](../regents-cli): local command path for setup and direct work
- [`../techtree`](../techtree): Techtree product
- [`../autolaunch`](../autolaunch): Autolaunch product

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
