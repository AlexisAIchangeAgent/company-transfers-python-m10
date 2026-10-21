from decimal import Decimal

import pytest

from company_transfers.clients.exchange_rate import FixedRateClient
from company_transfers.domain import (
    Currency,
    CustomerSegment,
    FeeCalculator,
    FeeRequest,
    TransferType,
    UnsupportedTransferError,
)


def test_instant_mdl_fee_of_a_retail_customer_is_the_standard_fee_plus_10(
    calculator: FeeCalculator,
):
    request = FeeRequest(
        Decimal("2000.00"), Currency.MDL, TransferType.INSTANT, CustomerSegment.RETAIL
    )

    fee = calculator.calculate(request)

    assert fee.amount == Decimal("20.00")
    assert fee.currency is Currency.MDL


def test_instant_mdl_fee_of_a_premium_customer_is_the_standard_fee(calculator: FeeCalculator):
    request = FeeRequest(
        Decimal("2000.00"), Currency.MDL, TransferType.INSTANT, CustomerSegment.PREMIUM
    )

    fee = calculator.calculate(request)

    assert fee.amount == Decimal("10.00")
    assert fee.currency is Currency.MDL


@pytest.mark.parametrize(
    ("segment", "amount"),
    [
        (CustomerSegment.RETAIL, "100000.01"),
        (CustomerSegment.PREMIUM, "150000.00"),
    ],
)
def test_instant_mdl_transfer_above_100000_is_rejected(calculator: FeeCalculator, segment, amount):
    request = FeeRequest(Decimal(amount), Currency.MDL, TransferType.INSTANT, segment)

    with pytest.raises(UnsupportedTransferError, match="limit exceeded"):
        calculator.calculate(request)


def test_instant_eur_fee_converts_to_mdl_then_applies_the_mdl_rule():
    calculator = FeeCalculator(FixedRateClient(rate=Decimal("19.8765")))
    request = FeeRequest(
        Decimal("500.00"), Currency.EUR, TransferType.INSTANT, CustomerSegment.RETAIL
    )

    fee = calculator.calculate(request)

    assert fee.amount == Decimal("59.69")
    assert fee.currency is Currency.MDL


def test_instant_eur_transfer_above_the_mdl_limit_is_rejected():
    calculator = FeeCalculator(FixedRateClient(rate=Decimal("19.8765")))
    request = FeeRequest(
        Decimal("5100.00"), Currency.EUR, TransferType.INSTANT, CustomerSegment.RETAIL
    )

    # EUR 5100.00 at 19.8765 is MDL 101,370.15, above MDL 100,000.00
    with pytest.raises(UnsupportedTransferError, match="limit exceeded"):
        calculator.calculate(request)
