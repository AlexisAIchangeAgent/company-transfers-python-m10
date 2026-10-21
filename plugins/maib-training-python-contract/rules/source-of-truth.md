# Source of truth and known conflicts

- Fee amounts: `docs/fee-rules.md` wins over code, over `docs/README-service.md` and over
  the feature file. Fees charged must match the published tariff.
- `docs/README-service.md` is stale (reviewed March 2025): it says maximum fee 40.00,
  banker's rounding and a `GET /fees/{id}` endpoint. None of this matches code or tariff.
  Do not use it.
- EUR rounding conflicts with the tariff (open, INC-2026-0412). The tariff says half up and
  "the converted amount is not rounded". The code truncates the converted amount and rounds
  the fee half even. Do not change it as a side effect of another task: ask first.
- The instant fee is not in the published tariff ("product decision pending"). Its rules come
  from the acceptance criteria in `features/instant-fee.feature`.
