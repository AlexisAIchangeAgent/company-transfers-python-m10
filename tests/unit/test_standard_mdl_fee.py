from decimal import Decimal

import pytest

from company_transfers.domain import (
    Currency,
    CustomerSegment,
    FeeCalculator,
    FeeRequest,
    TransferType,
)


def mdl_request(amount: str, segment: CustomerSegment = CustomerSegment.RETAIL) -> FeeRequest:
    return FeeRequest(Decimal(amount), Currency.MDL, TransferType.STANDARD, segment)


@pytest.mark.parametrize(
    ("amount", "expected_fee"),
    [
        ("2000.00", "10.00"),
        ("1234.00", "6.17"),
        ("9999.00", "50.00"),
    ],
)
def test_standard_mdl_fee_is_half_a_percent(calculator, amount, expected_fee):
    fee = calculator.calculate(mdl_request(amount))

    assert fee.amount == Decimal(expected_fee)
    assert fee.currency is Currency.MDL
    assert fee.rule == "standard-mdl"


@pytest.mark.parametrize("amount", ["0.01", "100.00", "999.99", "1000.00"])
def test_standard_mdl_fee_has_a_minimum_of_5(calculator: FeeCalculator, amount):
    assert calculator.calculate(mdl_request(amount)).amount == Decimal("5.00")


@pytest.mark.parametrize("amount", ["10000.00", "10000.01", "250000.00"])
def test_standard_mdl_fee_has_a_maximum_of_50(calculator: FeeCalculator, amount):
    assert calculator.calculate(mdl_request(amount)).amount == Decimal("50.00")


def test_standard_mdl_fee_rounds_half_up(calculator: FeeCalculator):
    # 0.5% of 1001.00 is 5.005
    assert calculator.calculate(mdl_request("1001.00")).amount == Decimal("5.01")


def test_standard_mdl_fee_has_two_decimals(calculator: FeeCalculator):
    assert calculator.calculate(mdl_request("2000.00")).amount.as_tuple().exponent == -2


def test_premium_standard_fee_is_the_retail_fee(calculator: FeeCalculator):
    retail = calculator.calculate(mdl_request("3000.00", CustomerSegment.RETAIL))
    premium = calculator.calculate(mdl_request("3000.00", CustomerSegment.PREMIUM))

    assert premium == retail


@pytest.mark.parametrize(
    ("amount", "expected_fee"),
    [
        ("0.00", "5.00"),  # the API refuses 0, the domain still applies the minimum
        ("0.01", "5.00"),
        ("999.99", "5.00"),
        ("1000.00", "5.00"),  # exactly the minimum
        ("1001.00", "5.01"),  # 5.005 rounds half up
        ("1003.00", "5.02"),  # 5.015 rounds half up
        ("9999.99", "50.00"),  # 49.99995 rounds to 50.00
        ("10000.00", "50.00"),  # exactly the maximum
        ("10000.01", "50.00"),
        ("1000000.00", "50.00"),
    ],
)
def test_standard_mdl_fee_bounds_and_half_up_rounding(calculator, amount, expected_fee):
    assert calculator.calculate(mdl_request(amount)).amount == Decimal(expected_fee)
