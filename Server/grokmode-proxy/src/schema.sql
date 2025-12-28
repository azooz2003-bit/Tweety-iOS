-- GrokMode Credit Tracking Database Schema
-- For Cloudflare D1 (SQLite)

-- Users table (tracks total credits spent)
-- user_id is the appAccountToken (UUID) from StoreKit 2
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT UNIQUE NOT NULL,
    credits_spent REAL DEFAULT 0.0,
    created_at INTEGER DEFAULT (unixepoch()),
    updated_at INTEGER DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id);

-- Receipts table (stores all processed transactions)
CREATE TABLE IF NOT EXISTS receipts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    transaction_id TEXT UNIQUE NOT NULL,
    original_transaction_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    credits_amount REAL NOT NULL,
    purchase_date INTEGER NOT NULL,
    is_trial_period INTEGER DEFAULT 0,
    validated_at INTEGER DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_receipts_user_id ON receipts(user_id);
CREATE INDEX IF NOT EXISTS idx_receipts_transaction_id ON receipts(transaction_id);
CREATE INDEX IF NOT EXISTS idx_receipts_original_transaction_id ON receipts(original_transaction_id);

-- Usage logs (optional - for analytics and debugging)
CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    service TEXT NOT NULL,
    amount REAL NOT NULL,
    cost REAL NOT NULL,
    created_at INTEGER DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_usage_logs_user_id_created ON usage_logs(user_id, created_at);
