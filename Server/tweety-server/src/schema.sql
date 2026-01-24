-- GrokMode Credit Tracking Database Schema
-- For Cloudflare D1 (SQLite)

-- Users table (tracks total credits spent)
-- user_id is the X (Twitter) user ID sent via X-User-Id header
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT UNIQUE NOT NULL,
    credits_spent REAL DEFAULT 0.0,
    created_at INTEGER DEFAULT (unixepoch()),
    updated_at INTEGER DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id);

-- Free access users table (users who can use Tweety without a subscription)
-- Manually add X user IDs to this table to grant free access
CREATE TABLE IF NOT EXISTS free_access_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    x_user_id TEXT UNIQUE NOT NULL,
    granted_date INTEGER DEFAULT (unixepoch()),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_free_access_x_user_id ON free_access_users(x_user_id);

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
    transaction_type TEXT,
    previous_product_id TEXT,
    revocation_date INTEGER,
    revocation_reason TEXT,
    expiration_date INTEGER,
    notes TEXT,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_receipts_user_id ON receipts(user_id);
CREATE INDEX IF NOT EXISTS idx_receipts_transaction_id ON receipts(transaction_id);
CREATE INDEX IF NOT EXISTS idx_receipts_original_transaction_id ON receipts(original_transaction_id);
CREATE INDEX IF NOT EXISTS idx_receipts_original_purchase_date ON receipts(original_transaction_id, purchase_date);

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
