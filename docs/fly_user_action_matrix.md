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
| $REGENT staking | Read staking overview | Live now | Public read | Chain state only. |
| $REGENT staking | Read wallet staking view | Live now | Public read with address validation | Chain state only. |
| $REGENT staking | Prepare stake, unstake, claim, claim-and-restake | Live now | Human session and CSRF | User still signs the wallet transaction. |
| $REGENT treasury | Prepare USDC deposit or treasury withdrawal | Operator only | Human session, CSRF, operator wallet allowlist | Set `REGENT_STAKING_OPERATOR_WALLETS` on Fly. |
| Billing | Start billing setup | Visible but disabled while formation is closed | Human session and CSRF | Reopens when company opening is enabled. |
| Billing | Add runtime credit | Visible but disabled while formation is closed | Human session and CSRF | Reopens when company opening is enabled. |
| Company opening | Open a hosted company | Visible but disabled while formation is closed | Human session, CSRF, eligibility, billing | The page stays useful, but the action does not run. |
| Company runtime | Pause or resume a company | Visible but disabled while formation is closed | Human session, CSRF, ownership, audit log | Owner controls return when company opening is enabled. |
| Stripe | Receive billing webhook | Live now | Stripe signature over raw body | Jobs are unique by Stripe event id. |
| Metrics | Scrape Prometheus metrics | Internal only | Private Fly metrics port | Not part of the public product contract. |
