# Fly Route Matrix

This matrix is for the Platform Phoenix Fly app (`platform-phx`). It is based on the current Phoenix router and Fly config.

## Legend

- **Keep**: expose on Fly production.
- **Keep, gated**: expose only with the current session, signed-agent, or payment guard.
- **Disable**: remove from Fly production before promotion.
- **Internal only**: keep reachable by Fly/platform tooling, but not as a public customer route.

## Public Discovery

| Route | Decision | What it does | Why it is necessary | Security notes |
| --- | --- | --- | --- | --- |
| `GET /robots.txt` | Keep | Publishes crawl rules. | Search and agent crawlers need clear instructions. | Public by design. |
| `GET /sitemap.xml` | Keep | Publishes public page URLs. | Helps discovery of the public site and company pages. | Public by design. |
| `GET /.well-known/api-catalog` | Keep | Publishes API discovery metadata. | Lets agents find the supported API surfaces. | Must list only current public contracts. |
| `GET /.well-known/agent-card.json` | Keep | Publishes the Platform agent card. | Required for agent-facing discovery. | Public by design. |
| `GET /.well-known/agent-skills/index.json` | Keep | Publishes agent skill index. | Lets agents find supported skills. | Public by design. |
| `GET /.well-known/mcp/server-card.json` | Keep | Publishes MCP server card. | Supports agent discovery. | Public by design. |
| `GET /healthz` | Keep | Simple health check. | Fly and uptime probes need a cheap health route. | Return only `ok`. |
| `GET /readyz` | Keep, shallow | Shows app readiness. | Useful before and after promotion. | Returns coarse dependency state only. |
| `GET /api-contract.openapiv3.yaml` | Keep | Serves the public API contract. | Source of truth for clients and agents. | Must not include disabled routes. |
| `GET /cli-contract.yaml` | Keep | Serves the public CLI contract. | Keeps CLI docs aligned with shipped commands. | Must not include disabled commands. |
| `GET /agent-skills/regents-cli.md` | Keep | Serves the Regents CLI skill. | Main CTA for agent operators. | Public by design. |

## Public Pages

| Route | Decision | What it does | Why it is necessary | Security notes |
| --- | --- | --- | --- | --- |
| `GET /` | Keep | Main Regents home page. | Primary public entry point. | Browser security headers apply. |
| `GET /app` | Keep | Starts the guided app flow. | Main human onboarding surface. | Browser session route. |
| `GET /app/access` | Keep | Access and pass checks. | Needed before company setup. | Browser session route. |
| `GET /app/trust` | Keep | Human-backed trust approvals. | Needed for AgentBook trust flow. | Browser session route. |
| `GET /app/identity` | Keep | Identity and wallet profile surface. | Needed for setup and account state. | Browser session route. |
| `GET /app/billing` | Keep, gated | Billing setup and credit state. | Needed for hosted company runtime. | Requires human session for private data. |
| `GET /app/formation` | Keep, gated | Company opening flow. | Needed to create hosted companies. | Requires human session for writes. |
| `GET /app/provisioning/:id` | Keep, gated | Shows company provisioning progress. | Needed after company creation. | Must only show authorized user data. |
| `GET /app/dashboard` | Keep, gated | Company dashboard. | Needed after launch. | Must only show authorized companies. |
| `GET /app/work` | Keep, gated | RWR work list for the signed-in company owner. | Needed for work tracking and run review. | Must only show authorized company work. |
| `GET /app/runs/:id` | Keep, gated | RWR run detail and event review. | Needed for run status and proof review. | Must enforce company ownership before showing events or artifacts. |
| `GET /app/runtimes` | Keep, gated | Runtime and checkpoint review. | Needed for hosted and local worker status. | Must separate hosted Sprite spend from local worker usage. |
| `GET /app/agents` | Keep, gated | Connected agents, workers, pools, and relationships. | Needed for RWR operator review. | Must not publish worker proof until an operator takes the publish action. |
| `GET /cli` | Keep | Public CLI guide. | Main agent/operator CTA. | Public by design. |
| `GET /docs` | Keep | Public docs. | Helps humans choose website vs CLI. | Public by design. |
| `GET /agents/:slug` | Keep | Public company page. | Core hosted company surface. | Must not leak private billing/setup state. |
| `GET /bug-report` | Keep | Public report page. | Gives humans a reporting path. | Pair with write-rate limits. |
| `GET /techtree` | Keep | Public Techtree product page. | Current product surface. | Public by design. |
| `GET /autolaunch` | Keep | Public Autolaunch product page. | Current product surface. | Public by design. |
| `GET /token-info` | Keep | Regent token information. | Needed for staking/token context. | Public by design. |
| `GET /cards/regents-club/:token_id` | Keep | Public token card. | Useful for owned pass/share links. | Validate token id shape. |
| `GET /metadata/:token_id` | Keep | NFT metadata. | Required for token display. | Validate token id shape and avoid private data. |
| `GET /demo` | Disabled | Demo page. | Not needed for production. | Not served by the release router. |
| `GET /heerich-demo` | Disabled | Visual demo chamber. | Not needed for production. | Not served by the release router. |
| `GET /logos` | Disabled | Logo studies. | Not needed for production. | Not served by the release router. |
| `GET /shader` | Disabled | Shader study page. | Not needed for production. | Not served by the release router. |

## Public JSON APIs

| Route | Decision | What it does | Why it is necessary | Security notes |
| --- | --- | --- | --- | --- |
| `GET /api/basenames/config` | Keep | Name-claim config. | App needs current claim settings. | Public read. |
| `GET /api/basenames/allowances` | Keep | Mint allowance overview. | App needs eligibility state. | Keep response bounded. |
| `GET /api/basenames/allowance` | Keep | Wallet allowance lookup. | App needs per-wallet claim state. | Validate address. |
| `GET /api/basenames/availability` | Keep | Name availability lookup. | App needs live name checks. | Rate-limited to prevent scraping/DB churn. |
| `GET /api/basenames/credits` | Keep | Wallet credit lookup. | App needs payment credit state. | Validate address. |
| `GET /api/basenames/owned` | Keep | Wallet-owned names. | App needs current owner names. | Validate address. |
| `GET /api/basenames/recent` | Keep | Recent claimed names. | Public activity feed. | Limit is capped; keep it capped. |
| `POST /api/basenames/credit` | Keep, gated by payment verification | Registers a payment credit. | Needed if name claiming is open. | Rate-limited; payment verification remains strict. |
| `POST /api/basenames/mint` | Keep, gated by signed payload | Reserves/mints a name. | Needed if name claiming is open. | Rate-limited; signature and payment checks are critical. |
| `POST /api/basenames/use` | Keep, gated by signed payload | Marks a name as in use. | Needed for app-owned claim state. | Rate-limited. |
| `POST /api/bug-report` | Keep | Saves public bug reports. | Needed for humans and agents without sessions. | Rate-limited and sanitized. |
| `POST /api/security-report` | Keep | Saves private security reports. | Needed for vuln intake. | Rate-limited; never publish details. |
| `GET /api/opensea` | Keep | Public OpenSea holdings lookup. | Supports access/pass checks. | Rate-limited external-call route. |
| `GET /api/opensea/redeem-stats` | Keep | Public redeem stats. | Supports access/status UI. | Rate-limited external-call route; keep payload bounded/cacheable. |
| `GET /api/agent-platform/templates` | Keep | Lists company templates. | Needed by formation UI. | Public read. |
| `GET /api/agent-platform/resolve` | Keep | Resolves platform identity/company inputs. | Needed by public app flows. | Validate inputs and cache where safe. |
| `GET /api/agent-platform/agents/:slug/feed` | Keep | Public company feed. | Needed by company pages. | Must expose public events only. |
| `POST /api/agent-platform/stripe/webhooks` | Keep | Receives Stripe billing events. | Required for billing status and credits. | Stripe signature verification required; keep unauthenticated otherwise. |

Autolaunch owns auction and market state. Platform keeps the public Autolaunch entry page, but does not publish an auction API.

## Human Session APIs

| Route | Decision | What it does | Why it is necessary | Security notes |
| --- | --- | --- | --- | --- |
| `GET /api/auth/privy/csrf` | Keep | Issues CSRF token. | Required before session writes. | Token route is public by design. |
| `POST /api/auth/privy/session` | Keep | Creates human session from Privy token. | Required for signed-in app. | Requires valid Privy bearer token and CSRF. |
| `GET /api/auth/privy/profile` | Keep, gated | Reads signed-in profile. | Needed by app shell. | Requires session. |
| `PUT /api/auth/privy/profile/avatar` | Keep, gated | Saves profile avatar. | Needed for account polish. | Requires session and CSRF. |
| `DELETE /api/auth/privy/session` | Keep, gated | Signs out. | Required account control. | Requires CSRF. |
| `GET /api/auth/agent/session` | Keep, gated | Reads browser-stored agent session. | Needed by human/agent bridge. | Session route. |
| `DELETE /api/auth/agent/session` | Keep, gated | Clears browser-stored agent session. | Needed by human/agent bridge. | Requires CSRF. |
| `POST /api/auth/agent/session` | Keep, gated | Creates agent browser session. | Needed by human/agent bridge. | Requires CSRF and Platform SIWA. |
| `POST /api/agentbook/sessions/:id/submit` | Keep, gated | Human approves AgentBook trust session. | Required for human-backed trust records. | Requires human session and CSRF. |
| `GET /api/agent-platform/formation` | Keep, gated | Reads formation state. | Required by app formation flow. | Requires session. |
| `POST /api/agent-platform/billing/setup/checkout` | Keep, gated | Starts Stripe billing setup. | Required for hosted companies. | Requires session and CSRF. |
| `GET /api/agent-platform/billing/account` | Keep, gated | Reads billing account. | Required for dashboard. | Requires session. |
| `GET /api/agent-platform/billing/usage` | Keep, gated | Reads runtime usage. | Required for billing clarity. | Requires session. |
| `POST /api/agent-platform/billing/topups/checkout` | Keep, gated | Starts runtime credit top-up. | Required for hosted runtime. | Requires session and CSRF. |
| `POST /api/agent-platform/formation/companies` | Keep, gated | Starts company creation. | Core Platform app action. | Requires session, billing, eligibility, and CSRF. |
| `GET /api/agent-platform/agents/:slug/runtime` | Keep, gated | Reads private runtime status. | Required for dashboard. | Must enforce ownership. |
| `POST /api/agent-platform/ens/claims/:claim_id/prepare-upgrade` | Keep, gated | Prepares ENS upgrade. | Required for identity setup. | Requires session and CSRF. |
| `POST /api/agent-platform/ens/claims/:claim_id/confirm-upgrade` | Keep, gated | Confirms ENS upgrade. | Required for identity setup. | Requires session and CSRF. |
| `POST /api/agent-platform/agents/:slug/ens/attach` | Keep, gated | Attaches ENS to company. | Required for company identity. | Must enforce ownership. |
| `POST /api/agent-platform/agents/:slug/ens/detach` | Keep, gated | Detaches ENS from company. | Required for owner control. | Must enforce ownership. |
| `POST /api/agent-platform/agents/:slug/ens/link/plan` | Keep, gated | Plans ENS link. | Required before signing. | Must enforce ownership. |
| `POST /api/agent-platform/agents/:slug/ens/link/prepare-bidirectional` | Keep, gated | Prepares bidirectional ENS action. | Required for identity setup. | Must enforce ownership. |
| `POST /api/agent-platform/sprites/:slug/pause` | Keep, gated | Pauses hosted runtime. | Required owner control. | Must enforce ownership and log action. |
| `POST /api/agent-platform/sprites/:slug/resume` | Keep, gated | Resumes hosted runtime. | Required owner control. | Must enforce ownership and log action. |
| `GET /api/agent-platform/rwr/account` | Keep, gated | Reads the signed-in user's RWR account context. | Required before company-scoped RWR actions. | Requires session. |
| `GET /api/agent-platform/companies/:company_id/rwr/work-items` | Keep, gated | Lists company work items. | Required by `/app/work`. | Must enforce company ownership. |
| `POST /api/agent-platform/companies/:company_id/rwr/work-items` | Keep, gated | Creates a company work item. | Required for RWR work intake. | Requires session, CSRF, ownership, and current contract shape. |
| `GET /api/agent-platform/companies/:company_id/rwr/work-items/:work_item_id` | Keep, gated | Reads one work item. | Required for detail views. | Must enforce company ownership. |
| `POST /api/agent-platform/companies/:company_id/rwr/work-items/:work_item_id/runs` | Keep, gated | Starts a run for one work item. | Required for RWR execution. | Requires session, CSRF, ownership, budget policy, and worker eligibility. |
| `GET /api/agent-platform/companies/:company_id/rwr/runs/:run_id` | Keep, gated | Reads one run. | Required by `/app/runs/:id`. | Must enforce company ownership. |
| `GET /api/agent-platform/companies/:company_id/rwr/runs/:run_id/events` | Keep, gated | Reads run events. | Required for operator review. | Must not include secrets or private local machine details. |
| `GET /api/agent-platform/companies/:company_id/rwr/runs/:run_id/artifacts` | Keep, gated | Reads run artifacts. | Required before publishing proof. | Private until an operator publishes. |
| `GET /api/agent-platform/companies/:company_id/rwr/workers` | Keep, gated | Lists company workers. | Required by `/app/agents`. | Must show local OpenClaw workers as local-only for v0.1. |
| `GET /api/agent-platform/companies/:company_id/rwr/runtimes` | Keep, gated | Lists runtime profiles. | Required by `/app/runtimes`. | Must separate hosted Sprite billing from local worker usage. |
| `POST /api/agent-platform/companies/:company_id/rwr/runtimes` | Keep, gated | Creates a runtime profile. | Required for hosted worker setup. | Hosted Sprite creation must use Platform Elixir code, not the sprite CLI. |
| `GET /api/agent-platform/companies/:company_id/rwr/runtimes/:runtime_id` | Keep, gated | Reads one runtime profile. | Required for status review. | Must enforce company ownership. |
| `POST /api/agent-platform/companies/:company_id/rwr/runtimes/:runtime_id/checkpoint` | Keep, gated | Creates a runtime checkpoint. | Required for hosted runtime review. | Requires session, CSRF, ownership, and hosted runtime eligibility. |
| `POST /api/agent-platform/companies/:company_id/rwr/runtimes/:runtime_id/restore` | Keep, gated | Restores a runtime checkpoint. | Required for operator recovery. | Requires session, CSRF, ownership, and audit trail. |
| `POST /api/agent-platform/companies/:company_id/rwr/runtimes/:runtime_id/pause` | Keep, gated | Pauses a runtime profile. | Required for hosted spend control. | Requires session, CSRF, ownership, and audit trail. |
| `POST /api/agent-platform/companies/:company_id/rwr/runtimes/:runtime_id/resume` | Keep, gated | Resumes a runtime profile. | Required for hosted worker return. | Requires session, CSRF, ownership, and audit trail. |
| `GET /api/agent-platform/companies/:company_id/rwr/runtimes/:runtime_id/services` | Keep, gated | Reads runtime services. | Required for hosted runtime checks. | Must not expose service secrets. |
| `GET /api/agent-platform/companies/:company_id/rwr/runtimes/:runtime_id/health` | Keep, gated | Reads runtime health. | Required for launch checks. | Return coarse state only. |
| `GET /api/agent-platform/companies/:company_id/rwr/agents/:source_id/relationships` | Keep, gated | Lists worker relationships. | Required by `/app/agents`. | Must enforce company ownership. |
| `POST /api/agent-platform/companies/:company_id/rwr/agents/:source_id/relationships` | Keep, gated | Creates a worker relationship. | Required for trusted delegation. | Requires session, CSRF, ownership, and current relationship policy. |
| `GET /api/agent-platform/companies/:company_id/rwr/agents/:manager_id/execution-pool` | Keep, gated | Lists eligible execution workers. | Required for manager delegation. | Must keep OpenClaw local-only for v0.1. |
| `DELETE /api/agent-platform/companies/:company_id/rwr/agent-relationships/:relationship_id` | Keep, gated | Removes a worker relationship. | Required for owner control. | Requires session, CSRF, ownership, and audit trail. |

## Signed-Agent APIs

| Route | Decision | What it does | Why it is necessary | Security notes |
| --- | --- | --- | --- | --- |
| `POST /api/agentbook/sessions` | Keep, gated | Agent creates human trust session. | Required for AgentBook. | Requires shared SIWA. |
| `GET /api/agentbook/sessions/:id` | Keep, gated | Agent reads trust session status. | Required for AgentBook. | Requires shared SIWA and session ownership. |
| `GET /api/agentbook/lookup` | Keep, gated | Agent reads completed trust status. | Required for AgentBook. | Requires shared SIWA. |
| `GET /v1/agent/regent/staking` | Keep, gated | Reads Regent staking totals for the signed Agent account. | Required for CLI staking. | Requires shared SIWA. |
| `GET /v1/agent/regent/staking/account/:address` | Keep, gated | Reads Regent staking state for one wallet. | Required for CLI account inspection. | Requires shared SIWA and address validation. |
| `POST /v1/agent/regent/staking/stake` | Keep, gated | Prepares a stake transaction. | Required for CLI staking. | Requires shared SIWA. |
| `POST /v1/agent/regent/staking/unstake` | Keep, gated | Prepares an unstake transaction. | Required for CLI staking. | Requires shared SIWA. |
| `POST /v1/agent/regent/staking/claim-usdc` | Keep, gated | Prepares a USDC claim transaction. | Required for CLI staking. | Requires shared SIWA. |
| `POST /v1/agent/regent/staking/claim-regent` | Keep, gated | Prepares a REGENT claim transaction. | Required for CLI staking. | Requires shared SIWA. |
| `POST /v1/agent/regent/staking/claim-and-restake-regent` | Keep, gated | Prepares a claim-and-restake transaction. | Required for CLI staking. | Requires shared SIWA. |
| `POST /v1/agent/bug-report` | Keep, gated | Agent-authenticated bug report. | Required for CLI/agent reports. | Requires shared SIWA. |
| `POST /v1/agent/security-report` | Keep, gated | Agent-authenticated security report. | Required for vuln intake from agents. | Requires shared SIWA. |
| `POST /api/agent-platform/ens/prepare-primary` | Keep, gated | Agent prepares primary ENS action. | Needed for agent-side ENS work. | Requires shared SIWA. |
| `POST /api/agent-platform/companies/:company_id/rwr/workers` | Keep, gated | Registers a local or hosted RWR worker. | Required for Hermes, OpenClaw, Codex, and custom workers. | Requires Platform signed worker auth and company authorization. |
| `POST /api/agent-platform/companies/:company_id/rwr/workers/:worker_id/heartbeat` | Keep, gated | Updates worker check-in state. | Required for assignment and status review. | Requires signed worker auth and matching worker ownership. |
| `GET /api/agent-platform/companies/:company_id/rwr/workers/:worker_id/assignments` | Keep, gated | Lists worker assignments. | Required for worker polling. | Requires signed worker auth and matching worker ownership. |
| `POST /api/agent-platform/companies/:company_id/rwr/assignments/:assignment_id/claim` | Keep, gated | Claims an assignment. | Required for worker execution. | Requires signed worker auth and current assignment eligibility. |
| `POST /api/agent-platform/companies/:company_id/rwr/assignments/:assignment_id/release` | Keep, gated | Releases an assignment. | Required when a worker cannot continue. | Requires signed worker auth and audit trail. |
| `POST /api/agent-platform/companies/:company_id/rwr/assignments/:assignment_id/complete` | Keep, gated | Completes an assignment. | Required for run progress. | Requires signed worker auth and bounded output. |
| `POST /api/agent-platform/companies/:company_id/rwr/runs/:run_id/events` | Keep, gated | Appends a normalized run event. | Required for run history. | Requires signed worker auth and no secrets in event payloads. |
| `POST /api/agent-platform/companies/:company_id/rwr/runs/:run_id/artifacts` | Keep, gated | Creates a run artifact record. | Required for proof review. | Requires signed worker auth; artifact stays private until published. |
| `POST /api/agent-platform/companies/:company_id/rwr/runs/:run_id/delegations` | Keep, gated | Requests delegation to an eligible worker. | Required for manager-to-worker handoff. | Requires signed worker auth; Regent resolves targets but does not plan the work. |

## Runtime And Dev Routes

| Route | Decision | What it does | Why it is necessary | Security notes |
| --- | --- | --- | --- | --- |
| `WS /live/websocket` | Keep | LiveView realtime connection. | Required for Phoenix pages. | Origin checking is enabled. |
| `GET /live/longpoll` | Disabled | LiveView fallback transport. | Not needed for the production browser target. | Not served by the release socket config. |
| `POST /live/longpoll` | Disabled | LiveView fallback transport. | Not needed for the production browser target. | Not served by the release socket config. |
| `GET /dev/dashboard*` | Disable | Phoenix dev dashboard. | Not needed on Fly production. | `dev_routes` must remain off in prod. |
| `* /dev/mailbox` | Disable | Local mailbox preview. | Not needed on Fly production. | `dev_routes` must remain off in prod. |
