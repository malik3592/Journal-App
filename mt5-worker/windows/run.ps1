# Run the Journal MT5 worker on Windows next to a logged-in MetaTrader 5 terminal.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path ".venv")) {
  py -3.12 -m venv .venv
}
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements-windows.txt

if (-not (Test-Path ".env")) {
  Copy-Item .\windows\env.example .env
  Write-Host "Created .env from windows/env.example — edit MT5_LOGIN, MT5_SERVER, API_BASE_URL, then re-run."
  exit 0
}

$env:PYTHONPATH = (Get-Location).Path
.\.venv\Scripts\python.exe -m app.main
