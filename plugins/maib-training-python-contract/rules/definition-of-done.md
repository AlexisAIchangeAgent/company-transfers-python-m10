# Definition of done, and when to stop and ask

Done means all of these, run from the repository root:

1. `python -m pytest` green, with no new warning.
2. `python -m behave`: no new failure and no undefined step. The night scenario may stay
   red, and any red scenario is named with its reason in the commit message.
3. `python -m ruff check .` and `python -m ruff format --check .` clean.
4. New behaviour has tests written with it; money stays `Decimal`; boundaries respected.

Stop and ask a human before:

- changing any fee rule, rounding mode, limit or rule name, or touching the EUR rounding;
- implementing the night rule, or inventing a definition of "night";
- editing `.github/workflows/`, `.env` or `privacy-agent/requests/`;
- adding a dependency, an endpoint, or a call to a real network service;
- anything that needs a customer's real data, or sends a reply to a requester;
- two sources disagree (tariff, code, docs, feature) and "Source of truth" does not settle it;
- a check fails for a reason you did not cause.
