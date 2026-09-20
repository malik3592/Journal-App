from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Protocol


@dataclass
class AccountSnapshot:
    login: str
    server: str
    name: str
    broker: str
    currency: str
    account_type: str
    leverage: int
    balance: str
    equity: str


@dataclass
class RawOrder:
    ticket: int
    position_id: int
    symbol: str
    type: str
    volume: float
    price: float
    sl: float | None
    tp: float | None
    state: str
    time_setup: datetime
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass
class RawDeal:
    ticket: int
    order: int
    position_id: int
    symbol: str
    type: str
    entry: str
    volume: float
    price: float
    profit: float
    commission: float
    swap: float
    fee: float
    magic: int
    comment: str
    time: datetime
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass
class RawPosition:
    ticket: int
    symbol: str
    type: str
    volume: float
    price_open: float
    sl: float | None
    tp: float | None
    time: datetime


class TradingDataProvider(Protocol):
    def get_account(self) -> AccountSnapshot | None: ...
    def get_open_positions(self) -> list[RawPosition]: ...
    def get_orders(self, start: datetime, end: datetime) -> list[RawOrder]: ...
    def get_deals(self, start: datetime, end: datetime) -> list[RawDeal]: ...
