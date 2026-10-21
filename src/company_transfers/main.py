"""Application factory. Run with: uvicorn company_transfers.main:app"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from company_transfers.api.routes import router
from company_transfers.clients.exchange_rate import (
    ExchangeRateClient,
    ExchangeRateError,
    FixedRateClient,
    HttpExchangeRateClient,
)
from company_transfers.config import Settings
from company_transfers.domain import FeeCalculator, UnsupportedTransferError


def build_rate_client(settings: Settings) -> ExchangeRateClient:
    """HTTP client when RATES_BASE_URL is set, otherwise the fixed-rate stub."""
    if settings.rates_base_url:
        return HttpExchangeRateClient(
            settings.rates_base_url, settings.rates_api_key, settings.rates_timeout_seconds
        )
    return FixedRateClient()


def create_app(rate_client: ExchangeRateClient | None = None) -> FastAPI:
    app = FastAPI(title="Company Bank transfer fees", version="0.1.0")
    app.state.calculator = FeeCalculator(rate_client or build_rate_client(Settings.from_env()))
    app.include_router(router)

    @app.exception_handler(UnsupportedTransferError)
    def unsupported_transfer(_: Request, exc: UnsupportedTransferError) -> JSONResponse:
        return JSONResponse(status_code=422, content={"error": str(exc)})

    @app.exception_handler(ExchangeRateError)
    def rate_unavailable(_: Request, exc: ExchangeRateError) -> JSONResponse:
        return JSONResponse(status_code=502, content={"error": "exchange rate unavailable"})

    return app


app = create_app()
