# Architecture boundaries

Rules of the Company transfers service. Layers: `api -> domain -> clients`.

- Direction: `api -> domain -> clients`. Never the reverse. `main.py` wires all three.
- `api` maps HTTP bodies to domain objects and back. No fee rule here.
- `domain` holds every fee rule. No FastAPI, no HTTP, no urllib. It depends on the
  `ExchangeRateClient` protocol, never on a concrete client.
- `clients` talks to third parties only. Network code stays here.
- Configuration is read in `config.Settings` only; no `os.environ` anywhere else.
- Error to HTTP mapping lives in `main.py`; domain code raises exceptions, not responses.
