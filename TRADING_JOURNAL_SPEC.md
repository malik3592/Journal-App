# Trading Journal --- Flutter + MT5 System Specification

## 1. Purpose

Build a production-quality cross-platform trading journal application
for **iPhone and Android** using Flutter.

The application automatically imports trading activity from MetaTrader 5
(MT5), then asks the user to complete the human parts of the journal
such as:

-   pre-trade checklist
-   setup/strategy
-   market condition
-   emotion/mindset
-   confidence
-   mistakes
-   notes
-   lessons learned
-   screenshots

The application then turns the imported trading data plus journal data
into dashboards, performance statistics, calendars, charts and progress
reports.

The product is a **journal and analytics application**, not an automated
trading application.

The mobile app must never directly connect to MT5 or store broker
trading passwords.

------------------------------------------------------------------------

# 2. Product Concept

The core loop is:

``` text
MT5 Trade
   ↓
Automatic Import
   ↓
Trade appears in Journal
   ↓
User completes Journal
   ↓
Statistics update
   ↓
User reviews patterns
   ↓
Improves process
```

The user should never have to manually type:

-   entry price
-   exit price
-   lot size
-   open time
-   close time
-   broker ticket
-   profit
-   commission
-   swap
-   symbol
-   direction

Those values come from MT5.

The user manually supplies the information that MT5 cannot know
reliably:

-   why the trade was taken
-   whether the checklist was followed
-   strategy/setup
-   emotional state
-   confidence
-   mistakes
-   lessons
-   screenshots
-   personal notes

------------------------------------------------------------------------

# 3. Design Reference

The provided reference image is the design direction for the product.

Use the reference for:

-   dark premium visual language
-   rounded cards
-   blue primary action
-   green/red performance indicators
-   compact trading statistics
-   professional fintech appearance
-   bottom navigation
-   large readable numbers
-   clean charts

Do NOT copy another product's branding, exact screens, logos or
proprietary UI.

The generated design direction contains these major screens:

1.  Home Dashboard
2.  MT5 Accounts
3.  Trades
4.  Trade Detail
5.  Journal
6.  Analytics
7.  Calendar
8.  Profile / Settings

------------------------------------------------------------------------

# 4. Technology Stack

## Mobile

``` text
Flutter
Dart
Material 3
Cupertino adaptations where appropriate
```

Flutter is appropriate because it supports Android and iOS from a shared
codebase. Flutter's current supported-platform documentation should be
treated as the source of truth for supported OS versions when preparing
releases.

References: - https://docs.flutter.dev/reference/supported-platforms -
https://docs.flutter.dev/resources/architectural-overview -
https://docs.flutter.dev/app-architecture

## Recommended Flutter Packages

Use current stable versions compatible with the selected Flutter SDK.

``` yaml
dependencies:
  flutter:
    sdk: flutter

  flutter_riverpod:
  go_router:
  dio:
  freezed_annotation:
  json_annotation:
  flutter_secure_storage:
  shared_preferences:
  intl:
  fl_chart:
  image_picker:
  cached_network_image:
  connectivity_plus:
  path_provider:
  uuid:
  equatable:
  formz:
```

Development:

``` yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner:
  freezed:
  json_serializable:
  flutter_lints:
```

Use official package documentation/current stable releases when adding
dependencies. Do not blindly copy obsolete versions.

------------------------------------------------------------------------

# 5. Backend Architecture

The mobile app should communicate with a backend.

Recommended:

``` text
                    ┌─────────────────────┐
                    │    Flutter Mobile   │
                    │    iOS + Android    │
                    └──────────┬──────────┘
                               │ HTTPS
                               │ REST/JSON
                               ▼
                    ┌─────────────────────┐
                    │      NestJS API     │
                    │ Auth / Journal /    │
                    │ Analytics / Sync    │
                    └──────┬───────┬──────┘
                           │       │
                    ┌──────▼───┐ ┌─▼──────────┐
                    │PostgreSQL│ │ Redis/Queue │
                    └──────────┘ └────────────┘
                           ▲
                           │
                    ┌──────┴──────────┐
                    │ MT5 Sync Worker │
                    │ Python          │
                    └──────┬──────────┘
                           │
                    ┌──────▼──────────┐
                    │ MT5 Terminal    │
                    │ Windows/VPS     │
                    └──────┬──────────┘
                           │
                         Broker
```

------------------------------------------------------------------------

# 6. Why MT5 Must Not Be Inside Flutter

The official MetaTrader Python integration communicates with the MT5
terminal through interprocess communication. MetaQuotes documents
functions such as:

-   `initialize`
-   `login`
-   `account_info`
-   `positions_get`
-   `history_orders_get`
-   `history_deals_get`
-   `shutdown`

Official documentation: https://www.mql5.com/en/docs/python_metatrader5

Therefore the architecture must be:

``` text
Flutter
  ↓
NestJS
  ↓
MT5 Worker
  ↓
MT5 Terminal
```

NOT:

``` text
Flutter
  ↓
MT5
```

Do not put the Python MT5 package inside the Flutter application.

------------------------------------------------------------------------

# 7. MT5 Integration Strategy

## V1 Recommended Approach

Use a Python service running on a Windows machine or Windows VPS where
the MT5 desktop terminal is installed and connected to the user's broker
account.

The Python service reads MT5 information and sends it to the NestJS
backend.

The application should be **read-only**.

The worker must never call:

``` python
mt5.order_send()
```

or any trade execution function.

The V1 application is not allowed to:

-   open trades
-   close trades
-   modify trades
-   modify SL
-   modify TP

It only reads and journals trading information.

------------------------------------------------------------------------

# 8. MT5 Data Sources

The worker should use:

``` python
mt5.account_info()
mt5.positions_get()
mt5.history_orders_get()
mt5.history_deals_get()
```

MetaQuotes documents `account_info()` as returning information available
about the current trading account, and the Python integration
documentation lists historical orders and deals retrieval functions.

References: - https://www.mql5.com/en/docs/python_metatrader5 -
https://www.mql5.com/en/docs/python_metatrader5/mt5accountinfo_py

------------------------------------------------------------------------

# 9. Important MT5 Data Model Concept

Do not assume:

``` text
1 MT5 order = 1 trade
```

or:

``` text
1 MT5 deal = 1 trade
```

A position can contain:

-   multiple executions
-   partial closes
-   multiple orders
-   multiple deals

The system must preserve raw MT5 data and then create a normalized
journal trade.

Architecture:

``` text
MT5 Orders
    +
MT5 Deals
    +
MT5 Positions
        ↓
Normalization Service
        ↓
Journal Trade
```

------------------------------------------------------------------------

# 10. Application Navigation

Use a five-item bottom navigation:

``` text
Home
Trades
   +
Analytics
More
```

The center `+` button is elevated and visually prominent.

The `+` action opens:

``` text
Manual Trade
Journal Existing Trade
```

MT5-imported trades should normally not be manually recreated.

------------------------------------------------------------------------

# 11. Screen Inventory

Required screens:

``` text
SplashScreen
OnboardingScreen
LoginScreen
RegisterScreen
ForgotPasswordScreen

HomeScreen

AccountsScreen
AddMT5AccountScreen
MT5AccountDetailScreen
SyncStatusScreen

TradesScreen
TradeFilterScreen
TradeDetailScreen

JournalScreen
JournalChecklistScreen
JournalNotesScreen
ScreenshotScreen

AnalyticsScreen
EquityCurveScreen
PerformanceBreakdownScreen
SessionAnalysisScreen
SymbolAnalysisScreen
StrategyAnalysisScreen
EmotionAnalysisScreen

CalendarScreen
DailyReviewScreen
WeeklyReviewScreen

StrategiesScreen
TagsScreen

ProfileScreen
SettingsScreen
NotificationSettingsScreen
DataExportScreen
```

------------------------------------------------------------------------

# 12. Home Dashboard

## Header

``` text
Trading Journal
Track · Analyze · Improve
```

Top-right:

``` text
Settings icon
```

Account selector:

``` text
[ MT5 Account 1 ▼ ]
```

If multiple accounts exist, all dashboard statistics must respect the
selected account.

Option:

``` text
All Accounts
```

------------------------------------------------------------------------

## Equity Card

``` text
Account Equity

$12,432.18

+$451.76 today
+2.34%
```

Secondary:

``` text
Balance
$11,980.42
```

------------------------------------------------------------------------

## KPI Grid

Display:

``` text
Today's P&L
Win Rate
Profit Factor
Max Drawdown
Total Trades
Average R
```

Each KPI must have:

-   title
-   value
-   optional period
-   optional trend
-   tooltip/help

------------------------------------------------------------------------

# 13. Equity Chart

Time controls:

``` text
1D
1W
1M
3M
6M
1Y
ALL
```

Chart requirements:

-   smooth line
-   tooltip
-   date
-   equity value
-   responsive
-   pinch/scroll optional
-   empty state when insufficient data

Do not fabricate data points.

------------------------------------------------------------------------

# 14. Recent Trades

Show:

``` text
Symbol
Direction
Volume
P&L
Result
Close Time
```

Example:

``` text
XAUUSD
BUY · 0.10

+$120.50
WIN
```

Tapping opens Trade Detail.

------------------------------------------------------------------------

# 15. MT5 Accounts Screen

Header:

``` text
MT5 Accounts
Connect and manage your MetaTrader accounts
```

Account card:

``` text
● Connected

MT5 Account 1
Broker Name
****5678

Equity       $12,432.18
Balance      $11,980.42

Last Sync
Sep 18, 2026 7:15 PM

[ Sync Now ]
```

Connection states:

``` text
Connected
Syncing
Disconnected
Error
Needs Attention
```

------------------------------------------------------------------------

# 16. Add MT5 Account

Do not design this as a direct mobile-to-MT5 connection.

Instead show:

``` text
Connect MT5 Account

Your MT5 account will be connected through a secure synchronization service.

Account Number
[             ]

Server
[ Broker-Server ▼ ]

Connection Method
[ MT5 Sync Worker ]

[ Continue ]
```

If the chosen integration requires credentials, explain clearly how they
are handled.

Never store broker passwords in the Flutter application.

For a read-only journal, prefer a broker/integration mechanism that
permits safe read-only access when available.

------------------------------------------------------------------------

# 17. Trade List

Header:

``` text
Trades
Automatically imported from MT5
```

Filters:

``` text
Date
Symbol
Direction
Result
Strategy
Session
Tag
Account
```

Search:

``` text
Search symbol / ticket
```

Trade row:

``` text
XAUUSD
BUY · 0.10

Entry 3648.20
Exit 3660.25

+$120.50
WIN
```

Loss:

``` text
-$45.30
LOSS
```

Open position:

``` text
OPEN
```

------------------------------------------------------------------------

# 18. Trade Detail

The Trade Detail screen is mostly read-only.

Header:

``` text
← Trade Detail

Imported from MT5
```

Trade identity:

``` text
XAUUSD
BUY · 0.10 Lots

WIN
+$120.50
```

Execution section:

``` text
Ticket
Open Time
Close Time
Entry Price
Exit Price
Stop Loss
Take Profit
Volume
```

Financial section:

``` text
Profit
Commission
Swap
Fee
Net P&L
```

Broker section:

``` text
Broker
Server
Account
Magic Number
Order ID
Position ID
Deal ID
```

The values from MT5 should have a visual indicator:

``` text
MT5
```

This tells the user the field was automatically imported.

------------------------------------------------------------------------

# 19. Complete Journal Button

At the bottom:

``` text
[ Complete Journal ]
```

This opens the human journal fields.

Important:

The imported trade data should NOT be editable by default.

If a broker correction is needed, preserve raw data and provide an
explicit adjustment mechanism rather than silently changing broker data.

------------------------------------------------------------------------

# 20. Journal Screen

Top:

``` text
Journal
Complete your trade journal
```

Trade summary:

``` text
XAUUSD
BUY · 0.10

Entry    3648.20
Exit     3660.25
P&L      +$120.50
```

Label:

``` text
MT5 EXECUTION DATA — READ ONLY
```

------------------------------------------------------------------------

# 21. Pre-Trade Checklist

This section is manually completed by the user.

Use expandable section:

``` text
Pre-Trade Checklist
```

Checklist:

``` text
□ Checked higher timeframe
□ Risk within limits
□ Fits my trading plan
□ Key levels identified
□ Economic calendar checked
```

Allow custom checklist items.

Example:

``` text
□ Liquidity identified
□ Confirmation received
□ No emotional impulse
```

Checklist must save:

``` text
item_id
checked
checked_at
```

Store checklist snapshot against the trade so historical reports remain
accurate if the user's default checklist later changes.

------------------------------------------------------------------------

# 22. Strategy / Setup

Manual fields:

``` text
Strategy
[ Breakout ▼ ]

Setup
[ Liquidity Sweep ▼ ]
```

Allow user-defined strategies.

Default strategy options:

``` text
Breakout
Retest
Trend Continuation
Reversal
Support / Resistance
Liquidity Sweep
FVG
Order Block
Other
```

------------------------------------------------------------------------

# 23. Market Condition

Options:

``` text
Trending
Ranging
Volatile
Low Volatility
News Driven
Unclear
```

Allow multiple selections.

------------------------------------------------------------------------

# 24. Emotion / Mindset

Options:

``` text
Calm
Confident
Neutral
Hesitant
Fearful
Greedy
FOMO
Revenge
Frustrated
Overconfident
```

The user can select one primary emotion and optional secondary emotions.

------------------------------------------------------------------------

# 25. Confidence

Use:

``` text
1  2  3  4  5
```

Display:

``` text
Low Confidence
...
High Confidence
```

------------------------------------------------------------------------

# 26. Trade Rating

Use:

``` text
★ ★ ★ ★ ★
```

This rating is a journal/process rating, NOT a rating of profitability.

The user may rate a losing trade 5/5 if it followed the plan.

------------------------------------------------------------------------

# 27. Mistakes

Allow multiple:

``` text
□ Entered early
□ Entered late
□ Oversized
□ Moved stop loss
□ Moved take profit
□ FOMO
□ Revenge trade
□ Ignored confirmation
□ Broke strategy
□ Overtraded
□ None
```

------------------------------------------------------------------------

# 28. Notes

Large text field:

``` text
Trade rationale, entry/exit notes...
```

Allow:

-   plain text
-   line breaks
-   auto-save draft

------------------------------------------------------------------------

# 29. Lessons Learned

Large text field:

``` text
What did I learn from this trade?
```

This should be displayed prominently in review screens.

------------------------------------------------------------------------

# 30. Screenshot Attachments

Allow:

``` text
Before Trade
During Trade
After Trade
```

Actions:

``` text
Take Photo
Choose from Gallery
Delete
View Fullscreen
```

Store images in object storage.

Do not store image binary data inside PostgreSQL.

------------------------------------------------------------------------

# 31. Journal Save Behavior

When saving:

``` text
Validate
 ↓
Save locally
 ↓
Sync API
 ↓
Success
```

If offline:

``` text
Saved locally
Waiting for connection
```

Never lose journal notes because the network is unavailable.

------------------------------------------------------------------------

# 32. Analytics

Analytics should be the second major feature after synchronization.

Top selector:

``` text
7D | 1M | 3M | 6M | 1Y | ALL
```

Account selector:

``` text
Account
```

------------------------------------------------------------------------

# 33. Core Metrics

Calculate:

``` text
Total Trades
Winning Trades
Losing Trades
Win Rate
Net P&L
Gross Profit
Gross Loss
Profit Factor
Average Win
Average Loss
Largest Win
Largest Loss
Expectancy
Max Drawdown
Average R
Average Trade Duration
```

------------------------------------------------------------------------

# 34. Statistics Definitions

## Win Rate

``` text
winning closed trades / total closed trades × 100
```

Do not count open positions.

## Gross Profit

``` text
sum(positive net trade P&L)
```

## Gross Loss

``` text
sum(negative net trade P&L)
```

## Profit Factor

``` text
gross profit / abs(gross loss)
```

If gross loss is zero:

``` text
profit factor = null
```

Do not display infinity.

## Net P&L

``` text
sum(net P&L)
```

## Average Win

``` text
gross profit / number of winning trades
```

## Average Loss

``` text
abs(gross loss) / number of losing trades
```

## Expectancy

``` text
(win_rate × average_win)
-
(loss_rate × average_loss)
```

## Max Drawdown

Use the equity curve.

For each point:

``` text
running_peak = maximum equity to date

drawdown =
(current_equity - running_peak)
/
running_peak
```

Max Drawdown is the largest negative drawdown.

------------------------------------------------------------------------

# 35. Risk / R Calculations

If risk amount is available:

``` text
realized_R = net_profit / risk_amount
```

If risk amount is not available:

``` text
realized_R = null
```

Never estimate risk from lot size alone because contract specifications
differ between instruments and brokers.

If SL exists and the application has reliable contract/tick-value
information, risk can optionally be calculated server-side.

For V1, prefer explicitly stored risk amount or broker-provided
information.

------------------------------------------------------------------------

# 36. Session Analytics

Calculate the trading session from the user's configured timezone.

Default categories:

``` text
Asian
London
New York
London / New York Overlap
Other
```

Do not hardcode a single timezone.

Store timestamps in UTC.

Convert to the user's configured timezone before session classification.

Session report:

``` text
Session       Trades   Win Rate   Net P&L
London        32       71.8%     +$640
New York      28       64.3%     +$420
Asian         12       50.0%     -$30
```

------------------------------------------------------------------------

# 37. Symbol Analytics

Example:

``` text
XAUUSD
EURUSD
GBPUSD
NAS100
```

Metrics:

``` text
Trades
Win Rate
Net P&L
Profit Factor
Average Win
Average Loss
Average R
```

------------------------------------------------------------------------

# 38. Strategy Analytics

For each strategy:

``` text
Strategy
Trades
Win Rate
Net P&L
Profit Factor
Average R
Average Rating
```

Example:

``` text
Liquidity Sweep
24 trades
70.8%
+$520
1.92
+0.62R
```

Do not rank strategies by a single simplistic score.

Allow sorting by any metric.

------------------------------------------------------------------------

# 39. Emotion Analytics

Compare journal emotion against actual historical results.

Example:

``` text
Emotion       Trades   Win Rate   Net P&L
Calm          42       73.8%     +$710
FOMO          11       36.4%     -$180
Revenge       6        33.3%     -$95
```

Use descriptive language:

``` text
Historical result
```

Do not present this as a causal claim.

------------------------------------------------------------------------

# 40. Calendar Screen

Monthly calendar.

Each day displays a P&L indicator.

Example:

``` text
September 2026

Mon Tue Wed Thu Fri Sat Sun

 1   2   3   4   5   6   7
 +   +   -   +   0   0   -

 8   9  10  11  12  13  14
 +   +   +   -   +   0   0
```

Tap a date:

``` text
Daily Review
```

------------------------------------------------------------------------

# 41. Daily Review

Display:

``` text
September 18

Net P&L
+$120.50

Trades
4

Win Rate
75%

Best Trade
XAUUSD +$120.50

Worst Trade
EURUSD -$32.10
```

Journal summary:

``` text
Checklist adherence
Common emotion
Strategies used
Mistakes
Lessons
```

------------------------------------------------------------------------

# 42. Weekly Review

Display:

``` text
Weekly Review

Net P&L
+$620.40

Trades
21

Win Rate
66.7%

Profit Factor
1.88

Average R
0.42R

Max Drawdown
-3.2%
```

Then:

``` text
Best Session
Best Strategy
Most Common Mistake
Most Common Emotion
```

Use neutral descriptive wording.

------------------------------------------------------------------------

# 43. Progress / Goals

Allow personal goals:

``` text
Weekly goal:
Complete journal for 90% of trades

Monthly goal:
Follow checklist on every trade
```

Progress:

``` text
Journal completion
84%

Checklist adherence
91%

Trades reviewed
32 / 40
```

Goals should measure process, not promise financial outcomes.

------------------------------------------------------------------------

# 44. Trade Journal Completion

Each imported closed trade should have:

``` text
Journal Status
Incomplete
Complete
```

Completion can be based on required fields selected by the user.

Default required fields:

``` text
Strategy
Emotion
Notes
Checklist
```

Optional:

``` text
Screenshot
Lessons
Mistakes
Rating
```

Dashboard:

``` text
Journal Completion
42 / 50 trades
84%
```

------------------------------------------------------------------------

# 45. MT5 Sync

The sync service should support:

``` text
Initial sync
Incremental sync
Manual sync
Automatic sync
```

Initial sync:

``` text
Last 30 days
Last 90 days
Last 1 year
All available
```

Let the user select.

------------------------------------------------------------------------

# 46. Incremental Sync Algorithm

Store:

``` text
last_successful_sync_at
```

Next sync:

``` text
from = last_successful_sync_at - overlap
to = current UTC time
```

Use a small overlap to avoid missing delayed records.

Then:

``` text
fetch orders
fetch deals
upsert raw records
normalize trades
update statistics
update sync timestamp
```

------------------------------------------------------------------------

# 47. Idempotency

Never create duplicate records.

Unique constraints:

``` text
account_id + mt5_deal_id
account_id + mt5_order_id
```

For journal trades, use a deterministic mapping based on:

``` text
account_id
position_id
normalized trade identity
```

If a position has partial closes, normalization must update the existing
journal trade rather than create duplicate trades.

------------------------------------------------------------------------

# 48. Sync Worker

Recommended Python project:

``` text
mt5-worker/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── mt5_client.py
│   ├── sync_service.py
│   ├── normalizer.py
│   ├── api_client.py
│   ├── models.py
│   └── logger.py
├── tests/
├── requirements.txt
├── Dockerfile
└── README.md
```

Pseudo-code:

``` python
initialize()

while service_is_running:

    account = account_info()

    positions = positions_get()

    orders = history_orders_get(
        last_sync - overlap,
        now
    )

    deals = history_deals_get(
        last_sync - overlap,
        now
    )

    payload = normalize(
        account,
        positions,
        orders,
        deals
    )

    send_to_backend(payload)

    wait(30)
```

Do not use `order_send`.

------------------------------------------------------------------------

# 49. MT5 Worker Security

The worker communicates with:

``` text
POST /internal/mt5/sync
```

Authenticate using a service credential.

Never expose this endpoint publicly without authentication.

Use:

``` text
HTTPS
service token
IP allowlist where practical
request signature optional
rate limiting
audit logs
```

------------------------------------------------------------------------

# 50. Backend Stack

Recommended:

``` text
NestJS
PostgreSQL
Prisma
Redis
BullMQ
S3-compatible object storage
Docker
```

NestJS modules:

``` text
auth
users
accounts
mt5
sync
trades
journal
analytics
strategies
tags
screenshots
reviews
notifications
files
health
```

------------------------------------------------------------------------

# 51. Flutter Architecture

Follow a clear separation between UI and data layers.

Recommended feature-based structure:

``` text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│
├── core/
│   ├── network/
│   ├── storage/
│   ├── errors/
│   ├── utils/
│   ├── constants/
│   └── extensions/
│
├── shared/
│   ├── widgets/
│   ├── charts/
│   ├── dialogs/
│   └── models/
│
└── features/
    ├── auth/
    ├── dashboard/
    ├── accounts/
    ├── trades/
    ├── journal/
    ├── analytics/
    ├── calendar/
    ├── reviews/
    ├── strategies/
    ├── tags/
    └── settings/
```

Flutter's architecture guidance emphasizes separation of concerns and
distinct UI/data responsibilities. See:
https://docs.flutter.dev/app-architecture/guide

------------------------------------------------------------------------

# 52. State Management

Use Riverpod.

Example:

``` text
authProvider
selectedAccountProvider
dashboardProvider
tradesProvider
tradeDetailProvider
journalProvider
analyticsProvider
calendarProvider
syncStatusProvider
settingsProvider
```

Do not put business logic inside widgets.

Widgets should primarily:

``` text
render state
send user actions
```

Repositories/services should handle:

``` text
API
cache
business logic
```

------------------------------------------------------------------------

# 53. Repository Pattern

Example:

``` text
TradeRepository
   ↓
TradeRemoteDataSource
TradeLocalDataSource
```

Repository decides whether data comes from:

``` text
local cache
remote API
```

This makes offline mode possible.

------------------------------------------------------------------------

# 54. API Client

Use Dio.

Features:

``` text
base URL
JWT interceptor
refresh token interceptor
timeouts
retry policy
logging in development only
error mapping
```

Never log:

``` text
Authorization header
refresh token
password
broker credentials
```

------------------------------------------------------------------------

# 55. Authentication

Support:

``` text
Email/password
Apple Sign-In
Google Sign-In
```

Token model:

``` text
access token
refresh token
```

Access token should be short-lived.

Store tokens using:

``` text
flutter_secure_storage
```

------------------------------------------------------------------------

# 56. Database Schema

## users

``` text
id UUID PK
email
display_name
password_hash nullable
timezone
currency
created_at
updated_at
```

## trading_accounts

``` text
id UUID PK
user_id FK
broker_name
mt5_login
mt5_server
account_type
currency
initial_balance
balance
equity
last_sync_at
sync_status
created_at
updated_at
```

Unique:

``` text
user_id + mt5_login + mt5_server
```

------------------------------------------------------------------------

# 57. MT5 Orders Table

``` text
mt5_orders

id UUID PK
account_id FK
mt5_order_id
mt5_position_id
symbol
order_type
volume
price
sl
tp
state
order_time
raw_payload JSONB
created_at
updated_at
```

Unique:

``` text
account_id + mt5_order_id
```

------------------------------------------------------------------------

# 58. MT5 Deals Table

``` text
mt5_deals

id UUID PK
account_id FK
mt5_deal_id
mt5_order_id
mt5_position_id
symbol
deal_type
entry_type
volume
price
profit
commission
swap
fee
magic
comment
execution_time
raw_payload JSONB
created_at
```

Unique:

``` text
account_id + mt5_deal_id
```

------------------------------------------------------------------------

# 59. Journal Trades Table

``` text
journal_trades

id UUID PK
account_id FK
position_id
symbol
direction
volume
entry_price
exit_price
stop_loss
take_profit
gross_profit
commission
swap
fee
net_profit
risk_amount nullable
realized_r nullable
duration_seconds
opened_at
closed_at
session
strategy_id nullable
market_conditions JSONB
primary_emotion nullable
secondary_emotions JSONB
confidence nullable
rating nullable
mistakes JSONB
notes
lessons
journal_status
created_at
updated_at
```

------------------------------------------------------------------------

# 60. Checklist Tables

## checklist_templates

``` text
id
user_id
name
is_default
created_at
updated_at
```

## checklist_items

``` text
id
template_id
label
sort_order
active
```

## trade_checklist_items

This is a snapshot.

``` text
id
trade_id
label
checked
checked_at
```

Do not simply reference the current template because the template may
change later.

------------------------------------------------------------------------

# 61. Strategies

``` text
strategies

id
user_id
name
description
color
active
created_at
updated_at
```

Users can create custom strategies.

------------------------------------------------------------------------

# 62. Tags

``` text
tags

id
user_id
name
created_at
```

Many-to-many:

``` text
trade_tags
trade_id
tag_id
```

------------------------------------------------------------------------

# 63. Screenshots

``` text
screenshots

id
trade_id
type
storage_key
url
created_at
```

Types:

``` text
before
during
after
```

------------------------------------------------------------------------

# 64. API Endpoints

## Auth

``` http
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
GET /auth/me
```

## Accounts

``` http
GET /accounts
POST /accounts
GET /accounts/:id
PATCH /accounts/:id
DELETE /accounts/:id
POST /accounts/:id/sync
GET /accounts/:id/sync-status
```

## Trades

``` http
GET /trades
GET /trades/:id
PATCH /trades/:id
```

Filters:

``` text
accountId
symbol
direction
result
strategyId
session
tagId
from
to
journalStatus
```

## Journal

``` http
GET /trades/:id/journal
PATCH /trades/:id/journal
POST /trades/:id/checklist
POST /trades/:id/screenshots
DELETE /trades/:id/screenshots/:screenshotId
```

## Analytics

``` http
GET /analytics/overview
GET /analytics/equity
GET /analytics/daily-pnl
GET /analytics/calendar
GET /analytics/sessions
GET /analytics/symbols
GET /analytics/strategies
GET /analytics/emotions
GET /analytics/mistakes
```

## Reviews

``` http
GET /reviews/daily/:date
GET /reviews/weekly/:week
```

------------------------------------------------------------------------

# 65. API Response Example

``` json
{
  "id": "trade-123",
  "accountId": "account-1",
  "symbol": "XAUUSD",
  "direction": "BUY",
  "volume": 0.10,
  "entryPrice": "3648.20",
  "exitPrice": "3660.25",
  "stopLoss": "3642.00",
  "takeProfit": "3669.00",
  "netProfit": "120.50",
  "commission": "-7.00",
  "swap": "-1.20",
  "openedAt": "2026-09-18T14:14:00Z",
  "closedAt": "2026-09-18T15:19:00Z",
  "journalStatus": "INCOMPLETE",
  "source": "MT5"
}
```

Financial values should be serialized safely. Prefer decimal/numeric
types rather than binary floating-point for persisted financial
calculations.

------------------------------------------------------------------------

# 66. Flutter Models

Create strongly typed models.

Example:

``` dart
@freezed
class Trade with _$Trade {
  const factory Trade({
    required String id,
    required String accountId,
    required String symbol,
    required TradeDirection direction,
    required Decimal volume,
    required Decimal entryPrice,
    Decimal? exitPrice,
    Decimal? stopLoss,
    Decimal? takeProfit,
    required Decimal netProfit,
    required DateTime openedAt,
    DateTime? closedAt,
    required JournalStatus journalStatus,
  }) = _Trade;
}
```

If a Decimal package is used, select a maintained package compatible
with the project. Otherwise keep monetary values as strings at the API
boundary and convert carefully for display/calculation.

------------------------------------------------------------------------

# 67. UI Theme

Dark theme.

Suggested palette:

``` text
Background       #080D14
Surface          #101721
Surface Elevated #151E2A
Primary Blue     #1677FF
Gold             #F5C451
Positive         #19C37D
Negative         #EF5350
Primary Text     #F4F7FA
Secondary Text   #8C98A8
Border           #253041
```

Use color semantically:

``` text
Green = positive
Red = negative
Blue = actions / selected state
Gold = XAUUSD / gold-related visual accent
```

Do not use excessive neon effects.

------------------------------------------------------------------------

# 68. Typography

Use:

``` text
Inter
```

or another modern sans-serif with a good Android/iOS fallback.

Hierarchy:

``` text
Display metric
28–34 px

Screen title
24–28 px

Section title
16–18 px

Body
14–16 px

Secondary
12–14 px
```

Do not make everything uppercase.

------------------------------------------------------------------------

# 69. Cards

Cards:

``` text
radius: 14–18
padding: 16
```

Use subtle borders.

Avoid excessive shadows.

------------------------------------------------------------------------

# 70. Responsive Design

The app must work on:

``` text
small iPhone
standard iPhone
large iPhone
small Android
large Android
```

Do not hardcode screen dimensions.

Use:

``` text
LayoutBuilder
MediaQuery
SafeArea
Flexible
Expanded
SliverList
```

For landscape, support scrolling and graceful layout changes.

------------------------------------------------------------------------

# 71. Accessibility

Support:

-   large text
-   screen readers
-   sufficient contrast
-   semantic labels
-   touch targets at least approximately 44x44 logical pixels
-   dynamic content sizing

Do not communicate meaning using color alone.

Example:

``` text
+$120.50
WIN
```

rather than only green.

------------------------------------------------------------------------

# 72. Loading States

Every API-backed screen needs:

``` text
loading
success
empty
error
offline
```

Example:

``` text
No trades yet

Connect an MT5 account to import your trading history.
[ Connect MT5 ]
```

------------------------------------------------------------------------

# 73. Error Handling

User-friendly errors:

``` text
MT5 account could not be synchronized.
Check the MT5 terminal connection and try again.
```

Do not expose stack traces.

Developer logs may contain technical details but must not contain
secrets.

------------------------------------------------------------------------

# 74. Offline Mode

Cache:

``` text
accounts
recent trades
trade details
journal drafts
strategies
tags
analytics summary
```

When offline:

``` text
View data: YES
Edit journal: YES
Sync MT5: NO
Upload screenshots: QUEUED
```

Queue journal edits locally.

When online:

``` text
local changes
 ↓
API
 ↓
server confirmation
 ↓
mark synchronized
```

------------------------------------------------------------------------

# 75. Conflict Handling

For journal fields:

``` text
last-write-wins
```

For MT5 data:

``` text
server is authoritative
```

Do not allow a local mobile edit to overwrite imported MT5 execution
fields.

------------------------------------------------------------------------

# 76. Security Rules

Never put these in the mobile binary:

``` text
database credentials
JWT secret
S3 secret
MT5 worker service token
broker password
```

Use environment variables on the backend.

Use secure storage on mobile.

Always use HTTPS in production.

------------------------------------------------------------------------

# 77. Data Privacy

User trading data is private.

Implement:

``` text
user_id ownership checks
account ownership checks
trade ownership checks
signed screenshot URLs
```

Every backend query must ensure:

``` text
resource.user_id == authenticated_user.id
```

Do not rely only on Flutter hiding records.

------------------------------------------------------------------------

# 78. Screenshot Upload

Recommended flow:

``` text
Flutter
  ↓
POST /files/upload-url
  ↓
NestJS returns signed URL
  ↓
Flutter uploads image
  ↓
POST /trades/:id/screenshots
  ↓
database stores object key
```

Compress images before upload.

Generate thumbnails if needed.

------------------------------------------------------------------------

# 79. Background Synchronization

Important:

A phone cannot be relied upon to keep a persistent MT5 connection
running in the background.

The MT5 sync should run on:

``` text
Windows PC
or
Windows VPS
```

The phone only talks to the backend.

------------------------------------------------------------------------

# 80. Recommended Production Deployment

``` text
                  Internet
                     │
             ┌───────▼────────┐
             │ Flutter Mobile │
             └───────┬────────┘
                     │ HTTPS
                     ▼
             ┌───────────────┐
             │ Load Balancer │
             └───────┬───────┘
                     ▼
             ┌───────────────┐
             │ NestJS API    │
             └──┬─────────┬──┘
                │         │
        ┌───────▼───┐ ┌───▼────┐
        │PostgreSQL │ │ Redis  │
        └───────────┘ └───┬────┘
                           │
                    ┌──────▼──────┐
                    │ BullMQ Jobs │
                    └──────┬──────┘

Windows VPS:
┌─────────────────────────────┐
│ MT5 Terminal                │
│      ↓                      │
│ Python MT5 Sync Worker      │
│      ↓                      │
│ HTTPS → NestJS              │
└─────────────────────────────┘
```

------------------------------------------------------------------------

# 81. Optional Cloud MT5 Integration

If maintaining a Windows MT5 terminal is undesirable, evaluate a
third-party MT5 cloud integration provider.

The architecture becomes:

``` text
Flutter
 ↓
NestJS
 ↓
MT5 Integration Provider
 ↓
Broker / MT5
```

This is a product/vendor decision and may introduce subscription fees
and different account-credential requirements.

Do not hardwire the Flutter UI to one provider.

Create an abstraction:

``` text
TradingDataProvider

  syncAccount()
  getPositions()
  getOrders()
  getDeals()
```

Then implementations can include:

``` text
MT5WorkerProvider
CloudMT5Provider
```

------------------------------------------------------------------------

# 82. Provider Interface

Backend interface:

``` typescript
interface TradingDataProvider {
  getAccount(accountId: string): Promise<TradingAccountData>;
  getOpenPositions(accountId: string): Promise<PositionData[]>;
  getOrders(accountId: string, from: Date, to: Date): Promise<OrderData[]>;
  getDeals(accountId: string, from: Date, to: Date): Promise<DealData[]>;
}
```

This keeps the system replaceable.

------------------------------------------------------------------------

# 83. Analytics API Strategy

Do not calculate all analytics on Flutter.

Backend should calculate authoritative statistics.

Flutter receives:

``` json
{
  "netPnl": "1367.42",
  "winRate": 68.4,
  "profitFactor": 2.14,
  "maxDrawdown": -8.32,
  "totalTrades": 86,
  "averageR": 1.42
}
```

Flutter only formats and visualizes.

------------------------------------------------------------------------

# 84. Analytics Caching

For large datasets:

``` text
raw trades
 ↓
analytics service
 ↓
daily aggregates
 ↓
monthly aggregates
```

Use cached aggregates for dashboard performance.

When a trade changes:

``` text
invalidate affected date/account analytics
```

------------------------------------------------------------------------

# 85. Currency

Account currency comes from MT5.

Do not assume USD.

Store:

``` text
currency = USD
currency = EUR
currency = GBP
```

For V1, show account-native currency.

Multi-currency aggregation can be a future feature.

------------------------------------------------------------------------

# 86. Time Zones

Store all server timestamps as UTC.

User has:

``` text
timezone = Asia/Karachi
```

Display in local timezone.

Allow user to choose timezone manually.

Do not rely solely on device timezone for historical analytics.

------------------------------------------------------------------------

# 87. Partial Close Handling

Example:

``` text
BUY 1.00 lot
close 0.40
close 0.60
```

The system should represent this as one normalized trade/position with:

``` text
volume = 1.00
weighted entry
weighted/realized exit
total realized P&L
```

Preserve the original deals separately.

If partial-close reconstruction cannot be made reliably, mark the trade
as requiring reconciliation instead of silently producing incorrect
data.

------------------------------------------------------------------------

# 88. Open Trades

Open trades should appear in the app but should not be included in:

``` text
win rate
profit factor
closed-trade expectancy
closed-trade average win/loss
```

They may appear in:

``` text
Open P&L
Open Positions
Current Exposure
```

------------------------------------------------------------------------

# 89. P&L Definitions

Keep separate:

``` text
Gross Profit
Commission
Swap
Fee
Net P&L
```

Display:

``` text
Net P&L = profit + commission + swap + fee
```

Verify the exact signs returned by the selected MT5 integration and
normalize them consistently.

Do not double-subtract commission.

------------------------------------------------------------------------

# 90. Journal Completion

Create a progress indicator:

``` text
Journal
████████░░ 80%
```

Required:

``` text
Strategy
Checklist
Emotion
Notes
```

Optional:

``` text
Screenshot
Lessons
Mistakes
Rating
Confidence
```

Allow users to change required fields later.

------------------------------------------------------------------------

# 91. Home Dashboard Additional Cards

Add:

``` text
Journal Completion
84%

Checklist Adherence
91%

Current Streak
4 days

Trades Reviewed
42
```

These are process metrics.

------------------------------------------------------------------------

# 92. Settings

Sections:

``` text
Profile
Trading Accounts
Timezone
Currency
Notifications
Checklist
Strategies
Tags
Appearance
Data Export
Privacy
Security
Help
Logout
```

Appearance:

``` text
Dark
Light
System
```

Default:

``` text
Dark
```

------------------------------------------------------------------------

# 93. Export

Allow:

``` text
CSV
PDF
JSON
```

CSV:

``` text
trade data
journal data
```

PDF:

``` text
performance report
```

JSON:

``` text
complete user export
```

Export must respect user account ownership.

------------------------------------------------------------------------

# 94. Delete Account

Provide:

``` text
Delete Account
```

Require confirmation.

Explain that deletion removes:

``` text
profile
MT5 connection metadata
trades
journal data
screenshots
settings
```

Use a backend deletion job for large datasets.

------------------------------------------------------------------------

# 95. Notifications

Optional V1:

``` text
MT5 disconnected
Sync failed
Journal incomplete
Daily review reminder
Weekly review reminder
```

Do not send price alerts in V1.

------------------------------------------------------------------------

# 96. Testing Requirements

## Flutter Unit Tests

Test:

``` text
trade model parsing
date formatting
journal completion
filter logic
chart data mapping
offline queue
```

## Flutter Widget Tests

Test:

``` text
dashboard
trade list
trade detail
journal
analytics
calendar
settings
```

## Backend Unit Tests

Test:

``` text
win rate
profit factor
expectancy
drawdown
P&L
partial closes
session classification
journal completion
```

## Integration Tests

Test:

``` text
login
account creation
MT5 sync
duplicate prevention
trade retrieval
journal update
screenshot upload
analytics
```

## MT5 Worker Tests

Test:

``` text
MT5 unavailable
terminal disconnected
new deal
duplicate deal
partial close
multiple positions
empty history
API unavailable
authentication failure
```

------------------------------------------------------------------------

# 97. Acceptance Criteria

The MVP is complete only when:

1.  iOS app builds successfully.
2.  Android app builds successfully.
3.  User can register/login.
4.  User can create/select a trading account.
5.  MT5 synchronization works through the backend architecture.
6.  Historical MT5 trades are imported.
7.  New MT5 trades are synchronized.
8.  Duplicate trades are prevented.
9.  Partial closes are handled or explicitly flagged for reconciliation.
10. MT5 execution fields are read-only.
11. User can complete a journal.
12. User can complete a pre-trade checklist.
13. User can select a strategy.
14. User can record emotion.
15. User can add notes.
16. User can add mistakes.
17. User can add lessons.
18. User can upload screenshots.
19. Dashboard statistics are correct.
20. Analytics statistics are correct.
21. Calendar P&L is correct.
22. Session statistics are correct.
23. Strategy statistics are correct.
24. Emotion statistics are correct.
25. Offline journal editing works.
26. Mobile tokens are stored securely.
27. No secrets are shipped in the mobile app.
28. No trade execution is implemented.
29. User can export data.
30. User can delete their account.

------------------------------------------------------------------------

# 98. Development Phases

## Phase 1 --- UI Foundation

Build all screens with mocked data.

``` text
Splash
Login
Home
Accounts
Trades
Trade Detail
Journal
Analytics
Calendar
Settings
```

Do not connect backend yet.

Goal:

``` text
pixel-quality UI
navigation
responsive layouts
```

------------------------------------------------------------------------

## Phase 2 --- Flutter Data Layer

Implement:

``` text
models
repositories
Dio
Riverpod
secure storage
local cache
```

Use fake repository initially.

------------------------------------------------------------------------

## Phase 3 --- NestJS Backend

Implement:

``` text
auth
users
accounts
trades
journal
strategies
tags
analytics
```

Create PostgreSQL schema.

------------------------------------------------------------------------

## Phase 4 --- Real API

Replace mock repository with REST API.

Test:

``` text
login
dashboard
trades
journal
analytics
```

------------------------------------------------------------------------

## Phase 5 --- MT5 Worker

Implement:

``` text
MT5 connection
account information
orders
deals
positions
sync
normalization
duplicate prevention
```

------------------------------------------------------------------------

## Phase 6 --- Analytics

Implement:

``` text
P&L
win rate
profit factor
drawdown
expectancy
R
sessions
symbols
strategies
emotions
calendar
```

------------------------------------------------------------------------

## Phase 7 --- Offline

Implement:

``` text
local cache
journal drafts
sync queue
retry
conflict handling
```

------------------------------------------------------------------------

## Phase 8 --- Production

Implement:

``` text
HTTPS
Docker
database backups
monitoring
logging
crash reporting
App Store build
Google Play build
```

------------------------------------------------------------------------

# 99. Cursor Implementation Instructions

Cursor should implement this project incrementally.

Do NOT generate the entire application in one step.

Use this sequence:

``` text
STEP 1
Create Flutter project and theme.

STEP 2
Create routing and navigation.

STEP 3
Build all screens using mock repositories.

STEP 4
Build models and repositories.

STEP 5
Build NestJS API.

STEP 6
Connect Flutter to API.

STEP 7
Build PostgreSQL schema.

STEP 8
Build MT5 Python worker.

STEP 9
Implement normalization.

STEP 10
Implement analytics.

STEP 11
Implement offline mode.

STEP 12
Implement testing.

STEP 13
Prepare release builds.
```

After each step:

``` text
flutter analyze
flutter test
```

and fix all errors before continuing.

------------------------------------------------------------------------

# 100. Cursor Coding Rules

Cursor MUST:

1.  Use null-safe Dart.
2.  Use strongly typed models.
3.  Keep widgets small.
4.  Keep business logic outside widgets.
5.  Use repositories.
6.  Use Riverpod providers.
7.  Use dependency injection.
8.  Avoid global mutable state.
9.  Avoid hardcoded API URLs.
10. Use environment configuration.
11. Never store secrets in source code.
12. Never store broker passwords in Flutter.
13. Never connect Flutter directly to MT5.
14. Never implement trading execution.
15. Use UTC internally.
16. Use decimal-safe financial calculations.
17. Add tests for calculations.
18. Add loading/error/empty states.
19. Support offline journal drafts.
20. Preserve raw MT5 data.
21. Never overwrite imported execution data with journal data.
22. Make MT5 sync idempotent.
23. Handle partial closes.
24. Never fabricate missing SL/TP/risk data.
25. Do not calculate R if risk amount is unknown.
26. Do not count open trades as closed trades.
27. Do not double-count commission/swap.
28. Use user ownership checks on every API resource.
29. Keep API and UI models separate when appropriate.
30. Document complex normalization logic.

------------------------------------------------------------------------

# 101. Definition of Done for a Screen

Every screen must include:

``` text
loading state
success state
empty state
error state
offline state where relevant
pull-to-refresh where appropriate
responsive layout
accessibility labels
navigation handling
```

No screen should depend on hardcoded fake data after its backend feature
is complete.

------------------------------------------------------------------------

# 102. Design Details for the Provided Add Trade Reference

The supplied reference is useful for manual-entry styling, but this
product should change the workflow.

Instead of:

``` text
Add Trade
Symbol
Quantity
Entry Price
Exit Price
Entry Date
Exit Date
```

the MT5 workflow should be:

``` text
Trade Detail

MT5 Execution Data
────────────────────────
Symbol       XAUUSD
Direction    BUY
Volume       0.10
Entry        3648.20
Exit         3660.25
Open Time    2:14 PM
Close Time   3:19 PM
P&L          +$120.50

[ MT5 data is read-only ]

Journal
────────────────────────
Pre-Trade Checklist
Strategy
Market Condition
Emotion
Confidence
Mistakes
Notes
Lessons
Screenshots

[ Save Journal ]
```

This is a fundamental product requirement.

------------------------------------------------------------------------

# 103. Recommended Trade Detail Layout

``` text
┌─────────────────────────────┐
│ ← Trade Detail       MT5 ✓ │
│                             │
│ XAUUSD       BUY · 0.10     │
│                         WIN │
│                    +$120.50 │
│                             │
│ ┌─────────────────────────┐ │
│ │ MT5 EXECUTION DATA      │ │
│ │                         │ │
│ │ Entry        3648.20    │ │
│ │ Exit         3660.25    │ │
│ │ SL           3642.00    │ │
│ │ TP           3669.00    │ │
│ │ Volume       0.10       │ │
│ │ Open         2:14 PM    │ │
│ │ Close        3:19 PM    │ │
│ └─────────────────────────┘ │
│                             │
│ Journal                     │
│ ┌─────────────────────────┐ │
│ │ ✓ Checklist             │ │
│ │ Strategy       Breakout │ │
│ │ Emotion          Calm   │ │
│ │ Confidence       4/5    │ │
│ │                         │ │
│ │ Notes                   │ │
│ │ [.....................] │ │
│ │                         │ │
│ │ Lessons                 │ │
│ │ [.....................] │ │
│ └─────────────────────────┘ │
│                             │
│ [      Save Journal       ] │
└─────────────────────────────┘
```

------------------------------------------------------------------------

# 104. Empty State Philosophy

When there are no trades:

``` text
Your journal is empty

Connect your MT5 account to automatically import your trades.

[ Connect MT5 ]
```

When there are trades but no journal:

``` text
You have 12 trades waiting for review.

[ Review Trades ]
```

When analytics lacks enough data:

``` text
Not enough data yet

Complete more trades to see this analysis.
```

Do not show misleading zero values when a metric is undefined.

------------------------------------------------------------------------

# 105. Important Financial Accuracy Rules

The app is a journal, so accuracy is more important than visual polish.

Rules:

``` text
Never invent data.
Never infer missing broker fields as facts.
Never display infinity for undefined metrics.
Never treat open P&L as realized P&L.
Never count duplicate MT5 deals twice.
Never count partial closes twice.
Never calculate R without known risk.
Never mix account currencies without conversion.
Never silently modify raw broker data.
```

------------------------------------------------------------------------

# 106. Future Features --- Do Not Build in V1

Keep architecture ready for:

``` text
AI trade review
Trading plan builder
Economic calendar
Trading screenshots with annotations
Advanced chart replay
Backtesting
Social sharing
Community
Achievements
Broker comparison
Multiple cloud MT5 providers
Advanced risk calculator
TradingView integration
```

Do not allow these features to complicate the V1 synchronization and
journaling workflow.

------------------------------------------------------------------------

# 107. Final Product Architecture

The finished system should conceptually look like:

``` text
                  ┌──────────────────────────┐
                  │       iPhone / Android   │
                  │                          │
                  │ Flutter Trading Journal  │
                  │                          │
                  │ Home                     │
                  │ Trades                   │
                  │ Journal                  │
                  │ Analytics                │
                  │ Calendar                 │
                  │ Settings                 │
                  └────────────┬─────────────┘
                               │
                             HTTPS
                               │
                  ┌────────────▼─────────────┐
                  │        NestJS API        │
                  │                          │
                  │ Auth                     │
                  │ Accounts                 │
                  │ Trades                   │
                  │ Journal                  │
                  │ Analytics                │
                  │ Files                    │
                  └──────┬───────────┬───────┘
                         │           │
                  ┌──────▼────┐ ┌───▼────────┐
                  │PostgreSQL │ │Redis/Queue │
                  └───────────┘ └────┬───────┘
                                     │
                              ┌──────▼───────┐
                              │ MT5 Worker   │
                              │ Python       │
                              └──────┬───────┘
                                     │
                              ┌──────▼───────┐
                              │ MT5 Terminal │
                              │ Windows VPS  │
                              └──────┬───────┘
                                     │
                                   Broker
```

------------------------------------------------------------------------

# 108. Primary Success Metric

The application succeeds if the user can:

``` text
Trade on MT5
      ↓
Open the app
      ↓
See the trade automatically
      ↓
Complete their journal in < 1 minute
      ↓
Later review exactly how they performed
      ↓
Identify recurring process patterns
```

The core product is not the chart.

The core product is:

**automatic MT5 data + high-quality journaling + trustworthy
analytics.**

------------------------------------------------------------------------

# 109. References

Flutter:

-   https://docs.flutter.dev/
-   https://docs.flutter.dev/reference/supported-platforms
-   https://docs.flutter.dev/app-architecture
-   https://docs.flutter.dev/app-architecture/guide

MetaTrader 5 Python:

-   https://www.mql5.com/en/docs/python_metatrader5
-   https://www.mql5.com/en/docs/python_metatrader5/mt5accountinfo_py
-   https://www.mql5.com/en/docs/python_metatrader5/mt5historydealsget_py
-   https://www.mql5.com/en/docs/python_metatrader5/mt5historyordersget_py

------------------------------------------------------------------------

# 110. Cursor Starting Prompt

Use the following prompt when starting the implementation:

> You are the senior Flutter/NestJS engineer for this project.
>
> Read `TRADING_JOURNAL_SPEC.md` completely before changing code.
>
> Build a production-quality Flutter application for iOS and Android
> using the architecture and UI specification in this document.
>
> The app is a personal trading journal that receives read-only trading
> data from MetaTrader 5 through a backend synchronization service.
>
> IMPORTANT:
>
> -   Flutter must never connect directly to MT5.
> -   Flutter must never store broker passwords.
> -   V1 must never execute trades.
> -   MT5 execution data is read-only.
> -   User journal fields are editable.
> -   Preserve raw MT5 records.
> -   Synchronization must be idempotent.
> -   Handle partial closes.
> -   Store timestamps in UTC.
> -   Do not calculate R when risk is unknown.
> -   Do not count open trades as closed trades.
> -   Do not fabricate missing data.
>
> First implement the Flutter project foundation, theme, routing, bottom
> navigation and all screen layouts using a mock repository.
>
> Do not implement the entire system in one response.
>
> After each implementation phase:
>
> 1.  Run `flutter analyze`.
> 2.  Run `flutter test`.
> 3.  Fix all errors.
> 4.  Explain what was implemented.
> 5.  Wait for the next phase.
>
> Follow the feature-based architecture and keep business logic outside
> widgets.
