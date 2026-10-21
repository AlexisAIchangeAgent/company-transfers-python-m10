from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal

import pytest

from company_transfers.clients.exchange_rate import ExchangeRate, FixedRateClient
from company_transfers.domain import (
    Currency,
    CustomerSegment,
    FeeCalculator,
    FeeRequest,
    TransferType,
    UnsupportedTransferError,
)


def eur_request(amount: str, segment: CustomerSegment = CustomerSegment.RETAIL) -> FeeRequest:
    return FeeRequest(Decimal(amount), Currency.EUR, TransferType.STANDARD, segment)


@dataclass
class RecordingRateClient:
    rate: Decimal
    calls: list[tuple[str, str]] = field(default_factory=list)

    def get_rate(self, from_currency: str, to_currency: str) -> ExchangeRate:
        self.calls.append((from_currency, to_currency))
        return ExchangeRate(from_currency, to_currency, self.rate, date(2026, 10, 19))


@pytest.mark.parametrize(
    ("amount_eur", "expected_fee"),
    [
        ("100.00", "10.00"),
        ("300.00", "30.00"),
        ("10.00", "5.00"),
        ("1000.00", "50.00"),
    ],
)
def test_standard_eur_fee_converts_to_mdl_then_applies_the_mdl_rule(
    calculator: FeeCalculator, amount_eur, expected_fee
):
    fee = calculator.calculate(eur_request(amount_eur))

    assert fee.amount == Decimal(expected_fee)
    assert fee.currency is Currency.MDL
    assert fee.rule == "standard-eur"


def test_standard_eur_fee_asks_the_eur_to_mdl_rate():
    rates = RecordingRateClient(rate=Decimal("20.0000"))

    FeeCalculator(rates).calculate(eur_request("100.00"))

    assert rates.calls == [("EUR", "MDL")]


def test_standard_eur_fee_with_the_published_rate():
    calculator = FeeCalculator(FixedRateClient())

    # EUR 100.00 at 19.8765 is MDL 1,987.65, and 0.5% of it is 9.93825
    assert calculator.calculate(eur_request("100.00")).amount == Decimal("9.94")


def test_mdl_transfer_does_not_ask_for_a_rate():
    rates = RecordingRateClient(rate=Decimal("20.0000"))

    FeeCalculator(rates).calculate(
        FeeRequest(Decimal("100.00"), Currency.MDL, TransferType.STANDARD, CustomerSegment.RETAIL)
    )

    assert rates.calls == []


def test_standard_eur_fee_matches_the_tariff_for_inc_2026_0412():
    # EUR 123.01 at 19.8765 is MDL 2,445.008265 (not rounded), and 0.5% of it is 12.2250413
    calculator = FeeCalculator(RecordingRateClient(Decimal("19.8765")))

    fee = calculator.calculate(eur_request("123.01"))

    assert fee.amount == Decimal("12.23")


def fee_at_rate(rate: str, amount_eur: str, type_: TransferType = TransferType.STANDARD) -> Decimal:
    request = FeeRequest(Decimal(amount_eur), Currency.EUR, type_, CustomerSegment.RETAIL)
    return FeeCalculator(RecordingRateClient(Decimal(rate))).calculate(request).amount


@pytest.mark.parametrize(
    ("rate", "amount_eur", "expected_fee"),
    [
        ("20.0000", "0.01", "5.00"),  # far below the minimum
        ("20.0000", "49.99", "5.00"),  # MDL 999.80, 4.999 is raised to the minimum
        ("20.0000", "50.00", "5.00"),  # MDL 1000.00, exactly the minimum
        ("20.0000", "50.05", "5.01"),  # MDL 1001.00, 5.005 rounds half up (half even gives 5.00)
        ("20.0500", "100.00", "10.03"),  # MDL 2005.00, 10.025 rounds half up (half even: 10.02)
        ("19.8765", "123.01", "12.23"),  # INC-2026-0412: the converted amount is not rounded
        ("19.8765", "100.00", "9.94"),  # 9.93825
        ("20.0000", "500.00", "50.00"),  # MDL 10000.00, exactly the maximum
        ("20.0000", "500.01", "50.00"),  # above the maximum
        ("20.0000", "100000.00", "50.00"),  # large amount
    ],
)
def test_standard_eur_fee_rounds_only_the_fee_half_up_within_the_bounds(
    rate, amount_eur, expected_fee
):
    assert fee_at_rate(rate, amount_eur) == Decimal(expected_fee)


def test_standard_eur_fee_does_not_depend_on_the_segment(calculator: FeeCalculator):
    retail = calculator.calculate(eur_request("123.01", CustomerSegment.RETAIL))
    premium = calculator.calculate(eur_request("123.01", CustomerSegment.PREMIUM))

    assert retail.amount == premium.amount


def test_instant_eur_fee_uses_the_same_unrounded_conversion():
    # standard part 12.23 (as INC-2026-0412) plus the MDL 10.00 retail flat fee
    assert fee_at_rate("19.8765", "123.01", TransferType.INSTANT) == Decimal("22.23")


@pytest.mark.parametrize(
    ("rate", "amount_eur", "accepted"),
    [
        ("20.0000", "5000.00", True),  # MDL 100000.00, exactly the limit
        ("20.0000008", "5000.00", True),  # MDL 100000.004: limit is checked on whole cents
        ("20.0000", "5000.01", False),  # MDL 100000.20
    ],
)
def test_instant_eur_limit_is_unchanged_by_the_unrounded_conversion(rate, amount_eur, accepted):
    if accepted:
        assert fee_at_rate(rate, amount_eur, TransferType.INSTANT) == Decimal("60.00")
    else:
        with pytest.raises(UnsupportedTransferError, match="limit exceeded"):
            fee_at_rate(rate, amount_eur, TransferType.INSTANT)
