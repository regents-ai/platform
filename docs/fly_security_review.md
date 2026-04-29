# Fly Security Review

This review covers the Platform Phoenix app planned for Fly (`platform-phx`), plus the shared services it calls from public routes: Privy, SIWA, Stripe, Regent staking RPC, OpenSea, Base RPC, Postgres, Sprite runtime control, and Regent Work Runtime routes.

## Current Fly Posture

- Fly app: `platform-phx`
- Public app port: `4000`
- Metrics port: `9568`
- HTTPS: forced by Fly and Phoenix production config
- Production release command: `/app/bin/migrate`
- Machine policy: auto-stop enabled, `min_machines_running = 1`
- Dev dashboard/mailbox: present in dev router output, but production should keep `dev_routes` off

## Findings

### Resolved: Demo/design routes are disabled

Routes:

- `GET /demo`
- `GET /heerich-demo`
- `GET /logos`
- `GET /shader`

These are useful internal design surfaces, but they are not needed for the production app. They are no longer mounted by the release router.

### Resolved: Regent staking separates browser and signed-agent routes

Regent staking is visible to people on `/token-info`. The browser page reads chain state directly through the Platform context and only prepares wallet actions for a signed-in human. CLI and agent clients use `/v1/agent/regent/staking...` with signed Agent account authentication. The old browser-session staking API routes are no longer part of the public route surface.

### Resolved: Public write and expensive read routes are rate-limited

Routes:

- `POST /api/bug-report`
- `POST /api/security-report`
- `POST /api/basenames/credit`
- `POST /api/basenames/mint`
- `POST /api/basenames/use`
- `GET /api/basenames/availability`
- `GET /api/opensea`
- `GET /api/opensea/redeem-stats`

The app validates and sanitizes the important inputs, and reports cap text length. These routes now also have app-level IP and route-family rate limits.

Autolaunch auction data is not served by Platform. The public Platform page links out to Autolaunch for live launch state.

### Resolved: Product route contract drift is guarded

The OpenAPI contract now matches the product API route surface, including token metadata and OpenSea redeem stats. Private Prometheus metrics are no longer advertised as a product route.

Recommendation: keep the contract drift test in place so every API route addition starts in the YAML contract.

### Resolved: LiveView longpoll is disabled

The app keeps the websocket transport and disables the longpoll transport. That removes two extra request paths from production while keeping the normal browser experience intact.

### Resolved: At least one Fly machine stays running

The Fly config now keeps one machine running so Stripe webhooks and billing callbacks are not dependent on a cold start.

### Resolved: Production session cookies are secure

The session cookie uses `same_site: "Lax"`, Phoenix signs the cookie, and production compilation sets the cookie `Secure` flag.

### Resolved: `/readyz` is shallow

Route:

- `GET /readyz`

This route is useful for promotion checks. It now returns only coarse app readiness and dependency status.

### Resolved: Metrics stay private to Fly

Fly config declares:

- `[metrics] port = 9568`
- `[metrics] path = "/metrics"`

The app starts a separate Prometheus exporter on the metrics port, and the product API contract no longer lists `/metrics`.

Recommendation: keep port `9568` out of public Fly services and keep metrics output free of user identifiers, secrets, wallet-specific data, and report content.

### P2: Keep Stripe webhook signature checks exactly as-is

Route:

- `POST /api/agent-platform/stripe/webhooks`

The route is intentionally unauthenticated because Stripe calls it directly. The code verifies the Stripe signature over the raw request body and rejects stale timestamps. Billing sync jobs are unique by Stripe event id, so webhook retries do not multiply work.

Recommendation: keep this route public but only accept signed Stripe payloads. Make `STRIPE_WEBHOOK_SECRET` mandatory before enabling billing on Fly.

### Resolved: Company and Sprite writes stay disabled while formation is closed

Company formation writes check whether formation is enabled. The read routes and pages remain visible, while company-opening and Sprite pause/resume actions show disabled controls when formation is closed.

### Resolved: RWR browser pages are owner-scoped

Routes:

- `GET /app/work`
- `GET /app/runs/:id`
- `GET /app/runtimes`
- `GET /app/agents`

These pages are part of the signed-in app. They show work, runs, runtime profiles, workers, relationships, checkpoints, and proof review state for the owner company only. They must not leak billing setup, runtime spend, private run events, or local machine details onto public company pages.

### Resolved: RWR worker routes use signed worker requests

Routes:

- `POST /api/agent-platform/companies/:company_id/rwr/workers`
- `POST /api/agent-platform/companies/:company_id/rwr/workers/:worker_id/heartbeat`
- `GET /api/agent-platform/companies/:company_id/rwr/workers/:worker_id/assignments`
- `POST /api/agent-platform/companies/:company_id/rwr/assignments/:assignment_id/claim`
- `POST /api/agent-platform/companies/:company_id/rwr/assignments/:assignment_id/release`
- `POST /api/agent-platform/companies/:company_id/rwr/assignments/:assignment_id/complete`
- `POST /api/agent-platform/companies/:company_id/rwr/runs/:run_id/events`
- `POST /api/agent-platform/companies/:company_id/rwr/runs/:run_id/artifacts`
- `POST /api/agent-platform/companies/:company_id/rwr/runs/:run_id/delegations`

These routes are not browser-session routes. They require the Platform signed worker guard, a worker that belongs to the company, and the current RWR contract shape. Worker event and artifact payloads must stay bounded and must not include secrets.

### Resolved: OpenClaw stays local-only for v0.1

OpenClaw enters RWR through the same local worker bridge as Hermes. Platform should register local OpenClaw workers with local execution, user-local billing, local user control, and self-reported usage. Do not add hosted OpenClaw secrets, hosted OpenClaw provisioning, or OpenClaw-specific Fly settings for v0.1.

### Resolved: Publishing is explicit

RWR private state includes work items, runs, events, artifacts, worker relationships, runtime profiles, checkpoints, service health, and local usage. None of that should appear on public company pages until an operator reviews it and takes a publish action. Public pages may show only published proof and public company data.

### Resolved: Hosted and local billing stay separate

Hosted Sprite workers use Platform billing, runtime credits, Stripe, metering, and runtime controls. Local Hermes and OpenClaw workers run on the user's machine and may report usage for visibility, but that usage must not become hosted Sprite spend.

### Resolved: Sprite management stays in Platform Elixir code

Platform may use a Sprites SDK or a thin Elixir HTTP client for hosted runtime management. Platform backend code must not shell out to the `sprite` CLI. Sprite CLI examples belong in local or operator smoke checks only.

### P3: Keep public discovery files aligned

Routes:

- `GET /api-contract.openapiv3.yaml`
- `GET /cli-contract.yaml`
- well-known agent discovery routes

These routes are correct to expose. The risk is drift: if they mention routes that are disabled on Fly, agents will call dead surfaces.

Recommendation: after disabling routes, update the OpenAPI and CLI contracts first, then regenerate any clients.

## Go / No-Go Checklist For Fly Promotion

- Shared public beta run sheet checked: `/Users/sean/Documents/regent/docs/regent-local-and-fly-launch-testing.md`.
- `mix precommit` passes.
- `MIX_ENV=prod mix compile --warnings-as-errors` passes.
- Demo/design routes disabled in production.
- `dev_routes` false in production.
- Platform does not expose treasury prepare routes; operator treasury actions stay in the Autolaunch/operator contract path.
- Public write routes have rate limits.
- RWR `/app` pages are owner-scoped.
- RWR signed worker routes reject unsigned worker calls.
- OpenClaw is registered only through the local worker bridge for v0.1.
- RWR publishing requires an explicit operator action.
- Hosted Sprite billing and local worker usage stay separate.
- Platform manages Sprites through Elixir code, not the sprite CLI.
- Stripe webhook secret set and webhook test succeeds.
- `SECRET_KEY_BASE`, `DATABASE_URL`, Privy, SIWA, Stripe, RPC, and enabled Sprite secrets are set through Fly secrets.
- Metrics port is not publicly exposed.
- `/healthz` returns `ok`.
- `/readyz` returns ready without exposing sensitive details.
- `min_machines_running = 1` for production billing/webhook use.
- Public contracts match the actual Fly route surface.
