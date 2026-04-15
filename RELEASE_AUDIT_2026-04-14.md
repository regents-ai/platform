# Release Audit 2026-04-14

This note replaces the stale audit summaries that were produced against an older build.

## Fix

### Privy session trusted a posted wallet address
- Status: fixed
- What changed: session sign-in now reads the wallet list from Privy's verified identity token claim instead of trusting `walletAddress` from the request body.
- Evidence:
  - [lib/platform_phx/privy.ex](/Users/sean/Documents/regent/platform/lib/platform_phx/privy.ex)
  - [lib/platform_phx_web/controllers/api/privy_session_controller.ex](/Users/sean/Documents/regent/platform/lib/platform_phx_web/controllers/api/privy_session_controller.ex)
  - [test/platform_phx_web/controllers/api/privy_session_controller_test.exs](/Users/sean/Documents/regent/platform/test/platform_phx_web/controllers/api/privy_session_controller_test.exs)

### Session-backed JSON writes were missing request protection
- Status: fixed
- What changed: cookie-backed JSON write routes now require the request-protection token, and the dashboard sends it on write requests.
- Evidence:
  - [lib/platform_phx_web/router.ex](/Users/sean/Documents/regent/platform/lib/platform_phx_web/router.ex)
  - [assets/js/dashboard/islands.tsx](/Users/sean/Documents/regent/platform/assets/js/dashboard/islands.tsx)
  - [test/platform_phx_web/controllers/api/agent_platform_controller_test.exs](/Users/sean/Documents/regent/platform/test/platform_phx_web/controllers/api/agent_platform_controller_test.exs)

### Company launch marked the service ready before a health check
- Status: fixed
- What changed: launch now verifies the sprite service is active before the public hostname is turned on or the company is marked ready.
- Evidence:
  - [lib/platform_phx/agent_platform/workers/run_formation_worker.ex](/Users/sean/Documents/regent/platform/lib/platform_phx/agent_platform/workers/run_formation_worker.ex)
  - [lib/platform_phx/agent_platform/formation_run.ex](/Users/sean/Documents/regent/platform/lib/platform_phx/agent_platform/formation_run.ex)
  - [test/platform_phx_web/controllers/api/agent_platform_controller_test.exs](/Users/sean/Documents/regent/platform/test/platform_phx_web/controllers/api/agent_platform_controller_test.exs)

## Won’t Fix

### “XMTP or group chat is missing”
- Status: won’t fix
- Reason: this finding is not true for the current repo. XMTP room records, room services, page flows, and tests are already present.
- Evidence:
  - [lib/platform_phx/xmtp.ex](/Users/sean/Documents/regent/platform/lib/platform_phx/xmtp.ex)
  - [lib/xmtp/room_server.ex](/Users/sean/Documents/regent/platform/lib/xmtp/room_server.ex)
  - [test/platform_phx/xmtp_test.exs](/Users/sean/Documents/regent/platform/test/platform_phx/xmtp_test.exs)

### “Stripe billing and top-ups are only local flag flips”
- Status: won’t fix
- Reason: this finding is not true for the current repo. The code already creates Stripe checkout sessions, verifies webhook signatures, and applies billing changes from webhook jobs.
- Evidence:
  - [lib/platform_phx/agent_platform/stripe_billing.ex](/Users/sean/Documents/regent/platform/lib/platform_phx/agent_platform/stripe_billing.ex)
  - [lib/platform_phx_web/controllers/api/stripe_webhook_controller.ex](/Users/sean/Documents/regent/platform/lib/platform_phx_web/controllers/api/stripe_webhook_controller.ex)
  - [lib/platform_phx/agent_platform/workers/sync_stripe_billing_worker.ex](/Users/sean/Documents/regent/platform/lib/platform_phx/agent_platform/workers/sync_stripe_billing_worker.ex)

### “Audit Solidity contracts in this repo”
- Status: won’t fix
- Reason: there are no Solidity source files in this repository, so that audit belongs to the repo that owns those contracts.

## Not Important

### Broad copy cleanup tied to the stale audit
- Status: not important for this pass
- Reason: the release-critical work was securing sign-in, protecting cookie-backed writes, and tightening launch readiness. A repo-wide copy sweep is separate work unless a specific page still promises behavior the code does not provide.
