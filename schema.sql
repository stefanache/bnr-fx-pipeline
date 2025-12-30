-- BNR FX Rates Database Schema for Cloudflare D1
-- Run this to initialize the database: wrangler d1 execute bnr-fx-db --file=./schema.sql

-- Main table for storing exchange rates
CREATE TABLE IF NOT EXISTS fx_rates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rate_date TEXT NOT NULL,               -- Date of the rate from BNR (YYYY-MM-DD)
    currency TEXT NOT NULL,                -- Currency code (EUR, USD, GBP, etc.)
    value REAL NOT NULL,                   -- Exchange rate value against RON
    multiplier INTEGER DEFAULT 1,          -- Multiplier (e.g., 100 for HUF)
    fetched_at TEXT NOT NULL DEFAULT (datetime('now')),  -- When data was fetched (YYYY-MM-DD HH:MM:SS UTC)
    created_at TEXT NOT NULL DEFAULT (datetime('now')),  -- Record creation timestamp
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),  -- Last update timestamp

    -- Ensure unique date+currency combination
    UNIQUE(rate_date, currency)
);

-- Index for fast lookups by date
CREATE INDEX IF NOT EXISTS idx_fx_rates_date ON fx_rates(rate_date);

-- Index for fast lookups by currency
CREATE INDEX IF NOT EXISTS idx_fx_rates_currency ON fx_rates(currency);

-- Index for combined queries
CREATE INDEX IF NOT EXISTS idx_fx_rates_currency_date ON fx_rates(currency, rate_date);

-- Index for fetched_at timestamp queries
CREATE INDEX IF NOT EXISTS idx_fx_rates_fetched ON fx_rates(fetched_at);
