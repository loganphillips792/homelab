-- Initializes the test-db Postgres with a sample table and data
-- Note: This runs only on first database initialization (empty data dir)

-- Create the table with a quoted identifier containing a hyphen
CREATE TABLE IF NOT EXISTS "test-table" (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed some test rows
INSERT INTO "test-table" (name)
VALUES ('Alice'), ('Bob'), ('Carol');

