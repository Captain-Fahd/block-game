# 003. Organisation Play developer account

Date: 2026-11-11
Status: Accepted

## Context
Personal Play accounts created after 13 Nov 2023 must run a closed test with at least 12 testers opted in for 14 continuous days before getting production access. Organisation accounts are exempt, need a D-U-N-S number (Omar already has one, plus an ABN), and can show a studio name instead of a legal name.

## Decision
Register an **organisation** developer account.

## Consequences
- No 12-tester × 14-day gate, so P9.3 becomes optional. A small closed or internal test is still worthwhile for feedback, but it no longer blocks production.
- Organisation verification (D-U-N-S matching, website, contact details) can take longer than personal verification. Start P0.6 early.
- The developer name shown on Play is the organisation's name, so the privacy policy and website should use the same name.
- Package prefix: `com.omarfahd`.
