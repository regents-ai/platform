# Fly Security Review

This review covers the Platform Phoenix app planned for Fly (`platform-phx`), plus the shared services it calls from public routes: Privy, SIWA, Stripe, Regent staking RPC, OpenSea, Base RPC, Dragonfly, Postgres, and Sprite runtime control.

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

### Resolved: Regent treasury prepare routes require an operator wallet

Routes:

- `POST /api/regent/staking/deposit-usdc/prepare`
- `POST /api/regent/staking/withdraw-treasury/prepare`

These routes are under the browser session API, so write methods require CSRF. They now also require the signed-in wallet to appear in `REGENT_STAKING_OPERATOR_WALLETS`.

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

### P3: Keep public discovery files aligned

Routes:

- `GET /api-contract.openapiv3.yaml`
- `GET /cli-contract.yaml`
- well-known agent discovery routes

These routes are correct to expose. The risk is drift: if they mention routes that are disabled on Fly, agents will call dead surfaces.

Recommendation: after disabling routes, update the OpenAPI and CLI contracts first, then regenerate any clients.

## Go / No-Go Checklist For Fly Promotion

- Shared public beta run sheet checked: `/Users/sean/Documents/regent/docs/public-beta-run-sheet.md`.
- `mix precommit` passes.
- `MIX_ENV=prod mix compile --warnings-as-errors` passes.
- Demo/design routes disabled in production.
- `dev_routes` false in production.
- Regent treasury prepare routes require signed-in operator access.
- Public write routes have rate limits.
- Stripe webhook secret set and webhook test succeeds.
- `SECRET_KEY_BASE`, `DATABASE_URL`, Privy, SIWA, Stripe, RPC, Dragonfly, and Sprite secrets are set through Fly secrets.
- Metrics port is not publicly exposed.
- `/healthz` returns `ok`.
- `/readyz` returns ready without exposing sensitive details.
- `min_machines_running = 1` for production billing/webhook use.
- Public contracts match the actual Fly route surface.
