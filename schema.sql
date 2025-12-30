-- BNR FX Rates Database Schema for Cloudflare D1
-- Run this to initialize the database: wrangler d1 execute bnr-fx-db --file=./schema.sql

-- Main table for storing exchange rates
CREATE TABLE IF NOT EXISTS fx_rates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,                    -- Date of the rate (YYYY-MM-DD)
    currency TEXT NOT NULL,                -- Currency code (EUR, USD, GBP, etc.)
    value REAL NOT NULL,                   -- Exchange rate value against RON
    multiplier INTEGER DEFAULT 1,          -- Multiplier (e.g., 100 for HUF)
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,

    -- Ensure unique date+currency combination
    UNIQUE(date, currency)
);

-- Index for fast lookups by date
CREATE INDEX IF NOT EXISTS idx_fx_rates_date ON fx_rates(date);

-- Index for fast lookups by currency
CREATE INDEX IF NOT EXISTS idx_fx_rates_currency ON fx_rates(currency);

-- Index for combined queries
CREATE INDEX IF NOT EXISTS idx_fx_rates_currency_date ON fx_rates(currency, date);
