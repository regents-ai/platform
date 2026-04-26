# Platform Release Phase Tracker

Last updated: April 25, 2026

Use this as the working handoff note for Platform release work. `AGENTS.md` should stay focused on durable rules; this file tracks the current phase, next phase, and release checks.

## Current Phase: Fly Production Hardening

Goal: make the Platform Fly release coherent and safe while `$REGENT` staking goes live first and hosted company opening stays visible but disabled.

Done:

- Demo and internal design routes are disabled in production.
- Public write routes and expensive public reads are rate-limited.
- Regent treasury prepare routes require a signed-in operator wallet from `REGENT_STAKING_OPERATOR_WALLETS`.
- Production session cookies are secure.
- `/readyz` is shallow and does not expose launch counts.
- Prometheus metrics stay on the private Fly metrics port and are not part of the public product API contract.
- LiveView longpoll is disabled; websocket remains enabled.
- Company opening, billing setup, top-ups, and Sprite pause/resume controls are visible but disabled while formation is closed.
- Stripe webhook signatures are verified over the raw request body.
- Stripe billing sync jobs are unique by Stripe event id.
- The OpenAPI contract now covers the public product route surface, including token metadata and OpenSea redeem stats.
- A contract drift test fails if product API routes and `api-contract.openapiv3.yaml` diverge.

Working docs:

- `docs/fly_route_matrix.md`
- `docs/fly_security_review.md`
- `docs/fly_user_action_matrix.md`
- `docs/operator-status.md`
- `/Users/sean/Documents/regent/docs/public-beta-run-sheet.md`

Latest verification:

- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `MIX_ENV=prod mix compile --warnings-as-errors`
- `mix contract.validate`
- production route check for disabled routes
- `mix precommit` passed with 233 app tests after the contract validation test

## Required Fly Secrets Before Promotion

- `SECRET_KEY_BASE`
- `DATABASE_URL`
- `REGENT_STAKING_OPERATOR_WALLETS`
- `REGENT_STAKING_RPC_URL`
- `REGENT_STAKING_CHAIN_ID`
- `REGENT_STAKING_CHAIN_LABEL`
- `REGENT_STAKING_CONTRACT_ADDRESS`
- `STRIPE_WEBHOOK_SECRET`
- Stripe billing secrets and price ids, if billing is enabled
- Privy auth secrets
- `SIWA_SERVER_BASE_URL`
- Dragonfly connection values
- Sprite control secrets, if hosted company control is enabled

Platform env source map:

| Platform env var | Source |
| --- | --- |
| `DATABASE_URL` | Fly Postgres attach or local Postgres URL |
| `SECRET_KEY_BASE` | `mix phx.gen.secret` |
| `PHX_HOST` | final Platform host |
| `PHX_SERVER` | `true` on Fly |
| `PORT` | `4000` locally, Fly app port from `fly.toml` |
| `BASE_RPC_URL` | Base mainnet RPC URL |
| `VITE_PRIVY_APP_ID` | Privy dashboard |
| `VITE_PRIVY_APP_CLIENT_ID` | Privy dashboard |
| `PRIVY_VERIFICATION_KEY` | Privy dashboard |
| `SIWA_SERVER_BASE_URL` | shared SIWA server URL |
| `DRAGONFLY_ENABLED` | `true` when Dragonfly is available |
| `DRAGONFLY_HOST` | Dragonfly private host |
| `DRAGONFLY_PORT` | usually `6379` |
| `OPENSEA_API_KEY` | OpenSea dashboard, if token pages need live OpenSea data |

Staking env source map:

| Platform env var | Source |
| --- | --- |
| `REGENT_STAKING_CONTRACT_ADDRESS` | `contractAddress` from the Base mainnet Regent staking deploy |
| `REGENT_STAKING_RPC_URL` | Base mainnet RPC URL |
| `REGENT_STAKING_CHAIN_ID` | `8453` |
| `REGENT_STAKING_CHAIN_LABEL` | `Base` |
| `REGENT_STAKING_OPERATOR_WALLETS` | comma-separated operator wallets allowed to prepare treasury actions |

Autolaunch uses the same staking contract address as `REGENT_REVENUE_STAKING_ADDRESS`; Platform does not read that env name.

Hosted-company env source map, only when company opening is enabled:

| Platform env var | Source |
| --- | --- |
| `AGENT_FORMATION_ENABLED` | `true` only after hosted-company checks pass |
| `STRIPE_SECRET_KEY` | Stripe dashboard |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook endpoint |
| `STRIPE_BILLING_PRICING_PLAN_ID` | Stripe billing setup |
| `STRIPE_BILLING_TOPUP_SUCCESS_URL` | Platform top-up return URL |
| `STRIPE_BILLING_TOPUP_CANCEL_URL` | Platform top-up cancel URL |
| `STRIPE_RUNTIME_METER_EVENT_NAME` | Stripe meter event name |
| `SPRITES_API_TOKEN_FILE` | path to Sprite API token file on the machine |
| `SPRITE_CLI_PATH` | Sprite CLI path, defaults to `sprite` |

## Next Phase: Staking Release Verification

Goal: make `$REGENT` staking the first live money surface.

Do next:

- Deploy or confirm the Base mainnet Regent staking contract.
- Point `regents.sh` at the live staking contract first.
- Verify staking reads on `regents.sh`.
- Point Platform at the same staking contract only after `regents.sh` is reading correctly.
- Rehearse stake, unstake, claim USDC, claim emissions, claim-and-restake, treasury deposit, treasury withdrawal, and paused-state behavior.
- Confirm reward funding and emissions after funding.
- Keep one written run sheet with contract address, owner, treasury recipient, operator wallets, RPC, chain id, and deployment timestamp.

Go/no-go for staking:

- Contract tests clean.
- Website read path clean.
- CLI read path clean.
- Reward funding tested.
- Emissions tested after funding.
- Treasury path tested.
- Operator allowlist set.
- Public copy clearly separates accrued rewards from currently claimable rewards.

## Next Phase: Hosted Company Reopening

Goal: reopen company formation only after the staking rail is settled.

Do next:

- Keep formation closed on Fly until one local Base Sepolia launch rehearsal is clean.
- Rehearse `/app` routing through access, identity, billing, company opening, provisioning, dashboard, and public company page.
- Rehearse Stripe setup, top-up, webhook retry, and billing-sync worker behavior.
- Rehearse Sprite pause/resume and metering with real operator secrets in a staging setting.
- Confirm AgentBook and SIWA flows still pass with real agent requests.
- Promote formation by setting `AGENT_FORMATION_ENABLED=true` only after the above is green.

Go/no-go for hosted company reopening:

- Local rehearsal passes.
- Fly staging or public rehearsal points at the intended non-mainnet environment first.
- Billing webhook event replay does not duplicate credit.
- Sprite controls produce audit records.
- Public pages do not reveal private billing or setup state.
- OpenAPI and CLI contracts match the live route surface.

## Hard Rules For Future Agents

- Start API or CLI changes in the YAML contract.
- Do not re-enable `/demo`, `/heerich-demo`, `/logos`, or `/shader` for production.
- Do not expose `/metrics` through the product app port.
- Do not add compatibility branches for old route or response shapes.
- Keep under-developed customer actions visible but disabled with plain text.
- Keep customer-facing copy about what the person can do next, not how the app is built.
