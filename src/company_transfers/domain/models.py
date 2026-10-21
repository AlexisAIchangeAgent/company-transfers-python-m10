"""Value objects of the fee domain."""

from dataclasses import dataclass
from decimal import Decimal
from enum import Enum


class _TextEnum(str, Enum):
    """A string enum that also runs on Python 3.10 (enum.StrEnum needs 3.11).

    str() and f-strings give the value, as with StrEnum.
    """

    def __str__(self) -> str:
        return str(self.value)

    def __format__(self, format_spec: str) -> str:
        return str(self.value).__format__(format_spec)


class Currency(_TextEnum):
    MDL = "MDL"
    EUR = "EUR"


class TransferType(_TextEnum):
    STANDARD = "standard"
    INSTANT = "instant"


class CustomerSegment(_TextEnum):
    RETAIL = "retail"
    PREMIUM = "premium"


@dataclass(frozen=True)
class FeeRequest:
    amount: Decimal
    currency: Currency
    type: TransferType
    customer_segment: CustomerSegment


@dataclass(frozen=True)
class Fee:
    amount: Decimal
    rule: str
    currency: Currency = Currency.MDL


class UnsupportedTransferError(Exception):
    """The transfer cannot be priced by the current rules."""
