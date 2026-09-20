from __future__ import annotations

import time

from dotenv import load_dotenv

from app.api_client import ApiClient
from app.config import load_settings
from app.logger import logger
from app.providers.mock import MockMt5Provider
from app.sync_service import SyncService


def build_provider(settings):
    if settings.provider == "real":
        from app.providers.real import RealMt5Provider

        return RealMt5Provider(settings)
    return MockMt5Provider(settings.mt5_login, settings.mt5_server)


def main() -> None:
    load_dotenv()
    settings = load_settings()
    logger.info("Starting MT5 worker provider=%s api=%s", settings.provider, settings.api_base_url)
    provider = build_provider(settings)
    service = SyncService(settings, provider, ApiClient(settings))
    while True:
        try:
            service.run_once()
        except Exception:
            logger.exception("Sync loop failed")
        time.sleep(settings.poll_seconds)


if __name__ == "__main__":
    main()
