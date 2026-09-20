from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.api_client import ApiClient
from app.config import Settings
from app.logger import logger
from app.models import TradingDataProvider
from app.normalizer import normalize_trades


class SyncService:
    def __init__(self, settings: Settings, provider: TradingDataProvider, api: ApiClient) -> None:
        self.settings = settings
        self.provider = provider
        self.api = api
        self._last_sync: datetime | None = None

    def run_once(self) -> dict | None:
        account = self.provider.get_account()
        if account is None:
            logger.warning("No MT5 account information available")
            return None
        end = datetime.now(timezone.utc)
        start = (self._last_sync or end - timedelta(days=365)) - timedelta(minutes=5)
        orders = self.provider.get_orders(start, end)
        deals = self.provider.get_deals(start, end)
        positions = self.provider.get_open_positions()
        trades = normalize_trades(deals, positions)
        result = self.api.post_sync(account, orders, deals, trades)
        if result and result.get("updated"):
            self._last_sync = end
        logger.info(
            "Synced login=%s orders=%s deals=%s trades=%s result=%s",
            account.login,
            len(orders),
            len(deals),
            len(trades),
            result,
        )
        return result
