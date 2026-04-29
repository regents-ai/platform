---
title: SIWA purpose
description: Shared SIWA provides signed identity and request authenticity for Regent services.
updated: 2026-04-29
owner: Shared SIWA
status: beta
---

Updated: 2026-04-29  
Status: beta  
Owner: Shared SIWA

## Short answer

Shared SIWA provides signed identity and request authenticity for Regent services.

## Canonical definition

Shared SIWA verifies wallet-backed identity, nonce and replay rules, receipts, and signed request envelopes for supported Regent products.

## Why it matters

Trust rails should be shared where identity proof is common, while product-specific action rules stay with the product.

## How it works in Regents

SIWA verifies who is acting. Platform, Techtree, Autolaunch, and other products decide what that actor can do in their own workflows.

## What this does not claim

SIWA does not replace product authorization.

## Related concepts

- [SIWA](/glossary/siwa/)
- [Sovereign agents](/learn/sovereign-agents/)
- [Source-of-truth discipline](/learn/source-of-truth-discipline/)

## FAQ

### Why keep identity shared?

Shared identity proof reduces drift across products.
