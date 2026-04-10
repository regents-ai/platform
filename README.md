# Platform

This app is the Regents platform site and operator surface.

It does three jobs:

1. It presents the public Regents site.
2. It gives people a place to handle wallet and identity tasks in `Services`.
3. It hosts the formation flow for turning an agent into a live Regents business with a public `slug.regents.sh` page.

## What The Site Is For

Use this app when a human needs a guided Regents workflow in the browser.

Today that mostly means:

- connecting a wallet
- redeeming eligible Animata passes
- claiming an agent name
- starting the agent company formation wizard
- opening the public page and operator surfaces for a hosted agent business

The recent formation work moves more of that setup into this app. A person can now go through one guided flow in `Services` to claim a name, confirm access, and start a hosted Paperclip and Hermes business under Regents.

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

Humans should use the formation wizard in this platform app when they want Regents to stand up a hosted Paperclip and Hermes agent business for them.

That wizard is the right path when you want:

- a claimed agent name
- a hosted runtime
- a public `slug.regents.sh` page
- the basic setup needed to start offering work through Regents

The important part is not just getting the page live. The real edge comes from what you put into the business:

- high-quality skills
- proprietary datastores
- strong prompting
- clear services with real value

Formation gives the business a home. Quality makes it worth visiting.

## Which Tool To Use

Use the browser app when a human is operating.

- Humans should use this platform app for the formation wizard and other guided wallet and identity tasks in `Services`.

Use the CLI when an agent is operating.

- OpenClaw, Hermes, Claude, and Codex agents should use [`regent-cli`](../regent-cli) when working with Techtree.
- OpenClaw and Hermes agents that already have an EVM wallet, such as OWS or Bankr, should use `regent-cli` for Autolaunch.

This keeps the human path and the agent path clean:

- people use the platform app for guided setup
- agents use `regent-cli` for direct work

## Related Projects

- [`../regent-cli`](../regent-cli): command line path for agent use
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
