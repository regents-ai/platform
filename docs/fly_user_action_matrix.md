# Fly User Action Matrix

This matrix lists what a person or signed agent can do in the Platform Fly app now, and how each action should behave for the release.

| Surface | User action | Launch state | Protection | Notes |
| --- | --- | --- | --- | --- |
| Public site | Read home, docs, CLI, Techtree, Autolaunch, token info | Live now | Public browser route | Keep these fast and stable. |
| Public company pages | Read a hosted company page | Live now | Public browser route | Public company data only. |
| Public company pages | Send or manage company room messages | Live now | Room-level checks | Keep owner-only room actions scoped to the owner. |
| Reports | Submit a bug report | Live now | Public rate limit | No private report content is rendered publicly. |
| Reports | Submit a security report | Live now | Public rate limit | Keep details private. |
| Access | Sign in with Privy | Live now | CSRF plus Privy token verification | Required before private app actions. |
| Identity | Save avatar choice | Live now | Human session and CSRF | Holdings checks remain server-side. |
| AgentBook | Create/read agent trust session | Live now | Shared SIWA | Agent-owned session data only. |
| AgentBook | Submit human approval | Live now | Human session and CSRF | Requires the signed-in human. |
| Basenames | Check name availability | Live now | Public rate limit | Bounded read. |
| Basenames | Register credit, mint, mark in use | Live now | Signed payload plus public rate limit | Keep signature and payment checks strict. |
| Collectibles | Check holdings or redeem stats | Live now | Public rate limit | External-call surface. |
| $REGENT staking browser page | Read staking overview and wallet staking view on `/token-info` | Live now | Public browser route; wallet actions require a signed-in human | Chain state only. The user still signs every wallet transaction. |
| $REGENT staking signed-agent API | Read staking overview and wallet staking view through `/v1/agent/regent/staking...` | Live now | Shared SIWA signed-agent auth | Used by Regents CLI and agent clients. |
| $REGENT staking signed-agent API | Prepare stake, unstake, claim, claim-and-restake through `/v1/agent/regent/staking...` | Live now | Shared SIWA signed-agent auth | Prepares wallet transactions only; the caller still signs. |
| Billing | Start billing setup | Visible but disabled while formation is closed | Human session and CSRF | Reopens when company opening is enabled. |
| Billing | Add runtime credit | Visible but disabled while formation is closed | Human session and CSRF | Reopens when company opening is enabled. |
| Company opening | Open a hosted company | Visible but disabled while formation is closed | Human session, CSRF, eligibility, billing | The page stays useful, but the action does not run. |
| Company runtime | Pause or resume a company | Visible but disabled while formation is closed | Human session, CSRF, ownership, audit log | Owner controls return when company opening is enabled. |
| RWR work | Review work items and runs | Live when the signed-in owner has a company | Human session and ownership | `/app/work` and `/app/runs/:id` must show only that company's work. |
| RWR work | Create work and start a run | Gated by company ownership, worker eligibility, and budget policy | Human session, CSRF, ownership | The manager chooses the work plan; Regent checks authorization and limits. |
| RWR workers | Register local Hermes or OpenClaw worker | Local-only for v0.1 unless a hosted worker is selected | Signed worker request and company authorization | OpenClaw stays on the user's machine for v0.1. Do not require Platform-hosted OpenClaw secrets. |
| RWR workers | Register hosted Codex or custom worker | Hosted-company gate required | Signed worker request, company authorization, billing state | Hosted workers use the Platform billing and runtime credit path. |
| RWR worker loop | Heartbeat, read assignments, claim, release, complete, append events, create artifacts, request delegation | Live for registered workers | Signed worker request and worker ownership | Events and artifacts stay private until an operator publishes proof. |
| RWR runtimes | Create, inspect, checkpoint, restore, pause, or resume runtime profiles | Hosted runtime actions require hosted-company gate | Human session, CSRF, ownership, audit log | Platform manages Sprites through Elixir code; sprite CLI commands are local/operator smoke checks only. |
| RWR publishing | Publish work, worker, runtime, relationship, checkpoint, or artifact proof | Explicit operator action only | Human session, CSRF, ownership, review state | Nothing from RWR becomes public by default. |
| RWR billing | Compare hosted and local usage | Live in owner views | Human session and ownership | Hosted Sprite work spends Platform runtime credits; local Hermes and OpenClaw work remains user-local and may be self-reported. |
| Stripe | Receive billing webhook | Live now | Stripe signature over raw body | Jobs are unique by Stripe event id. |
| Metrics | Scrape Prometheus metrics | Internal only | Private Fly metrics port | Not part of the public product contract. |
