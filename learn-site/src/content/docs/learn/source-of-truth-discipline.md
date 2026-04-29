---
title: Source-of-truth discipline
description: Source-of-truth discipline keeps product claims, contracts, money state, and local operator state from drifting.
updated: 2026-04-29
owner: Platform
status: beta
---

Updated: 2026-04-29  
Status: beta  
Owner: Platform

## Short answer

Source-of-truth discipline means every important Regent claim has a clear owner. Product contracts define public API and CLI surfaces, product services own workflow state, onchain state wins for money state, and local CLI state is downstream.

## Canonical definition

Source-of-truth discipline is the Regent rule that assigns one winner for each class of fact before pages, clients, agents, or operators rely on it.

## Why it matters

Agent systems become hard to trust when mirrors and cached views disagree. Clear ownership makes errors easier to detect and explain.

## How it works in Regents

Platform owns the guided human path. Techtree owns research workflow. Autolaunch owns launch workflow. Shared SIWA owns signed identity proof. Regents CLI reads from product and chain truth rather than replacing it.

## What this does not claim

This does not mean every source is always available or every mirror is always current. It means the winning record is declared before there is a disagreement.

## Related concepts

- [Source-of-truth matrix](/source/source-of-truth-matrix/)
- [Regents CLI purpose](/source/regents-cli-purpose/)
- [SIWA](/glossary/siwa/)

## FAQ

### What wins for money state?

Onchain state wins for balances, ownership, staking, and revenue distribution.

### What wins for workflow state?

The product that owns the workflow wins.
