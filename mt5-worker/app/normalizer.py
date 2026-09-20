from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone

from app.models import RawDeal, RawPosition


def normalize_trades(
    deals: list[RawDeal],
    positions: list[RawPosition] | None = None,
) -> list[dict]:
    """Collapse MT5 deals into one journal trade per position.

    Partial closes update the same position identity. If in/out volumes
    cannot be reconciled, the trade is flagged instead of guessed.
    """
    grouped: dict[int, list[RawDeal]] = defaultdict(list)
    for deal in deals:
        if deal.position_id:
            grouped[deal.position_id].append(deal)

    trades: list[dict] = []
    for position_id, rows in grouped.items():
        rows = sorted(rows, key=lambda d: d.time)
        ins = [d for d in rows if _is_entry(d)]
        outs = [d for d in rows if not _is_entry(d)]
        if not ins:
            continue
        volume_in = sum(d.volume for d in ins)
        volume_out = sum(d.volume for d in outs)
        entry_price = _weighted(ins)
        exit_price = _weighted(outs) if outs else None
        direction = "BUY" if _is_buy(ins[0]) else "SELL"
        profit = sum(d.profit for d in rows)
        commission = sum(d.commission for d in rows)
        swap = sum(d.swap for d in rows)
        fee = sum(d.fee for d in rows)
        opened_at = ins[0].time
        closed_at = outs[-1].time if volume_out >= volume_in - 1e-8 and outs else None
        needs_reconciliation = volume_out - volume_in > 1e-8
        trades.append(
            {
                "positionId": str(position_id),
                "symbol": ins[0].symbol,
                "direction": direction,
                "volume": f"{volume_in:.2f}",
                "entryPrice": f"{entry_price:.5f}",
                "exitPrice": f"{exit_price:.5f}" if exit_price is not None else None,
                "netProfit": f"{profit:.2f}",
                "commission": f"{commission:.2f}",
                "swap": f"{swap:.2f}",
                "fee": f"{fee:.2f}",
                "grossProfit": f"{(profit - commission - swap - fee):.2f}",
                "openedAt": _iso(opened_at),
                "closedAt": _iso(closed_at) if closed_at else None,
                "ticket": str(ins[0].ticket),
                "orderId": str(ins[0].order),
                "dealId": str(rows[-1].ticket),
                "magicNumber": ins[0].magic,
                "needsReconciliation": needs_reconciliation,
            }
        )

    for position in positions or []:
        if str(position.ticket) in {t["positionId"] for t in trades}:
            continue
        trades.append(
            {
                "positionId": str(position.ticket),
                "symbol": position.symbol,
                "direction": position.type,
                "volume": f"{position.volume:.2f}",
                "entryPrice": f"{position.price_open:.5f}",
                "exitPrice": None,
                "netProfit": "0.00",
                "commission": "0.00",
                "swap": "0.00",
                "fee": "0.00",
                "grossProfit": "0.00",
                "openedAt": _iso(position.time),
                "closedAt": None,
                "ticket": str(position.ticket),
                "needsReconciliation": False,
            }
        )
    return trades


def _is_entry(deal: RawDeal) -> bool:
    return str(deal.entry).lower() in {"in", "entry", "0", "deal_entry_in"}


def _is_buy(deal: RawDeal) -> bool:
    return str(deal.type).upper() in {"BUY", "0", "DEAL_TYPE_BUY"}


def _weighted(deals: list[RawDeal]) -> float:
    total = sum(d.volume for d in deals)
    if total <= 0:
        return 0.0
    return sum(d.price * d.volume for d in deals) / total


def _iso(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
