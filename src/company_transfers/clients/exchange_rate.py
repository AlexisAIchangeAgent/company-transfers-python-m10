"""Exchange-rate client: the third-party API that gives the EUR to MDL rate.

Contract of the provider:
    GET {base_url}/rates?from=EUR&to=MDL
    200 {"from": "EUR", "to": "MDL", "rate": 19.8765, "as_of": "2026-10-19"}
"""

import json
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Protocol
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


@dataclass(frozen=True)
class ExchangeRate:
    from_currency: str
    to_currency: str
    rate: Decimal
    as_of: date


class ExchangeRateError(Exception):
    """The exchange rate could not be obtained."""


class ExchangeRateClient(Protocol):
    def get_rate(self, from_currency: str, to_currency: str) -> ExchangeRate: ...


class HttpExchangeRateClient:
    """Calls the exchange-rate API over HTTP."""

    def __init__(
        self, base_url: str, api_key: str | None = None, timeout_seconds: float = 5.0
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._timeout_seconds = timeout_seconds

    def get_rate(self, from_currency: str, to_currency: str) -> ExchangeRate:
        query = urlencode({"from": from_currency, "to": to_currency})
        headers = {"Accept": "application/json"}
        if self._api_key:
            headers["X-Api-Key"] = self._api_key
        request = Request(f"{self._base_url}/rates?{query}", headers=headers)
        try:
            with urlopen(request, timeout=self._timeout_seconds) as response:
                payload = json.load(response, parse_float=Decimal)
            return ExchangeRate(
                from_currency=payload["from"],
                to_currency=payload["to"],
                rate=Decimal(str(payload["rate"])),
                as_of=date.fromisoformat(payload["as_of"]),
            )
        except (URLError, TimeoutError, ValueError, KeyError) as exc:
            raise ExchangeRateError(f"cannot get rate {from_currency}/{to_currency}") from exc


@dataclass(frozen=True)
class FixedRateClient:
    """Stub used in tests and local runs: always returns the same rate, no network."""

    rate: Decimal = Decimal("19.8765")
    as_of: date = date(2026, 10, 19)

    def get_rate(self, from_currency: str, to_currency: str) -> ExchangeRate:
        return ExchangeRate(from_currency, to_currency, self.rate, self.as_of)
