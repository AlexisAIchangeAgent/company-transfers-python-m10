from decimal import Decimal

from company_transfers.clients.exchange_rate import FixedRateClient, HttpExchangeRateClient
from company_transfers.config import Settings
from company_transfers.main import build_rate_client


def test_settings_are_read_from_the_environment(monkeypatch):
    monkeypatch.setenv("RATES_BASE_URL", "https://rates.example.invalid")
    monkeypatch.setenv("RATES_API_KEY", "fake-key-do-not-use")
    monkeypatch.setenv("RATES_TIMEOUT_SECONDS", "2")

    settings = Settings.from_env()

    assert settings.rates_base_url == "https://rates.example.invalid"
    assert settings.rates_api_key == "fake-key-do-not-use"
    assert settings.rates_timeout_seconds == 2.0


def test_http_rate_client_is_used_when_a_base_url_is_set():
    client = build_rate_client(Settings(rates_base_url="https://rates.example.invalid"))

    assert isinstance(client, HttpExchangeRateClient)


def test_fixed_rate_client_is_used_without_a_base_url():
    client = build_rate_client(Settings(rates_base_url=None))

    assert isinstance(client, FixedRateClient)


def test_fixed_rate_client_returns_the_published_rate():
    rate = FixedRateClient().get_rate("EUR", "MDL")

    assert (rate.from_currency, rate.to_currency, rate.rate) == ("EUR", "MDL", Decimal("19.8765"))
