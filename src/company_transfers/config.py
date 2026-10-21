"""Service configuration, read from environment variables."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    rates_base_url: str | None = None
    rates_api_key: str | None = None
    rates_timeout_seconds: float = 5.0

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            rates_base_url=os.environ.get("RATES_BASE_URL") or None,
            rates_api_key=os.environ.get("RATES_API_KEY") or None,
            rates_timeout_seconds=float(os.environ.get("RATES_TIMEOUT_SECONDS", "5")),
        )
