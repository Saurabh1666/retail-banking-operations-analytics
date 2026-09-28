Retail Banking Operations Analytics (SQL)
A self-contained SQL portfolio project simulating retail banking operations data — customers, accounts, transactions, and loans across eight branches — with a set of analysis queries covering the kind of reporting a banking operations or analytics team runs day to day: liquidity/transaction trends, branch performance, customer segmentation, and loan risk.

Built with SQLite so it runs anywhere with no server setup, using standard ANSI SQL that ports easily to PostgreSQL / SQL Server / MySQL with minor syntax changes.

Why this project
I'm building a portfolio around business analysis and financial services operations roles, so the schema and questions here are modelled on the kind of operational reporting used in retail/commercial banking (account lifecycle, transaction monitoring, loan repayment risk) rather than a generic textbook dataset.

Entity-relationship diagram

Project structure
.
├── schema.sql          -- DDL: tables, constraints, indexes
├── load_data.py         -- builds data/banking.db from schema.sql + CSVs
├── queries.sql          -- all analysis queries, organised by technique
├── data/
│   └── csv/              -- raw seed data (branches, customers, accounts, ...)
└── README.md
Getting started
git clone <this-repo>
cd retail-banking-operations-analytics
python load_data.py          # builds data/banking.db
sqlite3 data/banking.db      # open a shell and paste queries from queries.sql
# or: sqlite3 data/banking.db < queries.sql
Requires Python 3 (standard library only, no dependencies) and optionally the sqlite3 CLI for exploring interactively.

Dataset
Synthetic but internally consistent — generated with fixed random seeds so results are reproducible. Roughly:

Table	Rows
branches	8
customers	400
accounts	616
transactions	~12,000
loans	165
loan_payments	~6,800
Known simplification: balances are summed across accounts regardless of currency (GBP/INR) for simplicity — in a production system you'd convert to a base currency first.

What the queries cover
queries.sql is organised into six sections, going from basic to advanced:

Foundational lookups — filtered joins across customers/accounts/branches
Aggregation & grouping — GROUP BY / HAVING, transaction mix by type
Multi-table joins — derived account balances, a "customer 360" view
Subqueries & CTEs — top customers by flow, digital-only customers, NTILE() balance quartiles
Window functions — running balance (SUM() OVER), branch ranking (RANK()), month-over-month growth (LAG()), cumulative loan disbursement
Business insights — churn-risk accounts (no activity in 90 days), on-time/late/missed payment rates, branch default-rate ranking, account-opening trend
Sample — month-over-month transaction volume with growth %:

WITH monthly AS (
    SELECT strftime('%Y-%m', transaction_date) AS txn_month,
           ROUND(SUM(amount), 2) AS net_amount
    FROM transactions
    GROUP BY txn_month
)
SELECT txn_month, net_amount,
       LAG(net_amount) OVER (ORDER BY txn_month) AS prev_month_amount,
       ROUND((net_amount - LAG(net_amount) OVER (ORDER BY txn_month))
             / NULLIF(ABS(LAG(net_amount) OVER (ORDER BY txn_month)), 0) * 100, 1) AS pct_change
FROM monthly
ORDER BY txn_month;
Possible extensions
Add a staff table and branch headcount vs. transaction-volume analysis
Build a small BI dashboard (Power BI / Tableau / Looker Studio) on top of queries.sql
Port the schema to PostgreSQL and add EXPLAIN ANALYZE notes on index usage
