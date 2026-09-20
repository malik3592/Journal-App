from __future__ import annotations

from datetime import datetime

import requests

from app.config import Settings
from app.logger import logger
from app.models import AccountSnapshot, RawDeal, RawOrder


class ApiClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def post_sync(
        self,
        account: AccountSnapshot,
        orders: list[RawOrder],
        deals: list[RawDeal],
        trades: list[dict],
    ) -> dict:
        payload = {
            "mt5Login": account.login,
            "mt5Server": account.server,
            "brokerName": account.broker,
            "account": {
                "name": account.name,
                "currency": account.currency,
                "accountType": account.account_type,
                "leverage": account.leverage,
                "balance": account.balance,
                "equity": account.equity,
            },
            "orders": [
                {
                    "ticket": o.ticket,
                    "position_id": o.position_id,
                    "symbol": o.symbol,
                    "type": o.type,
                    "volume": o.volume,
                    "price": o.price,
                    "sl": o.sl,
                    "tp": o.tp,
                    "state": o.state,
                    "time_setup": o.time_setup.isoformat(),
                    "raw": o.raw,
                }
                for o in orders
            ],
            "deals": [
                {
                    "ticket": d.ticket,
                    "order": d.order,
                    "position_id": d.position_id,
                    "symbol": d.symbol,
                    "type": d.type,
                    "entry": d.entry,
                    "volume": d.volume,
                    "price": d.price,
                    "profit": d.profit,
                    "commission": d.commission,
                    "swap": d.swap,
                    "fee": d.fee,
                    "magic": d.magic,
                    "comment": d.comment,
                    "time": d.time.isoformat(),
                    "raw": d.raw,
                }
                for d in deals
            ],
            "trades": trades,
        }
        response = requests.post(
            f"{self.settings.api_base_url}/internal/mt5/sync",
            json=payload,
            headers={"x-mt5-token": self.settings.mt5_api_token},
            timeout=30,
        )
        if response.status_code >= 400:
            logger.error("Sync failed %s %s", response.status_code, response.text)
            response.raise_for_status()
        return response.json()
