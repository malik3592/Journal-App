# Journal Trading Journal

Flutter journal for iOS and Android, a NestJS API, and a read-only MT5 worker.

```text
Flutter  →  NestJS  →  MongoDB (Mongoose)
                ↑
         Python MT5 worker (mock on Mac, live on Windows)
```

The mobile app never talks to MT5 and never stores a broker password. The worker never places trades.

## Quick start (this Mac)

```bash
docker compose up --build
```

API: `http://127.0.0.1:3000`

Local MongoDB (this Mac already running `mongod`):

```text
mongodb://127.0.0.1:27017/journal
```

Docker Compose Mongo is published at `localhost:27018` so it does not collide with that local `mongod`. The API container talks to Mongo on the internal Docker network.

```bash
cd mobile
flutter run
```

1. Register an account.
2. Choose **Connect MT5** and keep demo login `12345678` / `ICMarketsSC-Demo`.
3. The mock worker imports sample trades. Complete a journal, or add a manual trade from `+`.

## Windows live MT5

See [mt5-worker/README.md](mt5-worker/README.md). Run `windows/run.ps1` next to a logged-in MetaTrader 5 terminal.
