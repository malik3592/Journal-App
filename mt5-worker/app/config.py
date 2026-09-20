from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    api_base_url: str
    mt5_api_token: str
    provider: str
    poll_seconds: int
    mt5_login: str
    mt5_server: str
    mt5_password: str
    mt5_path: str


def load_settings() -> Settings:
    return Settings(
        api_base_url=os.getenv("API_BASE_URL", "http://localhost:3000").rstrip("/"),
        mt5_api_token=os.getenv("MT5_API_TOKEN", "dev-mt5-service-token"),
        provider=os.getenv("MT5_PROVIDER", "mock").lower(),
        poll_seconds=int(os.getenv("POLL_SECONDS", "30")),
        mt5_login=os.getenv("MT5_LOGIN", "12345678"),
        mt5_server=os.getenv("MT5_SERVER", "ICMarketsSC-Demo"),
        mt5_password=os.getenv("MT5_PASSWORD", ""),
        mt5_path=os.getenv("MT5_PATH", ""),
    )
