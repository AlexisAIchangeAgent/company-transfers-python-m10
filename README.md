# company-transfers-python

Training material. Invented bank. Company Bank SA, its customers and its figures are invented.

Transfer-fee service of Company Bank: `POST /fees` returns the fee of a transfer in MDL,
`GET /health` returns `{"status": "ok"}`. Python 3.10+, FastAPI.

## Getting started

Windows 11: use PowerShell. macOS: use Terminal. Run every command from the repository folder.

```
git clone https://github.com/AlexisAIchangeAgent/company-transfers-python.git
cd company-transfers-python
```

Or download the ZIP of the latest release on GitHub (Releases, then Source code (zip)), unzip it,
and open a terminal in the folder. Step 3 then creates the git repository: the training commits
in it.

| Step | Windows | macOS |
|---|---|---|
| 1. Check the tools (changes nothing) | `powershell -ExecutionPolicy Bypass -File .\step-1-check.ps1` | `bash step-1-check.sh` |
| 2. Only if a line says KO: install the missing tools, open a new terminal, run step 1 again | `powershell -ExecutionPolicy Bypass -File .\step-2-install-tools.ps1` | `bash step-2-install-tools.sh` |
| 3. Install the dependencies of the project (network, a few minutes) | `powershell -ExecutionPolicy Bypass -File .\step-3-setup.ps1` | `bash step-3-setup.sh` |
| 4. Start Claude Code | `claude` | `claude` |

Or double-click the file of each step in the folder: `step-1-check.cmd`, `step-2-install-tools.cmd`,
`step-3-setup.cmd` on Windows; `step-1-check.command`, `step-2-install-tools.command`,
`step-3-setup.command` on macOS. The window stays open at the end: read the result, then press a
key. The first time, Windows may show "Windows protected your PC": choose More info, then Run
anyway. macOS may refuse a file downloaded in a ZIP: right-click it, choose Open, then Open.

Step 3 ends with "Ready for cycle 1". If your IT team installs the tools for you, give them
`INSTALL-TOOLS.md`.

## Before the training

Run these once, with network access. During the training, Claude Code works without network.

`step-3-setup.ps1` (Windows) and `step-3-setup.sh` (macOS) run these steps for you, then the unit tests: see
Getting started above. The commands below do the same by hand.

```
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m playwright install chromium
```

On Windows (PowerShell or cmd), use `.venv\Scripts\python` instead of `.venv/bin/python`, here
and in every command below.

The dev install also brings the Claude Agent SDK used in `privacy-agent/`.

## Build

```
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
```

On Windows:

```
py -3 -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
```

`py -3` uses the newest Python installed; `py -3.10` or `py -3.12` picks another one, and
`python -m venv .venv` works too. With `make` (macOS, Linux): `make install`. `make` is not
installed on Windows: run the commands.

## Run

macOS and Linux:

```
.venv/bin/python -m uvicorn company_transfers.main:app --reload --port 8000
curl -X POST localhost:8000/fees -H "Content-Type: application/json" \
  -d '{"amount": 2000.00, "currency": "MDL", "type": "standard", "customer_segment": "retail"}'
```

Windows, PowerShell (in Windows PowerShell 5.1 `curl` is an alias of `Invoke-WebRequest`, so the
`curl` line above does not work). Start the service, then call it from a second terminal:

```
.venv\Scripts\python -m uvicorn company_transfers.main:app --reload --port 8000
Invoke-RestMethod -Method Post -Uri http://localhost:8000/fees -ContentType "application/json" -Body '{"amount": 2000.00, "currency": "MDL", "type": "standard", "customer_segment": "retail"}'
```

Windows, cmd (`curl.exe` ships with Windows 10 and 11; inner quotes are escaped):

```
curl -X POST localhost:8000/fees -H "Content-Type: application/json" -d "{\"amount\": 2000.00, \"currency\": \"MDL\", \"type\": \"standard\", \"customer_segment\": \"retail\"}"
```

Without `RATES_BASE_URL` in the environment, the service uses a fixed EUR to MDL rate
(19.8765) and makes no network call.

## Test

```
.venv/bin/python -m pytest                   # unit tests (tests/unit)
.venv/bin/python -m behave                   # BDD features (features/)
.venv/bin/python -m ruff check .             # lint
.venv/bin/python -m ruff format --check .    # format check
```

On Windows, `.venv\Scripts\python -m behave` passes 8 of the 9 scenarios of `instant-fee.feature`.
"Instant transfer at night" is counted as `error` (its step `it is night` raises
`NotImplementedError`), so behave exits with code 1.

Playwright browser, needed for the Playwright tests of the training:

```
.venv/bin/python -m playwright install chromium
```

`make test`, `make bdd`, `make lint` and `make playwright-install` do the same on macOS and
Linux. `make` is not installed on Windows: run the commands above.

## Architecture

Three layers, one sub-package each in `src/company_transfers/`. The dependency goes one way:
`api -> domain -> clients`, never the other way (see `CLAUDE.md`).

| Layer | Module | Role |
|---|---|---|
| app | `main.py` | `create_app()` builds the FastAPI app; `app` is the module-level instance for uvicorn. It chooses the rate client and maps errors to HTTP. |
| app | `config.py` | `Settings.from_env()`: `RATES_BASE_URL`, `RATES_API_KEY`, `RATES_TIMEOUT_SECONDS` (default 5). |
| `api` | `routes.py` | `GET /health` and `POST /fees`. |
| `api` | `schemas.py` | Request and response bodies. `DecimalJSONResponse` writes the fee as a JSON number, without float. |
| `domain` | `models.py` | Enums `Currency`, `TransferType`, `CustomerSegment`, frozen dataclasses `FeeRequest` and `Fee`, `UnsupportedTransferError`. |
| `domain` | `fees.py` | `FeeCalculator`: the fee rules. No HTTP. It depends on the `ExchangeRateClient` protocol only. |
| `clients` | `exchange_rate.py` | `HttpExchangeRateClient` (third-party API, `GET {base}/rates?from=EUR&to=MDL`) and `FixedRateClient` (stub, no network). |

`main.py` uses `HttpExchangeRateClient` when `RATES_BASE_URL` is set, otherwise `FixedRateClient`.
Errors become HTTP answers in `main.py`:

| Error | Response |
|---|---|
| `UnsupportedTransferError` | 422 `{"error": "..."}` |
| `ExchangeRateError` | 502 `{"error": "exchange rate unavailable"}` |
| invalid body | 422 from FastAPI validation (`amount` > 0 with at most 2 decimals; `currency`, `type`, `customer_segment` from fixed lists) |

Money is always `decimal.Decimal`, never `float`. Fees are in MDL.

## What the service computes today

The published tariff is `docs/fee-rules.md`. `domain/fees.py` implements:

- Standard transfer in MDL: 0.5% of the amount, rounded half up to 2 decimals, minimum MDL 5.00,
  maximum MDL 50.00. Rule name in the response: `standard-mdl`.
- Standard transfer in EUR: converted to MDL with the EUR to MDL rate, then the same minimum and
  maximum. Rule name: `standard-eur`.
- The customer segment does not change the standard fee.
- Instant transfer: a retail customer pays the standard fee plus a flat MDL 10.00, a premium
  customer pays the standard fee only. An EUR amount is converted to MDL first. An amount above
  MDL 100,000.00 (converted amount for EUR) is rejected with 422 `{"error": "limit exceeded"}`.
  Rule names: `instant-mdl`, `instant-eur`. The acceptance criteria are in
  `features/instant-fee.feature`; the instant fee is not published in `docs/fee-rules.md`.
  Instant transfer at night is not built.

Known differences, not fixed here:

- EUR rounding. `docs/fee-rules.md` says the converted amount is not rounded and the fee is rounded
  half up. `domain/fees.py` rounds the converted amount down to 2 decimals, then the fee half to
  even. `incidents/INC-2026-0412.md` is a customer dispute about an EUR fee.
- `docs/README-service.md` is out of date (last reviewed March 2025). It lists `GET /fees/{id}`,
  which does not exist in `api/routes.py`, a maximum fee of MDL 40.00 and bankers rounding.
  Use `docs/fee-rules.md` and the code.

## Dependencies

Declared in `pyproject.toml`. Python 3.10 or newer; the pipeline in `docs/pipeline/ci.yml` uses 3.11.

| Kind | Packages |
|---|---|
| Runtime | `fastapi`, `uvicorn`, `simplejson` (pydantic comes with FastAPI) |
| Dev (extra `dev`) | `pytest`, `httpx2` (FastAPI `TestClient`), `behave`, `ruff` |
| Dev, installed but not used yet | `pact-python`, `pytest-playwright`, `claude-agent-sdk` (for `privacy-agent/`) |
| External service | the exchange-rate API, set by `RATES_BASE_URL` (optional `RATES_API_KEY`) |

`requirements-dev.txt` installs the package in editable mode with the `dev` extra (`-e .[dev]`).
The `.env` file holds fake values and is not loaded automatically: export the variables yourself
to call a real exchange-rate API.

## Not in the repository

- Pact tests, Playwright tests, and the
  code of the privacy agent.
- An active CI pipeline: `docs/pipeline/ci.yml` is not in `.github/workflows/` yet.
- Architecture decision records (`docs/adr/` is empty), a Dockerfile, and any authentication on the API.

## Folder map

| Folder | Content |
|---|---|
| `src/company_transfers/` | the service: `api/`, `domain/`, `clients/` |
| `tests/unit/` | pytest unit tests |
| `features/` | behave features, `steps/`, `environment.py` |
| `crm/` | static page of the internal CRM |
| `incidents/` | incident tickets |
| `docs/` | service documentation, published tariff, `adr/` |
| `privacy-agent/` | GDPR intake policy and synthetic requests |
| `docs/pipeline/` | CI pipeline, not active yet: cycle 3 copies it to `.github/workflows/` |

See `CLAUDE.md` for the conventions.
