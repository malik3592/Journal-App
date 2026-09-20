# Journal MT5 Worker

Read-only sync from a MetaTrader 5 terminal into the Journal API.

This process never places, closes, or modifies trades.

## Development (this Mac)

```bash
docker compose up --build
```

`MT5_PROVIDER=mock` posts design-matching demo deals to `POST /internal/mt5/sync`.

In the app, **Connect MT5** with:

- Account number: `12345678`
- Server: `ICMarketsSC-Demo`

## Windows (live MT5)

1. Install MetaTrader 5 and log into the broker (or demo) account.
2. Install Python 3.12.
3. Copy `windows/env.example` to `.env` in this folder.
4. Set `API_BASE_URL` to your NestJS host, plus `MT5_LOGIN` / `MT5_SERVER`.
5. Broker password, if `mt5.login` needs it, stays in this `.env` only — never in the mobile app.
6. Run:

```powershell
.\windows\run.ps1
```

Optional single-file build on a Windows machine:

```powershell
.\.venv\Scripts\pyinstaller.exe windows\journal-worker.spec
```

## Safety

Do not add `order_send`, close, or modify calls. The test suite fails if those symbols appear.
