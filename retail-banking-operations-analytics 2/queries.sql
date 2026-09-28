-- ============================================================
-- Retail Banking Operations Analytics — Analysis Queries
-- Run against: data/banking.db  (build it first with load_data.py)
-- Dialect: SQLite
-- ============================================================


-- ------------------------------------------------------------
-- SECTION 1 — Foundational lookups
-- ------------------------------------------------------------

-- 1.1 Active accounts opened in the last 12 months, with the owning customer
SELECT
    a.account_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    a.account_type,
    a.opened_date,
    b.branch_name
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches  b ON b.branch_id   = a.branch_id
WHERE a.status = 'Active'
  AND a.opened_date >= date('2026-09-14', '-12 months')
ORDER BY a.opened_date DESC;


-- ------------------------------------------------------------
-- SECTION 2 — Aggregation & grouping
-- ------------------------------------------------------------

-- 2.1 Transaction volume and count by transaction type
SELECT
    transaction_type,
    COUNT(*)                       AS num_transactions,
    ROUND(SUM(amount), 2)          AS net_amount,
    ROUND(AVG(amount), 2)          AS avg_amount
FROM transactions
GROUP BY transaction_type
ORDER BY num_transactions DESC;

-- 2.2 Branches with more than 50 active accounts (GROUP BY + HAVING)
SELECT
    b.branch_name,
    b.city,
    COUNT(*) AS active_accounts
FROM accounts a
JOIN branches b ON b.branch_id = a.branch_id
WHERE a.status = 'Active'
GROUP BY b.branch_id
HAVING COUNT(*) > 50
ORDER BY active_accounts DESC;

-- 2.3 Average loan interest rate by loan type and branch region
SELECT
    l.loan_type,
    b.region,
    COUNT(*)                    AS num_loans,
    ROUND(AVG(l.interest_rate), 2) AS avg_interest_rate
FROM loans l
JOIN branches b ON b.branch_id = l.branch_id
GROUP BY l.loan_type, b.region
ORDER BY l.loan_type, avg_interest_rate DESC;


-- ------------------------------------------------------------
-- SECTION 3 — Joins across the customer / account / transaction chain
-- ------------------------------------------------------------

-- 3.1 Current balance per account (derived from transaction history)
SELECT
    a.account_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    a.account_type,
    a.currency,
    ROUND(COALESCE(SUM(t.amount), 0), 2) AS current_balance
FROM accounts a
JOIN customers c      ON c.customer_id = a.customer_id
LEFT JOIN transactions t ON t.account_id = a.account_id
WHERE a.status != 'Closed'
GROUP BY a.account_id
ORDER BY current_balance DESC
LIMIT 20;

-- 3.2 Customer 360 view: balance across all accounts + total outstanding loan exposure
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.segment,
    ROUND(COALESCE(bal.total_balance, 0), 2)   AS total_balance,
    ROUND(COALESCE(loan.total_principal, 0), 2) AS total_loan_exposure
FROM customers c
LEFT JOIN (
    SELECT a.customer_id, SUM(t.amount) AS total_balance
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY a.customer_id
) bal ON bal.customer_id = c.customer_id
LEFT JOIN (
    SELECT customer_id, SUM(principal_amount) AS total_principal
    FROM loans
    WHERE status = 'Active'
    GROUP BY customer_id
) loan ON loan.customer_id = c.customer_id
ORDER BY total_loan_exposure DESC
LIMIT 20;


-- ------------------------------------------------------------
-- SECTION 4 — Subqueries & CTEs
-- ------------------------------------------------------------

-- 4.1 Top 10 customers by total transaction value (deposits + inflows)
WITH customer_flows AS (
    SELECT
        a.customer_id,
        SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END) AS total_inflow,
        SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS total_outflow
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY a.customer_id
)
SELECT
    c.first_name || ' ' || c.last_name AS customer_name,
    c.segment,
    ROUND(f.total_inflow, 2)  AS total_inflow,
    ROUND(f.total_outflow, 2) AS total_outflow
FROM customer_flows f
JOIN customers c ON c.customer_id = f.customer_id
ORDER BY f.total_inflow DESC
LIMIT 10;

-- 4.2 Digital-only customers: never transacted at a branch counter
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name
FROM customers c
WHERE c.customer_id IN (
    SELECT a.customer_id FROM accounts a JOIN transactions t ON t.account_id = a.account_id
)
AND c.customer_id NOT IN (
    SELECT a.customer_id
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    WHERE t.channel = 'Branch'
);

-- 4.3 Customer balance quartiles (NTILE) — segmentation input for marketing/risk
WITH balances AS (
    SELECT a.customer_id, SUM(t.amount) AS total_balance
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY a.customer_id
)
SELECT
    customer_id,
    ROUND(total_balance, 2) AS total_balance,
    NTILE(4) OVER (ORDER BY total_balance DESC) AS balance_quartile
FROM balances
ORDER BY total_balance DESC;


-- ------------------------------------------------------------
-- SECTION 5 — Window functions
-- ------------------------------------------------------------

-- 5.1 Running balance over time for a single account (replace 1 with any account_id)
SELECT
    transaction_id,
    transaction_date,
    transaction_type,
    amount,
    SUM(amount) OVER (
        PARTITION BY account_id ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM transactions
WHERE account_id = 1
ORDER BY transaction_date, transaction_id;

-- 5.2 Rank branches by total deposit volume
SELECT
    b.branch_name,
    ROUND(SUM(t.amount), 2) AS total_deposits,
    RANK() OVER (ORDER BY SUM(t.amount) DESC) AS deposit_rank
FROM transactions t
JOIN accounts a  ON a.account_id = t.account_id
JOIN branches b  ON b.branch_id  = a.branch_id
WHERE t.transaction_type = 'Deposit'
GROUP BY b.branch_id
ORDER BY deposit_rank;

-- 5.3 Month-over-month transaction volume with LAG() growth comparison
WITH monthly AS (
    SELECT
        strftime('%Y-%m', transaction_date) AS txn_month,
        ROUND(SUM(amount), 2) AS net_amount
    FROM transactions
    GROUP BY txn_month
)
SELECT
    txn_month,
    net_amount,
    LAG(net_amount) OVER (ORDER BY txn_month) AS prev_month_amount,
    ROUND(
        (net_amount - LAG(net_amount) OVER (ORDER BY txn_month))
        / NULLIF(ABS(LAG(net_amount) OVER (ORDER BY txn_month)), 0) * 100, 1
    ) AS pct_change
FROM monthly
ORDER BY txn_month;

-- 5.4 Cumulative loan disbursement over time
SELECT
    start_date,
    principal_amount,
    SUM(principal_amount) OVER (ORDER BY start_date) AS cumulative_disbursed
FROM loans
ORDER BY start_date;


-- ------------------------------------------------------------
-- SECTION 6 — Business insights: risk & retention
-- ------------------------------------------------------------

-- 6.1 Accounts at churn risk: active accounts with no transaction in the last 90 days
SELECT
    a.account_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    MAX(t.transaction_date) AS last_transaction_date,
    CASE
        WHEN MAX(t.transaction_date) IS NULL THEN 'No activity on record'
        WHEN julianday('2026-09-14') - julianday(MAX(t.transaction_date)) > 90 THEN 'At Risk'
        ELSE 'Active'
    END AS risk_flag
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
LEFT JOIN transactions t ON t.account_id = a.account_id
WHERE a.status = 'Active'
GROUP BY a.account_id
HAVING risk_flag != 'Active'
ORDER BY last_transaction_date;

-- 6.2 On-time / late / missed payment rate by loan type
SELECT
    l.loan_type,
    lp.payment_status,
    COUNT(*) AS num_payments,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY l.loan_type), 1) AS pct_of_type
FROM loan_payments lp
JOIN loans l ON l.loan_id = lp.loan_id
GROUP BY l.loan_type, lp.payment_status
ORDER BY l.loan_type, lp.payment_status;

-- 6.3 Branches with the highest loan default rate
SELECT
    b.branch_name,
    COUNT(*) AS total_loans,
    SUM(CASE WHEN l.status = 'Default' THEN 1 ELSE 0 END) AS defaulted_loans,
    ROUND(100.0 * SUM(CASE WHEN l.status = 'Default' THEN 1 ELSE 0 END) / COUNT(*), 1) AS default_rate_pct
FROM loans l
JOIN branches b ON b.branch_id = l.branch_id
GROUP BY b.branch_id
HAVING total_loans >= 5
ORDER BY default_rate_pct DESC;

-- 6.4 New account openings by month (trend line input)
SELECT
    strftime('%Y-%m', opened_date) AS open_month,
    COUNT(*) AS accounts_opened
FROM accounts
GROUP BY open_month
ORDER BY open_month;
