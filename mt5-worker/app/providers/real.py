from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.config import Settings
from app.models import AccountSnapshot, RawDeal, RawOrder, RawPosition


class RealMt5Provider:
    """Windows-only adapter around the official MetaTrader5 package.

    Read-only: account, positions, orders, and deals. No trade execution.
    """

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._mt5 = None

    def _client(self):
        if self._mt5 is None:
            import MetaTrader5 as mt5  # type: ignore

            kwargs: dict[str, Any] = {}
            if self.settings.mt5_path:
                kwargs["path"] = self.settings.mt5_path
            if not mt5.initialize(**kwargs):
                raise RuntimeError(f"MT5 initialize failed: {mt5.last_error()}")
            if self.settings.mt5_login and self.settings.mt5_password:
                logged_in = mt5.login(
                    int(self.settings.mt5_login),
                    password=self.settings.mt5_password,
                    server=self.settings.mt5_server,
                )
                if not logged_in:
                    raise RuntimeError(f"MT5 login failed: {mt5.last_error()}")
            self._mt5 = mt5
        return self._mt5

    def get_account(self) -> AccountSnapshot | None:
        mt5 = self._client()
        info = mt5.account_info()
        if info is None:
            return None
        return AccountSnapshot(
            login=str(info.login),
            server=str(info.server),
            name=str(getattr(info, "name", "MT5 Account")),
            broker=str(getattr(info, "company", "Broker")),
            currency=str(info.currency),
            account_type="demo" if getattr(info, "trade_mode", 0) == 0 else "live",
            leverage=int(info.leverage),
            balance=f"{info.balance:.2f}",
            equity=f"{info.equity:.2f}",
        )

    def get_open_positions(self) -> list[RawPosition]:
        mt5 = self._client()
        rows = mt5.positions_get() or []
        return [
            RawPosition(
                ticket=int(row.ticket),
                symbol=str(row.symbol),
                type="BUY" if int(row.type) == 0 else "SELL",
                volume=float(row.volume),
                price_open=float(row.price_open),
                sl=float(row.sl) or None,
                tp=float(row.tp) or None,
                time=_from_mt5_time(row.time),
            )
            for row in rows
        ]

    def get_orders(self, start: datetime, end: datetime) -> list[RawOrder]:
        mt5 = self._client()
        rows = mt5.history_orders_get(start, end) or []
        result: list[RawOrder] = []
        for row in rows:
            result.append(
                RawOrder(
                    ticket=int(row.ticket),
                    position_id=int(getattr(row, "position_id", 0) or 0),
                    symbol=str(row.symbol),
                    type=str(row.type),
                    volume=float(row.volume_initial),
                    price=float(row.price_open),
                    sl=float(row.sl) or None,
                    tp=float(row.tp) or None,
                    state=str(row.state),
                    time_setup=_from_mt5_time(row.time_setup),
                    raw=_as_dict(row),
                )
            )
        return result

    def get_deals(self, start: datetime, end: datetime) -> list[RawDeal]:
        mt5 = self._client()
        rows = mt5.history_deals_get(start, end) or []
        result: list[RawDeal] = []
        for row in rows:
            result.append(
                RawDeal(
                    ticket=int(row.ticket),
                    order=int(row.order),
                    position_id=int(row.position_id),
                    symbol=str(row.symbol),
                    type=str(row.type),
                    entry=str(row.entry),
                    volume=float(row.volume),
                    price=float(row.price),
                    profit=float(row.profit),
                    commission=float(row.commission),
                    swap=float(row.swap),
                    fee=float(getattr(row, "fee", 0) or 0),
                    magic=int(row.magic),
                    comment=str(row.comment),
                    time=_from_mt5_time(row.time),
                    raw=_as_dict(row),
                )
            )
        return result


def _from_mt5_time(value: int) -> datetime:
    return datetime.fromtimestamp(int(value), tz=timezone.utc)


def _as_dict(row: Any) -> dict[str, Any]:
    if hasattr(row, "_asdict"):
        return dict(row._asdict())
    return {"ticket": getattr(row, "ticket", None)}
