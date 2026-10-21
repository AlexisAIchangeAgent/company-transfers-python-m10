"""behave hooks. Each scenario gets a fresh in-process client of the fee service.

Step definitions go in features/steps/. The fixed-rate stub is used: no network call.
"""

from fastapi.testclient import TestClient

from company_transfers.clients.exchange_rate import FixedRateClient
from company_transfers.main import create_app


def before_scenario(context, scenario):
    context.rate_client = FixedRateClient()
    context.client = TestClient(create_app(rate_client=context.rate_client))


def after_scenario(context, scenario):
    context.client.close()
