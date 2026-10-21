"""Request and response bodies of the HTTP API."""

from decimal import Decimal
from typing import Literal

import simplejson
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field


class FeeRequestBody(BaseModel):
    amount: Decimal = Field(gt=0, decimal_places=2)
    currency: Literal["MDL", "EUR"]
    type: Literal["standard", "instant"]
    customer_segment: Literal["retail", "premium"]


class FeeResponseBody(BaseModel):
    fee: Decimal
    currency: Literal["MDL"] = "MDL"
    rule: str


class ErrorBody(BaseModel):
    error: str


class DecimalJSONResponse(JSONResponse):
    """Writes Decimal values as JSON numbers, without converting them to float."""

    def render(self, content: object) -> bytes:
        return simplejson.dumps(content, use_decimal=True).encode("utf-8")
