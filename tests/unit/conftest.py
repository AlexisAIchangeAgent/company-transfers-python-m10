from collections.abc import Iterator
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from company_transfers.clients.exchange_rate import FixedRateClient
from company_transfers.domain import FeeCalculator
from company_transfers.main import create_app

TEST_RATE = Decimal("20.0000")


@pytest.fixture
def calculator() -> FeeCalculator:
    return FeeCalculator(FixedRateClient(rate=TEST_RATE))


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(create_app(rate_client=FixedRateClient(rate=TEST_RATE))) as test_client:
        yield test_client
