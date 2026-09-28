-- ============================================================
-- Retail Banking Operations Analytics — Schema
-- Dialect: SQLite (portable; minor tweaks needed for Postgres/MySQL)
-- ============================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS loan_payments;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS branches;

CREATE TABLE branches (
    branch_id     INTEGER PRIMARY KEY,
    branch_name   TEXT NOT NULL,
    city          TEXT NOT NULL,
    region        TEXT NOT NULL,
    opened_date   TEXT NOT NULL          -- ISO date
);

CREATE TABLE customers (
    customer_id     INTEGER PRIMARY KEY,
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    date_of_birth   TEXT NOT NULL,
    gender          TEXT NOT NULL,
    city            TEXT NOT NULL,
    customer_since  TEXT NOT NULL,
    segment         TEXT NOT NULL CHECK (segment IN ('Retail','Priority','Private Banking','SME'))
);

CREATE TABLE accounts (
    account_id      INTEGER PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES customers(customer_id),
    branch_id       INTEGER NOT NULL REFERENCES branches(branch_id),
    account_type    TEXT NOT NULL CHECK (account_type IN ('Savings','Current','Fixed Deposit')),
    opened_date     TEXT NOT NULL,
    status          TEXT NOT NULL CHECK (status IN ('Active','Dormant','Closed')),
    currency        TEXT NOT NULL DEFAULT 'GBP'
);

CREATE TABLE transactions (
    transaction_id   INTEGER PRIMARY KEY,
    account_id       INTEGER NOT NULL REFERENCES accounts(account_id),
    transaction_date TEXT NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('Deposit','Withdrawal','Transfer In','Transfer Out','Fee','Interest')),
    amount           REAL NOT NULL,      -- negative = money out, positive = money in
    channel          TEXT NOT NULL CHECK (channel IN ('Branch','ATM','Online','Mobile App','Standing Order')),
    description      TEXT
);

CREATE TABLE loans (
    loan_id          INTEGER PRIMARY KEY,
    customer_id      INTEGER NOT NULL REFERENCES customers(customer_id),
    branch_id        INTEGER NOT NULL REFERENCES branches(branch_id),
    loan_type        TEXT NOT NULL CHECK (loan_type IN ('Personal','Auto','Mortgage','Business')),
    principal_amount REAL NOT NULL,
    interest_rate    REAL NOT NULL,      -- annual %, simple
    start_date       TEXT NOT NULL,
    tenure_months    INTEGER NOT NULL,
    status           TEXT NOT NULL CHECK (status IN ('Active','Closed','Default'))
);

CREATE TABLE loan_payments (
    payment_id       INTEGER PRIMARY KEY,
    loan_id          INTEGER NOT NULL REFERENCES loans(loan_id),
    due_date         TEXT NOT NULL,
    payment_date     TEXT,               -- NULL if missed
    amount_due       REAL NOT NULL,
    amount_paid      REAL NOT NULL,
    payment_status   TEXT NOT NULL CHECK (payment_status IN ('On Time','Late','Missed'))
);

CREATE INDEX idx_accounts_customer ON accounts(customer_id);
CREATE INDEX idx_txn_account       ON transactions(account_id);
CREATE INDEX idx_txn_date          ON transactions(transaction_date);
CREATE INDEX idx_loans_customer    ON loans(customer_id);
CREATE INDEX idx_payments_loan     ON loan_payments(loan_id);
