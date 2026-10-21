"""Consumer contract of company-transfers with the exchange-rate API (Pact).

The real HttpExchangeRateClient talks to a Pact mock server on localhost, so no third-party
network is used. Running this file writes tests/contract/pacts/<consumer>-<provider>.json,
which the provider team verifies. Run it with: python -m pytest tests/contract
"""

from collections.abc import Iterator
from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest
from pact import Pact, match

from company_transfers.clients.exchange_rate import ExchangeRateError, HttpExchangeRateClient

PACT_DIR = Path(__file__).parent / "pacts"
API_KEY = "test-key"


@pytest.fixture(scope="module", autouse=True)
def fresh_pact_file() -> None:
    """Start from an empty pact file: write_file merges into an existing one."""
    for old in PACT_DIR.glob("company-transfers-exchange-rate-api.json"):
        old.unlink()


@pytest.fixture
def pact() -> Iterator[Pact]:
    pact = Pact("company-transfers", "exchange-rate-api").with_specification("V3")
    yield pact
    pact.write_file(PACT_DIR)  # merged with the interactions of the other tests


def rates_request(interaction):
    return (
        interaction.with_request("GET", "/rates")
        .with_query_parameter("from", "EUR")
        .with_query_parameter("to", "MDL")
        .with_header("Accept", "application/json")
        .with_header("X-Api-Key", API_KEY)
    )


def test_get_rate_returns_the_eur_to_mdl_rate(pact: Pact):
    (
        rates_request(
            pact.upon_receiving("a request for the EUR to MDL rate").given("EUR to MDL has a rate")
        )
        .will_respond_with(200)
        .with_header("Content-Type", "application/json")
        .with_body(
            {
                "from": "EUR",
                "to": "MDL",
                "rate": match.decimal(19.8765),
                "as_of": match.date("2026-10-19", "%Y-%m-%d"),
            }
        )
    )

    with pact.serve() as server:
        client = HttpExchangeRateClient(str(server.url), api_key=API_KEY)
        rate = client.get_rate("EUR", "MDL")

    assert (rate.from_currency, rate.to_currency) == ("EUR", "MDL")
    assert rate.rate == Decimal("19.8765")
    assert rate.as_of == date(2026, 10, 19)


def test_get_rate_raises_exchange_rate_error_when_the_provider_is_unavailable(pact: Pact):
    (
        rates_request(
            pact.upon_receiving("a request for the rate while the service is down").given(
                "the rate service is unavailable"
            )
        ).will_respond_with(503)
    )

    with pact.serve() as server:
        client = HttpExchangeRateClient(str(server.url), api_key=API_KEY)
        with pytest.raises(ExchangeRateError, match="cannot get rate EUR/MDL"):
            client.get_rate("EUR", "MDL")
