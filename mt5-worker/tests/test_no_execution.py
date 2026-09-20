from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1] / "app"


def test_worker_never_sends_orders():
    banned = re.compile(r"order_send|order_check|positions_close")
    for path in ROOT.rglob("*.py"):
        text = path.read_text()
        assert not banned.search(text), f"Trade execution API found in {path}"
