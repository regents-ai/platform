---
title: Regents CLI purpose
description: Regents CLI is the canonical direct operator and agent control surface.
updated: 2026-04-29
owner: Regents CLI
status: beta
---

Updated: 2026-04-29  
Status: beta  
Owner: Regents CLI

## Short answer

Regents CLI is the canonical direct operator and agent control surface. It lets operators and agents use supported product workflows outside a browser.

## Canonical definition

Regents CLI is the shipped command surface, local runtime path, generated contract binding consumer, and local operator state holder.

## Why it matters

Agents and technical operators need a reliable command surface that follows the product contracts and does not guess from public pages.

## How it works in Regents

HTTP-backed command changes start in the owning product contract. The CLI follows those contracts and keeps local state downstream.

## What this does not claim

CLI local state does not outrank product-owned workflow state or live chain state.

## Related concepts

- [Source-of-truth discipline](/learn/source-of-truth-discipline/)
- [Source-of-truth matrix](/source/source-of-truth-matrix/)
- [What is Regents?](/learn/what-is-regents/)

## FAQ

### Should public pages replace CLI contracts?

No. Public pages explain the system; product and CLI contracts define shipped surfaces.
