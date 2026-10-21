"""HTTP routes of the fee service."""

from fastapi import APIRouter, Request

from company_transfers.api.schemas import (
    DecimalJSONResponse,
    ErrorBody,
    FeeRequestBody,
    FeeResponseBody,
)
from company_transfers.domain import (
    Currency,
    CustomerSegment,
    FeeCalculator,
    FeeRequest,
    TransferType,
)

router = APIRouter()


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.post(
    "/fees",
    response_model=FeeResponseBody,
    responses={422: {"model": ErrorBody}, 502: {"model": ErrorBody}},
)
def compute_fee(body: FeeRequestBody, request: Request) -> DecimalJSONResponse:
    calculator: FeeCalculator = request.app.state.calculator
    fee = calculator.calculate(
        FeeRequest(
            amount=body.amount,
            currency=Currency(body.currency),
            type=TransferType(body.type),
            customer_segment=CustomerSegment(body.customer_segment),
        )
    )
    response = FeeResponseBody(fee=fee.amount, currency=fee.currency, rule=fee.rule)
    return DecimalJSONResponse(response.model_dump())
