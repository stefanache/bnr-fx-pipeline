# BNR FX Rates Pipeline

A complete workflow that fetches daily Romanian National Bank (BNR) exchange rates, stores them in Cloudflare D1, and exposes them via a JSON API accessible through RapidAPI.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     CLOUDFLARE (Free Tier)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────┐ │
│  │ Cron Trigger │────▶│   Worker     │────▶│  D1 Database     │ │
│  │ (Daily 8AM)  │     │  (Python)    │     │  (SQLite)        │ │
│  └──────────────┘     └──────────────┘     └──────────────────┘ │
│                              │                      ▲            │
│                              │                      │            │
│                              ▼                      │            │
│                       ┌──────────────┐              │            │
│                       │  API Routes  │──────────────┘            │
│                       │   /rates     │                           │
│                       └──────────────┘                           │
│                              ▲                                   │
└──────────────────────────────│───────────────────────────────────┘
                               │
                        ┌──────┴──────┐
                        │  RapidAPI   │
                        │  Gateway    │
                        └─────────────┘
                               ▲
                               │
                        ┌──────┴──────┐
                        │ Subscribers │
                        └─────────────┘
```

## Features

- **Daily Ingestion**: Cron trigger fetches BNR XML at 8:00 AM UTC
- **D1 Storage**: All rates stored with upsert (no duplicates)
- **JSON API**: Clean REST endpoints for querying rates
- **RapidAPI Ready**: OpenAPI spec included for easy import
- **CI/CD Script**: One-command deployment to Cloudflare

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `GET /rates` | Latest available rates |
| `GET /rates?date=2025-01-15` | Rates for specific date |
| `GET /rates?currency=EUR` | EUR history (last 30 days) |
| `GET /rates?currency=EUR&from=2025-01-01` | EUR from specific date |

## Quick Start

### Prerequisites

- Ubuntu 24.04 LTS (or similar Linux)
- Node.js 18+
- Git
- Cloudflare account (free)
- RapidAPI provider account (free)

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/bnr-fx-pipeline.git
cd bnr-fx-pipeline
```

### 2. Set Environment Variables

```bash
export CLOUDFLARE_API_TOKEN="your-cloudflare-api-token"
export CLOUDFLARE_ACCOUNT_ID="your-cloudflare-account-id"
export GITHUB_REPO="https://github.com/stefanache/bnr-fx-pipeline.git"
```

### 3. Deploy

```bash
chmod +x deploy.sh
./deploy.sh
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLOUDFLARE_API_TOKEN` | Yes | Cloudflare API token with Workers edit permission |
| `CLOUDFLARE_ACCOUNT_ID` | Yes | Your Cloudflare account ID (found in dashboard URL) |
| `GITHUB_REPO` | No | GitHub repo URL for git pull during CI/CD |
| `RAPIDAPI_KEY` | No | RapidAPI provider key for auto-sync |
| `ANTHROPIC_API_KEY` | No | Anthropic API key for Claude Code CLI (AI-assisted development) |

## Getting Cloudflare Credentials

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. **Account ID**: Found in the URL after login: `dash.cloudflare.com/ACCOUNT_ID`
3. **API Token**:
   - Go to "My Profile" → "API Tokens"
   - Click "Create Token"
   - Use template "Edit Cloudflare Workers"
   - Copy the generated token

## Adjusting Cron Schedule

The default schedule is daily at 8:00 AM UTC (11:00 AM Romania time).

To change it, edit `wrangler.toml`:

```toml
[triggers]
crons = ["0 8 * * *"]  # Change this cron expression
```

### Cron Expression Examples

| Expression | Schedule |
|------------|----------|
| `0 8 * * *` | Daily at 8:00 AM UTC |
| `0 6 * * *` | Daily at 6:00 AM UTC |
| `0 */6 * * *` | Every 6 hours |
| `0 8 * * 1-5` | Weekdays at 8:00 AM UTC |

After changing, redeploy:

```bash
wrangler deploy
```

## RapidAPI Setup

1. Go to [RapidAPI Provider Hub](https://rapidapi.com/provider)
2. Click "Add New API"
3. Import from file: Upload `openapi.yaml`
4. Configure:
   - Base URL: `https://bnr-fx-rates.YOUR_ACCOUNT.workers.dev`
   - Plans: Free tier, Basic, Pro (your choice)
5. Publish the API

## Project Structure

```
bnr-fx-pipeline/
├── src/
│   └── worker.py          # Main Worker code (Python)
├── tests/
│   └── test_worker.py     # Unit tests
├── schema.sql             # D1 database schema
├── wrangler.toml          # Cloudflare configuration
├── openapi.yaml           # Swagger/OpenAPI spec
├── deploy.sh              # CI/CD bash script
├── requirements.txt       # Python dependencies
└── README.md              # This file
```

## Testing Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run tests
python -m pytest tests/ -v

# Local development server
wrangler dev
```

## API Response Examples

### Latest Rates

```bash
curl https://bnr-fx-rates.YOUR_ACCOUNT.workers.dev/rates
```

```json
{
  "date": "2025-01-15",
  "base": "RON",
  "rates": [
    {"currency": "EUR", "value": 4.977, "multiplier": 1, "date": "2025-01-15"},
    {"currency": "USD", "value": 4.5623, "multiplier": 1, "date": "2025-01-15"}
  ]
}
```

### Specific Date

```bash
curl "https://bnr-fx-rates.YOUR_ACCOUNT.workers.dev/rates?date=2025-01-10"
```

### Currency History

```bash
curl "https://bnr-fx-rates.YOUR_ACCOUNT.workers.dev/rates?currency=EUR&from=2025-01-01"
```

```json
{
  "currency": "EUR",
  "base": "RON",
  "history": [
    {"currency": "EUR", "value": 4.977, "multiplier": 1, "date": "2025-01-15"},
    {"currency": "EUR", "value": 4.9755, "multiplier": 1, "date": "2025-01-14"}
  ]
}
```

## Costs

Everything runs on **free tiers**:

| Service | Free Limit | Your Usage |
|---------|------------|------------|
| Cloudflare Workers | 100K req/day | ~100-1000 req/day |
| Cloudflare D1 | 5GB storage | ~10MB/year |
| RapidAPI | Unlimited (provider) | Free |

## Troubleshooting

### Worker not responding

```bash
# Check worker status
wrangler tail

# Redeploy
wrangler deploy
```

### No rates in database

```bash
# Manually trigger cron
curl https://bnr-fx-rates.YOUR_ACCOUNT.workers.dev/__scheduled

# Check D1 data
wrangler d1 execute bnr-fx-db --command="SELECT * FROM fx_rates LIMIT 5"
```

### Cron not firing

- Cron changes take up to 15 minutes to propagate
- Check Cloudflare dashboard: Workers → Your Worker → Triggers

## AI-Assisted Development with Claude Code

The deploy script automatically installs Claude Code CLI for AI-assisted development.

### Setup

1. Get an Anthropic API key from [Anthropic Console](https://console.anthropic.com/settings/keys)
2. Set the environment variable:
   ```bash
   export ANTHROPIC_API_KEY="your-anthropic-api-key"
   ```

### Usage

```bash
# Navigate to project directory
cd bnr-fx-pipeline

# Start Claude Code
claude

# Ask Claude to modify the code, for example:
# "Add a new endpoint /rates/convert?from=EUR&to=USD&amount=100"
# "Add caching to reduce database queries"
# "Fix the bug in the XML parser"

# After Claude makes changes, redeploy:
./deploy.sh
```

### Example Prompts

- "Add a new endpoint to convert between currencies"
- "Add rate limiting to the API"
- "Improve error handling in the scheduled fetch"
- "Add more currencies to track"
- "Change the cron schedule to run twice daily"

## License

MIT License
