# Conventions (Python)

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
