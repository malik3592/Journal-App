from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.models import AccountSnapshot, RawDeal, RawOrder, RawPosition


def _dt(value: str) -> datetime:
    return datetime.fromisoformat(value).replace(tzinfo=timezone.utc)


# Design-matching closed trades around 18 Sep 2026.
MOCK_TRADES = [
    {
        "position_id": 14473981,
        "symbol": "XAUUSD",
        "direction": "BUY",
        "volume": 0.10,
        "entry": 3648.20,
        "exit": 3660.25,
        "sl": 3642.00,
        "tp": 3669.00,
        "profit": 120.50,
        "commission": -7.00,
        "swap": -1.20,
        "open": "2026-09-18T09:14:00",
        "close": "2026-09-18T10:19:00",
    },
    {
        "position_id": 14474002,
        "symbol": "EURUSD",
        "direction": "SELL",
        "volume": 0.20,
        "entry": 1.10840,
        "exit": 1.11065,
        "sl": 1.11120,
        "tp": 1.10500,
        "profit": -45.30,
        "commission": -2.40,
        "swap": 0.00,
        "open": "2026-09-18T07:10:00",
        "close": "2026-09-18T08:42:00",
    },
    {
        "position_id": 14471011,
        "symbol": "XAUUSD",
        "direction": "BUY",
        "volume": 0.10,
        "entry": 3631.40,
        "exit": 3640.10,
        "sl": 3624.00,
        "tp": 3652.00,
        "profit": 87.20,
        "commission": -7.00,
        "swap": 0.00,
        "open": "2026-09-17T15:02:00",
        "close": "2026-09-17T16:16:00",
    },
    {
        "position_id": 14470980,
        "symbol": "EURUSD",
        "direction": "BUY",
        "volume": 0.10,
        "entry": 1.10410,
        "exit": 1.11040,
        "sl": 1.10100,
        "tp": 1.11200,
        "profit": 62.70,
        "commission": -1.40,
        "swap": 0.00,
        "open": "2026-09-17T10:05:00",
        "close": "2026-09-17T11:32:00",
    },
    {
        "position_id": 14470044,
        "symbol": "XAUUSD",
        "direction": "SELL",
        "volume": 0.10,
        "entry": 3628.90,
        "exit": 3632.80,
        "sl": 3636.00,
        "tp": 3615.00,
        "profit": -38.75,
        "commission": -7.00,
        "swap": 0.00,
        "open": "2026-09-17T05:40:00",
        "close": "2026-09-17T06:20:00",
    },
    {
        "position_id": 14468821,
        "symbol": "XAUUSD",
        "direction": "BUY",
        "volume": 0.10,
        "entry": 3618.50,
        "exit": 3629.05,
        "sl": 3610.00,
        "tp": 3640.00,
        "profit": 105.40,
        "commission": -7.00,
        "swap": 0.00,
        "open": "2026-09-16T12:02:00",
        "close": "2026-09-16T13:14:00",
    },
]


class MockMt5Provider:
    def __init__(self, login: str, server: str) -> None:
        self.login = login
        self.server = server

    def get_account(self) -> AccountSnapshot:
        return AccountSnapshot(
            login=self.login,
            server=self.server,
            name="MT5 Account 1",
            broker="IC Markets",
            currency="USD",
            account_type="demo",
            leverage=500,
            balance="11980.42",
            equity="12432.18",
        )

    def get_open_positions(self) -> list[RawPosition]:
        return []

    def get_orders(self, start: datetime, end: datetime) -> list[RawOrder]:
        orders: list[RawOrder] = []
        for trade in MOCK_TRADES:
            opened = _dt(trade["open"])
            if start - timedelta(hours=1) <= opened <= end:
                orders.append(
                    RawOrder(
                        ticket=int(trade["position_id"]),
                        position_id=int(trade["position_id"]),
                        symbol=str(trade["symbol"]),
                        type="BUY" if trade["direction"] == "BUY" else "SELL",
                        volume=float(trade["volume"]),
                        price=float(trade["entry"]),
                        sl=float(trade["sl"]) if trade["sl"] else None,
                        tp=float(trade["tp"]) if trade["tp"] else None,
                        state="filled",
                        time_setup=opened,
                        raw={"source": "mock"},
                    )
                )
        return orders

    def get_deals(self, start: datetime, end: datetime) -> list[RawDeal]:
        deals: list[RawDeal] = []
        for trade in MOCK_TRADES:
            opened = _dt(trade["open"])
            closed = _dt(trade["close"])
            if not (start - timedelta(hours=1) <= closed <= end or start <= opened <= end):
                continue
            entry_type = "BUY" if trade["direction"] == "BUY" else "SELL"
            exit_type = "SELL" if trade["direction"] == "BUY" else "BUY"
            deals.append(
                RawDeal(
                    ticket=int(trade["position_id"]) * 10,
                    order=int(trade["position_id"]),
                    position_id=int(trade["position_id"]),
                    symbol=str(trade["symbol"]),
                    type=entry_type,
                    entry="in",
                    volume=float(trade["volume"]),
                    price=float(trade["entry"]),
                    profit=0.0,
                    commission=float(trade["commission"]) / 2,
                    swap=0.0,
                    fee=0.0,
                    magic=0,
                    comment="mock",
                    time=opened,
                    raw={"source": "mock", "side": "in"},
                )
            )
            deals.append(
                RawDeal(
                    ticket=int(trade["position_id"]) * 10 + 1,
                    order=int(trade["position_id"]),
                    position_id=int(trade["position_id"]),
                    symbol=str(trade["symbol"]),
                    type=exit_type,
                    entry="out",
                    volume=float(trade["volume"]),
                    price=float(trade["exit"]),
                    profit=float(trade["profit"]),
                    commission=float(trade["commission"]) / 2,
                    swap=float(trade["swap"]),
                    fee=0.0,
                    magic=0,
                    comment="mock",
                    time=closed,
                    raw={"source": "mock", "side": "out"},
                )
            )
        return deals
