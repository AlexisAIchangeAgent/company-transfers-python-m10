# CLAUDE.md: company-transfers-python

Training material: invented bank, invented data. Company Bank SA does not exist.

This file is the working contract for this repository, for Claude Code and for developers.
Section 1 holds verified facts, section 2 assumptions, section 3 missing information,
section 4 the definition of done. The unnumbered sections (Architecture boundaries,
Conventions, Source of truth) are rules, not facts.

## 1. Facts (checked against the repository)

### Purpose and stack

HTTP service that computes the fee of a customer transfer before confirmation.
`POST /fees` takes `amount`, `currency` (MDL, EUR), `type` (standard, instant) and
`customer_segment` (retail, premium). It returns `{"fee", "currency": "MDL", "rule"}`.
`GET /health` returns `{"status": "ok"}`. No other endpoint exists.

- Python `>=3.10` (`pyproject.toml`); src layout, setuptools. FastAPI, uvicorn, pydantic v2,
  simplejson (Decimal to JSON number). Last run here: Python 3.14.7.
- Dev extra: pytest, httpx2 (TestClient), behave, ruff, pact-python, pytest-playwright,
  claude-agent-sdk. Pact and Playwright are declared but have no code or test yet; the agent has code, no test.
- Configuration: `RATES_BASE_URL`, `RATES_API_KEY`, `RATES_TIMEOUT_SECONDS`, read only in
  `config.Settings.from_env()`. Without `RATES_BASE_URL`, `FixedRateClient` (rate 19.8765, no
  network) is used. `.env` is committed with fake values and is not loaded automatically.

### Layout

```
src/company_transfers/
  main.py     create_app() factory, module-level `app`, picks the rate client, maps errors to HTTP
  config.py   Settings
  api/        routes.py, schemas.py (request/response bodies, DecimalJSONResponse)
  domain/     models.py (enums, frozen dataclasses), fees.py (FeeCalculator), iban.py (mask_iban)
  clients/    exchange_rate.py (ExchangeRateClient protocol, Http and Fixed clients)
tests/unit/   pytest; conftest.py has fixtures `calculator` and `client` (FixedRateClient, 20.0000)
features/     behave: instant-fee.feature, environment.py, steps/instant_fee_steps.py
docs/         fee-rules.md (published tariff), README-service.md, pipeline/ci.yml (template of the active pipeline)
crm/          static CRM page (customer-lookup.html)
incidents/    INC-2026-0412.md (disputed EUR fee, open)
privacy-agent/  policy.md, requests/, agent.py (intake agent), SCOPE.md
                README.md, requirements.txt, output/ (triage records, audit.log)
run-local.ps1   Windows: start/stop the service in the background
step-1..3-*     onboarding scripts (check tools, install tools, install dependencies)
Makefile        macOS/Linux shortcuts (install, run, test, bdd, lint, format, playwright-install)
README.md, INSTALL-TOOLS.md, requirements-dev.txt (`-e .[dev]`)
docs/adr/       empty
.claude/settings.json   permissions
.claude-plugin/, plugins/maib-training-python-contract/   local plugin: the working contract
```

### Commands (each one run from the repository root on Windows; `.venv` exists)

On macOS and Linux replace `.venv\Scripts\python` with `.venv/bin/python`.

| Task | Command | Result when run |
|---|---|---|
| Unit tests | `.venv\Scripts\python -m pytest` | 71 passed, exit 0 |
| One test | `.venv\Scripts\python -m pytest tests/unit/test_standard_mdl_fee.py -k minimum` | 4 passed |
| BDD | `.venv\Scripts\python -m behave` | 8 scenarios pass, 1 error, exit 1 (expected, see "Behaviour implemented") |
| Lint | `.venv\Scripts\python -m ruff check .` | All checks passed |
| Format check | `.venv\Scripts\python -m ruff format --check .` | 42 files already formatted |

Exist but not run here (they install, rewrite files or start a server): `Makefile` targets
(`make` is not installed on Windows), `ruff format .`, `ruff check --fix .`,
`pip install -r requirements-dev.txt`, `playwright install chromium`, `run-local.ps1`.
Run command (also used by `run-local.ps1`):
`python -m uvicorn company_transfers.main:app --reload --port 8000`.
pytest collects `tests/unit` only; behave collects `features/`.

### Behaviour implemented

- Standard MDL: 0.5% of the amount, minimum 5.00, maximum 50.00, half up to 2 decimals.
- Standard EUR: converted to MDL (the converted amount is not rounded), then the MDL rule
  applies: the fee is rounded half up and bounded. Rule name `standard-eur`.
- Instant: standard fee, plus MDL 10.00 for retail. Premium pays the standard fee. Above
  MDL 100,000.00 (converted for EUR, compared on whole cents truncated): 422
  `{"error": "limit exceeded"}`. Rules
  `instant-mdl`, `instant-eur`.
- `UnsupportedTransferError` becomes 422 `{"error": <message>}`; `ExchangeRateError` becomes
  502 `{"error": "exchange rate unavailable"}`. Invalid bodies give FastAPI's 422.
- Not implemented: instant transfer at night. Its scenario fails because the step
  `it is night` raises `NotImplementedError`. This stays red until the rule is specified.

## Architecture boundaries

- Direction: `api -> domain -> clients`. Never the reverse. `main.py` wires all three.
- `api` maps HTTP bodies to domain objects and back. No fee rule here.
- `domain` holds every fee rule. No FastAPI, no HTTP, no urllib. It depends on the
  `ExchangeRateClient` protocol, never on a concrete client.
- `clients` talks to third parties only. Network code stays here.
- Configuration is read in `config.Settings` only; no `os.environ` anywhere else.
- Error to HTTP mapping lives in `main.py`; domain code raises exceptions, not responses.

## Conventions

- PEP 8, ruff rules E, F, I, B, UP, SIM, line length 100, formatted by `ruff format`.
- Modules, functions, variables `snake_case`; classes `PascalCase`; constants `UPPER_CASE`.
  One sub-package per layer. Type hints on public functions.
- Enums derive from `_TextEnum(str, Enum)` in `domain/models.py` (not `StrEnum`, to run on
  3.10). Value objects are frozen dataclasses.
- Money is `decimal.Decimal`, never `float`. Build from strings, quantize to 2 decimals with
  an explicit rounding mode. Fees are in MDL. The API writes `fee` through
  `DecimalJSONResponse`.
- Tests: `tests/unit/test_<topic>.py`, `test_<subject>_<expected_behaviour>`, arrange / act /
  assert, `pytest.mark.parametrize` for cases. No network: use `FixedRateClient` or a fake
  `ExchangeRateClient`. Compare money as `Decimal`; parse JSON with `parse_float=Decimal`.
- BDD: steps in `features/steps/`, one per Gherkin step, no fee logic. `environment.py`
  gives each scenario `context.client` and `context.rate_client` (rate 19.8765).

## Source of truth and known conflicts

- Fee amounts: `docs/fee-rules.md` wins over code, over `docs/README-service.md` and over
  the feature file. Fees charged must match the published tariff.
- `docs/README-service.md` is stale (reviewed March 2025): it says maximum fee 40.00,
  banker's rounding and a `GET /fees/{id}` endpoint. None of this matches code or tariff.
  Do not use it.
- EUR rounding was fixed to follow the tariff (INC-2026-0412, confirmed by the Product Owner):
  the converted amount is not rounded and the fee is rounded half up. EUR 123.01 at 19.8765
  now gives 12.23 (was 12.22). Instant EUR fees change the same way. Whether to report the
  past difference to Compliance is still open.
- The instant fee is not in the published tariff ("product decision pending"). Its rules come
  from the acceptance criteria in `features/instant-fee.feature`.

## 2. Assumptions (not verifiable from the repository)

- CI runs Python 3.11: `.github/workflows/ci.yml` (active) declares it, but no run result was
  seen here. It runs `pytest` only, not `behave` or `ruff`.
- The EUR to MDL provider contract in `clients/exchange_rate.py` matches the real provider.
- The fake `.env` values are for training only.

## 3. Missing information

- Whether to report the past EUR fee difference to Compliance, and whether to correct the fees
  already charged (INC-2026-0412).
- What "night" means for instant transfers, and how the service learns the time.
- The published instant-transfer tariff.
- Supported Python versions in practice: CI tests 3.11 only, local runs
  used 3.14; 3.10 (the `pyproject.toml` minimum) is untested.

## 4. Definition of done, and when to stop and ask

Done means all of these, run from the repository root:

1. `python -m pytest` green, with no new warning.
2. `python -m behave`: no new failure and no undefined step. The night scenario may stay
   red, and any red scenario is named with its reason in the commit message.
3. `python -m ruff check .` and `python -m ruff format --check .` clean.
4. New behaviour has tests written with it; money stays `Decimal`; boundaries respected.

Stop and ask a human before:

- changing any fee rule, rounding mode, limit or rule name;
- implementing the night rule, or inventing a definition of "night";
- editing `.github/workflows/`, `.env` or `privacy-agent/requests/`;
- adding a dependency, an endpoint, or a call to a real network service;
- anything that needs a customer's real data, or sends a reply to a requester;
- two sources disagree (tariff, code, docs, feature) and section "Source of truth" does not
  settle it;
- a check fails for a reason you did not cause.

## Execution control

Limits for Claude Code on every task. The team owns them; the release manager can rely on them.

Budget: at most 30 tool calls per task and at most 2 retries per failing step.
Stop as soon as the definition of done (section 4) holds and the acceptance criteria pass.
Escalate to a human after the second failed retry, when sources conflict, or when evidence
is missing. Say what was tried, what failed, and what is needed.

The pipeline `.github/workflows/ci.yml` is active: `build-and-test` runs `pytest` on Python 3.11
for every push and pull request. It does not run `behave` or `ruff`, so green CI is weaker than
section 4: run all of section 4 locally. The `deploy` job is manual (`workflow_dispatch`) and
fake: it deploys nothing.

| May do alone | Needs an approval first | Never |
|---|---|---|
| Read files, except secrets | Change a fee rule, rounding, limit or rule name | Edit `.github/workflows/` or `.env` (a hook blocks it; a human does it) |
| Edit `src/` and `tests/`, test first | Implement the night rule | Read or print `.env`, `*.pem`, `*.key`, `secrets/` |
| Run `pytest`, `behave`, `ruff check .`, `ruff format --check .` | Add a dependency, an endpoint, or a real network call | Run `curl`, `wget`, `ssh`, `scp`, `Invoke-WebRequest`, `Invoke-RestMethod` |
| Edit docs and this file, where facts are checked | Start any deployment, even the fake one | Touch `privacy-agent/requests/`, or reply to a requester |
| Commit when asked, naming any red scenario | Any destructive command: delete, `git reset --hard`, force-push, `ruff format .`, `ruff check --fix .` | Use a customer's real data |
| | Install tools or start the service (`pip install`, `playwright install`, `run-local.ps1`) | Skip hooks or deploy unapproved |
| | Two sources disagree, or a check fails for a reason Claude did not cause | |
