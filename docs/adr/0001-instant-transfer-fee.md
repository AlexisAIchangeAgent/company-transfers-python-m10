Training material. Invented data.

# ADR 0001: Fee of an instant transfer

Status: implemented in commit `57b8c9c` (2026-10-14); product decision pending.
The acceptance criteria say "product decision pending" (`features/instant-fee.feature:7`) and the
published tariff says "The instant fee is not published yet" (`docs/fee-rules.md:22`).
MISSING: who accepted this decision and when. No file records an approval.

Citations: `file:line` refer to the repository at HEAD. The files cited from `src/`, `tests/`,
`features/` and `docs/fee-rules.md` are unchanged since `57b8c9c` (`git diff 57b8c9c HEAD`
lists only `src/company_transfers/domain/iban.py` and `tests/unit/test_iban_mask.py`). A bare hash
is a commit.

## Context

- `POST /fees` takes `type` equal to `standard` or `instant` (`src/company_transfers/api/schemas.py:14`).
  Before `57b8c9c`, an instant request was refused with `UnsupportedTransferError("instant transfers
  not supported yet")` (`git show 57b8c9c -- src/company_transfers/domain/fees.py`), and a unit test
  `tests/unit/test_instant_fee_not_supported.py` asserted that refusal (same commit, deleted).
- The published tariff covers standard transfers only: MDL 0.5%, minimum 5.00, maximum 50.00, EUR
  converted first (`docs/fee-rules.md:8-18`). Its section on instant transfers states no fee
  (`docs/fee-rules.md:20-22`). The tariff says fees charged must match it (`docs/fee-rules.md:5-6`).
- The only specification of the instant fee is the list of acceptance criteria in
  `features/instant-fee.feature:7-11`:
  - a retail customer pays the standard fee plus a flat fee of MDL 10.00;
  - a premium customer pays the standard fee only, the flat fee is waived;
  - an instant transfer above MDL 100,000.00, or the equivalent in EUR, is rejected;
  - an EUR amount is converted to MDL first, then the MDL rule applies.
- The same file contains a ninth scenario, "Instant transfer at night": "Instant transfers at night cost
  MDL 5.00 more", expected fee 25.00 for MDL 2000.00 retail (`features/instant-fee.feature:49-55`).
- The project contract says that changing a fee rule, or implementing the night rule or inventing a
  definition of "night", needs a human's approval (`CLAUDE.md`, section 4 and the table "Execution
  control"). It also says the instant fee rules come from the acceptance criteria (`CLAUDE.md`,
  "Source of truth and known conflicts").

## Decision

Implement the four acceptance criteria of `features/instant-fee.feature:7-11` in
`FeeCalculator` (`src/company_transfers/domain/fees.py`), and leave the night scenario red. The subject
of `57b8c9c` says "test first"; code and tests are in one commit, so the history does not show the order.

1. The instant fee is the standard fee plus `INSTANT_FLAT_FEE = Decimal("10.00")` for a retail customer;
   a premium customer pays the standard fee (`fees.py:20,59-60`).
2. An instant request whose amount in MDL is strictly above `INSTANT_MAX_AMOUNT_MDL = Decimal("100000.00")`
   raises `UnsupportedTransferError("limit exceeded")` (`fees.py:21,57-58`). `main.py` turns it into
   422 `{"error": "limit exceeded"}` (`src/company_transfers/main.py:31-33`). The limit error reuses
   `UnsupportedTransferError` (`57b8c9c`, message).
3. An EUR amount goes through the existing standard EUR path: conversion to MDL, then the MDL bounds
   (`fees.py:48-54,62-64`). No new conversion or rounding code was written for instant (`fees.py:43-45`).
4. The rule names are `instant-mdl` and `instant-eur` (`fees.py:28-29,60`; `57b8c9c`, message).
5. The night scenario is not implemented. Its step `it is night` raises `NotImplementedError`
   (`features/steps/instant_fee_steps.py:27-31`). The reason recorded: "no definition of night, no
   clock input, no rule for premium or for the limit check" (`57b8c9c`, message).
6. `docs/fee-rules.md` is not changed (`57b8c9c`, message).

Tests written with the code:

- Unit: `tests/unit/test_instant_fee.py:16` (retail), `:29` (premium), `:47` (MDL limit), `:54` (EUR),
  `:66` (EUR limit).
- Behave: `features/instant-fee.feature:17-47`, through the HTTP layer with `FixedRateClient`
  (`features/environment.py:12-14`).
- Result recorded in the commit: "8 of 9 scenarios pass, exit code 1 because of the night scenario"
  (`57b8c9c`). I re-ran behave on 2026-10-14 in the working tree (HEAD plus the uncommitted `CLAUDE.md` change): 8 scenarios passed, 1 error
  (`features/instant-fee.feature:49`), exit code 1.

## Alternatives considered

The repository records two alternatives. No file records any other.

| Alternative | Outcome | Source |
|---|---|---|
| Keep rejecting every instant transfer ("not supported yet") | Dropped: the old test "contradicts the criteria" and was removed | `57b8c9c`, message |
| Also implement the night rule (+5.00) | Not done: ambiguous, and `CLAUDE.md` forbids inventing a definition of "night" without approval | `57b8c9c`, message; `CLAUDE.md`, section 4 |

MISSING: any record of alternatives for the amounts (10.00 flat fee, 100,000.00 limit), for the
flat fee applying to retail only, or for publishing the instant fee in the tariff before building it.

## Consequences

- The service charges an instant fee that the published tariff does not state (`fees.py:59-60` against
  `docs/fee-rules.md:22`). The only written source for the amounts is the feature file
  (`CLAUDE.md`, "Source of truth and known conflicts"). MISSING: the published instant tariff.
- Instant EUR transfers inherit the open EUR rounding conflict: the code truncates the converted
  amount and rounds the fee half even (`fees.py:53,64`), the tariff says the converted amount is not
  rounded and the fee is rounded half up (`docs/fee-rules.md:16-17`). See
  `README.md:165-167` and `incidents/INC-2026-0412.md`. This ADR does not settle it.
- The limit is inclusive: exactly MDL 100,000.00 is accepted, because the test is `>`
  (`fees.py:57`). For EUR, the limit applies to the converted amount truncated to 2 decimals
  (`fees.py:62-64`).
- The standard fee, and so the exchange-rate call for EUR, is computed before the limit check
  (`fees.py:43-45,52`). An EUR instant request above the limit therefore returns 502 if the rate
  is unavailable (`main.py:35-37`), not 422.
- A premium customer pays no flat fee on any instant transfer (`fees.py:59`). The segment still has no
  effect on a standard transfer (`fees.py:46`).
- One scenario stays red, so `python -m behave` exits with code 1. The definition of done allows
  this if the scenario is named with its reason in the commit message (`CLAUDE.md`, section 4).
- The feature file expects 25.00 for the night scenario and the service returns 20.00 for the same
  request (`features/instant-fee.feature:55`; `fees.py:59-60`).
  MISSING: the definition of "night" and how the service learns the time (`CLAUDE.md`, section 3).
- Callers get 422 `limit exceeded` through HTTP in behave only. pytest tests it at the calculator
  (`tests/unit/test_instant_fee.py:47,66`), not at the HTTP layer.
- Changing the flat fee, the limit or the rule names later is a change of fee rule and needs
  approval (`CLAUDE.md`, section 4).
