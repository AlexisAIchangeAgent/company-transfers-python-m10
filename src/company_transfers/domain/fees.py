"""Fee calculation. The published tariff is in docs/fee-rules.md."""

from decimal import ROUND_DOWN, ROUND_HALF_UP, Decimal

from company_transfers.clients.exchange_rate import ExchangeRateClient
from company_transfers.domain.models import (
    Currency,
    CustomerSegment,
    Fee,
    FeeRequest,
    TransferType,
    UnsupportedTransferError,
)

CENT = Decimal("0.01")
ZERO = Decimal("0.00")
STANDARD_RATE = Decimal("0.005")
STANDARD_MIN_FEE = Decimal("5.00")
STANDARD_MAX_FEE = Decimal("50.00")
INSTANT_FLAT_FEE = Decimal("10.00")
INSTANT_MAX_AMOUNT_MDL = Decimal("100000.00")


def _clamp(fee: Decimal) -> Decimal:
    return min(max(fee, STANDARD_MIN_FEE), STANDARD_MAX_FEE)


def _rule_name(transfer_type: str, currency: Currency) -> str:
    return f"{transfer_type}-{currency.value.lower()}"


def standard_fee_mdl(amount_mdl: Decimal) -> Decimal:
    """Standard fee of an MDL amount: 0.5%, minimum MDL 5.00, maximum MDL 50.00.

    The amount is not rounded, only the fee is (half up), as the published tariff says.
    """
    fee = (amount_mdl * STANDARD_RATE).quantize(CENT, rounding=ROUND_HALF_UP)
    return _clamp(fee)


class FeeCalculator:
    def __init__(self, rates: ExchangeRateClient) -> None:
        self._rates = rates

    def calculate(self, request: FeeRequest) -> Fee:
        amount_mdl, standard_fee = self._standard_fee(request)
        if request.type is TransferType.INSTANT:
            return self._instant_fee(request, amount_mdl, standard_fee)
        return Fee(amount=standard_fee, rule=_rule_name("standard", request.currency))

    def _standard_fee(self, request: FeeRequest) -> tuple[Decimal, Decimal]:
        """Amount in MDL and standard fee of the request."""
        if request.currency is Currency.MDL:
            return request.amount, standard_fee_mdl(request.amount)
        amount_mdl = self._to_mdl(request.amount)
        return amount_mdl, standard_fee_mdl(amount_mdl)

    def _instant_fee(self, request: FeeRequest, amount_mdl: Decimal, standard_fee: Decimal) -> Fee:
        if amount_mdl.quantize(CENT, rounding=ROUND_DOWN) > INSTANT_MAX_AMOUNT_MDL:
            raise UnsupportedTransferError("limit exceeded")
        flat_fee = INSTANT_FLAT_FEE if request.customer_segment is CustomerSegment.RETAIL else ZERO
        return Fee(amount=standard_fee + flat_fee, rule=_rule_name("instant", request.currency))

    def _to_mdl(self, amount_eur: Decimal) -> Decimal:
        rate = self._rates.get_rate(Currency.EUR, Currency.MDL).rate
        return amount_eur * rate
