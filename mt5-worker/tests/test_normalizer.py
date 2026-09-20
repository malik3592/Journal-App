from datetime import datetime, timezone

from app.models import RawDeal
from app.normalizer import normalize_trades


def test_partial_close_stays_one_trade():
    deals = [
        RawDeal(1, 10, 99, "XAUUSD", "BUY", "in", 1.0, 2000, 0, 0, 0, 0, 0, "", datetime.now(timezone.utc)),
        RawDeal(2, 11, 99, "XAUUSD", "SELL", "out", 0.4, 2010, 40, -1, 0, 0, 0, "", datetime.now(timezone.utc)),
        RawDeal(3, 12, 99, "XAUUSD", "SELL", "out", 0.6, 2020, 120, -1, 0, 0, 0, "", datetime.now(timezone.utc)),
    ]
    trades = normalize_trades(deals)
    assert len(trades) == 1
    assert trades[0]["volume"] == "1.00"
    assert trades[0]["netProfit"] == "160.00"
    assert trades[0]["needsReconciliation"] is False


def test_duplicate_position_is_single_trade():
    deals = [
        RawDeal(1, 10, 5, "EURUSD", "BUY", "in", 0.2, 1.1, 0, 0, 0, 0, 0, "", datetime.now(timezone.utc)),
        RawDeal(2, 10, 5, "EURUSD", "SELL", "out", 0.2, 1.2, 20, 0, 0, 0, 0, "", datetime.now(timezone.utc)),
        RawDeal(1, 10, 5, "EURUSD", "BUY", "in", 0.2, 1.1, 0, 0, 0, 0, 0, "", datetime.now(timezone.utc)),
    ]
    trades = normalize_trades(deals)
    assert len(trades) == 1
