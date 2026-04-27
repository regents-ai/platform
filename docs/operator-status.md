# Platform Operator Status

This document defines how Platform should explain company and operator state during stabilization.

Use it for dashboard text, release review, and future page changes that touch billing, company opening, hosted runtime, reports, public records, or trust approval.

Launch, Fly deploy, and cross-product testing commands live in `/Users/sean/Documents/regent/docs/regent-local-and-fly-launch-testing.md`.

## Operator Promise

Every Platform operator surface should answer four questions:

- What happened?
- What is happening now?
- What needs action?
- What happens next?

If a page cannot answer those questions, the release is not ready.

## Status Model

| State | Meaning | Required next-action copy |
| --- | --- | --- |
| `live` | The company, billing, report, room, or public page is usable now | Tell the person what they can do now |
| `pending` | Platform has accepted the request and is still working | Tell the person what is being checked and whether the page updates on its own |
| `needs-attention` | The person or operator must do something before progress continues | Name the action and where to take it |
| `failed` | The last attempt did not complete | Say what did not complete and the safest next step |
| `preview` | The surface is visible but is not the source of truth | Say that it is a preview and point to the live source |

Use these states in docs and operator reasoning even when a page shows friendlier labels.

## Required Attention Areas

Platform stabilization focuses on:

- access and pass checks
- name claims
- billing setup and top-ups
- company opening progress
- hosted runtime status
- public company page readiness
- bug and security report receipts
- trust approval status
- room readiness and owner actions

Each area needs a clear next action or a clear "no action needed" state.

## Internal Issue Ledger

Platform keeps one internal issue ledger for user-visible operational problems. The first version covers billing, runtime usage, top-ups, room setup, launch or provisioning, and formation readiness.

Use the ledger to feed account and operator pages. Do not turn it into a public diagnostics page. Public pages should show the safe next action, not private service details.

## Release Review

Before Platform is included in a release:

- Confirm `/app` routes a person to the right setup step.
- Confirm billing success, billing cancel, and billing still-pending states explain what happens next.
- Confirm company opening progress shows the current step and does not mark a company live before the hosted service is ready.
- Confirm dashboard runtime controls show live, paused, pending, and failed states in plain English.
- Confirm bug and security reports return a receipt the person can use.
- Confirm public company pages do not show private setup or billing state.
- Confirm `/healthz` and `/readyz` match the release expectation.
- Run `mix platform.doctor`.
- Run `mix platform.beta_smoke --host https://<platform-host>`.
- Preview the run sheet entry with `mix platform.beta_report --host https://<platform-host> --dry-run`.

## Copy Rules

Use customer-facing text that says what the person can do, what happens next, and why it matters.

Avoid explaining how the app is built, how requests move through the system, or how old behavior used to work.
