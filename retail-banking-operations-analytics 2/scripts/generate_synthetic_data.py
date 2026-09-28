"""
One-off script used to generate the synthetic data checked into data/csv/.
Not part of the normal setup flow (use load_data.py for that) — kept here
for transparency on how the sample dataset was produced.
"""
import sqlite3, random, datetime, os

random.seed(42)
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(HERE, "data", "banking_generator_scratch.db")
if os.path.exists(DB):
    os.remove(DB)
conn = sqlite3.connect(DB)
cur = conn.cursor()
cur.executescript("""
PRAGMA foreign_keys = ON;

CREATE TABLE branches (
    branch_id     INTEGER PRIMARY KEY,
    branch_name   TEXT NOT NULL,
    city          TEXT NOT NULL,
    region        TEXT NOT NULL,
    opened_date   TEXT NOT NULL
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
    amount           REAL NOT NULL,
    channel          TEXT NOT NULL CHECK (channel IN ('Branch','ATM','Online','Mobile App','Standing Order')),
    description      TEXT
);

CREATE TABLE loans (
    loan_id          INTEGER PRIMARY KEY,
    customer_id      INTEGER NOT NULL REFERENCES customers(customer_id),
    branch_id        INTEGER NOT NULL REFERENCES branches(branch_id),
    loan_type        TEXT NOT NULL CHECK (loan_type IN ('Personal','Auto','Mortgage','Business')),
    principal_amount REAL NOT NULL,
    interest_rate    REAL NOT NULL,
    start_date       TEXT NOT NULL,
    tenure_months    INTEGER NOT NULL,
    status           TEXT NOT NULL CHECK (status IN ('Active','Closed','Default'))
);

CREATE TABLE loan_payments (
    payment_id       INTEGER PRIMARY KEY,
    loan_id          INTEGER NOT NULL REFERENCES loans(loan_id),
    due_date         TEXT NOT NULL,
    payment_date     TEXT,
    amount_due       REAL NOT NULL,
    amount_paid      REAL NOT NULL,
    payment_status   TEXT NOT NULL CHECK (payment_status IN ('On Time','Late','Missed'))
);

CREATE INDEX idx_accounts_customer ON accounts(customer_id);
CREATE INDEX idx_txn_account ON transactions(account_id);
CREATE INDEX idx_txn_date ON transactions(transaction_date);
CREATE INDEX idx_loans_customer ON loans(customer_id);
CREATE INDEX idx_payments_loan ON loan_payments(loan_id);
""")

# ---------- Branches ----------
branches = [
    (1,"Kotak Mahindra - Mumbai Fort","Mumbai","West","2005-04-01"),
    (2,"Kotak Mahindra - Pune Camp","Pune","West","2007-08-15"),
    (3,"Kotak Mahindra - Delhi CP","Delhi","North","2006-01-10"),
    (4,"BNP Paribas - London City","London","UK","2001-03-20"),
    (5,"BNP Paribas - Manchester","Manchester","UK","2010-06-01"),
    (6,"Citi - Bangalore Tech Park","Bangalore","South","2009-11-11"),
    (7,"Citi - Chennai Anna Salai","Chennai","South","2012-02-14"),
    (8,"HSBC - Birmingham","Birmingham","UK","2003-09-09"),
]
cur.executemany("INSERT INTO branches VALUES (?,?,?,?,?)", branches)

first_names = ["Aarav","Vivaan","Aditya","Vihaan","Arjun","Sai","Reyansh","Ayaan","Krishna","Ishaan",
               "Saanvi","Ananya","Diya","Myra","Aadhya","Pari","Anika","Navya","Kiara","Riya",
               "James","Oliver","Harry","George","Noah","Jack","Charlotte","Amelia","Olivia","Isla",
               "Mohammed","Ahmed","Fatima","Zara","Liam","William","Ethan","Lucas","Emma","Sophia",
               "Rohan","Karan","Neha","Priya","Simran","Aisha","Daniel","Michael","Sarah","Laura"]
last_names = ["Sharma","Verma","Patel","Gupta","Reddy","Nair","Iyer","Kumar","Singh","Mehta",
              "Smith","Johnson","Williams","Brown","Taylor","Wilson","Davies","Evans","Thomas","Roberts",
              "Khan","Ali","Hussain","Malhotra","Chopra","Desai","Joshi","Bose","Rao","Pillai"]
cities = ["Mumbai","Pune","Delhi","London","Manchester","Bangalore","Chennai","Birmingham","Leeds","Hyderabad"]
segments = ["Retail","Retail","Retail","Priority","SME","Private Banking"]

def rand_date(start_year, end_year):
    start = datetime.date(start_year,1,1)
    end = datetime.date(end_year,12,31)
    delta = (end-start).days
    return (start + datetime.timedelta(days=random.randint(0,delta))).isoformat()

# ---------- Customers ----------
N_CUST = 400
customers = []
for cid in range(1, N_CUST+1):
    fn = random.choice(first_names); ln = random.choice(last_names)
    dob = rand_date(1955, 2003)
    gender = random.choice(["Male","Female"])
    city = random.choice(cities)
    since = rand_date(2015, 2025)
    seg = random.choice(segments)
    customers.append((cid, fn, ln, dob, gender, city, since, seg))
cur.executemany("INSERT INTO customers VALUES (?,?,?,?,?,?,?,?)", customers)

# ---------- Accounts ----------
accounts = []
aid = 1
for cid in range(1, N_CUST+1):
    n_acc = random.choices([1,2,3],[0.55,0.35,0.10])[0]
    for _ in range(n_acc):
        branch_id = random.randint(1,8)
        acc_type = random.choices(["Savings","Current","Fixed Deposit"],[0.55,0.30,0.15])[0]
        opened = rand_date(2015, 2026)
        status = random.choices(["Active","Dormant","Closed"],[0.82,0.12,0.06])[0]
        currency = "GBP" if branch_id in (4,5,8) else ("INR" if branch_id in (1,2,3,6,7) else "GBP")
        accounts.append((aid, cid, branch_id, acc_type, opened, status, currency))
        aid += 1
cur.executemany("INSERT INTO accounts VALUES (?,?,?,?,?,?,?)", accounts)
N_ACC = aid - 1

# ---------- Transactions ----------
txn_types_amt = {
    "Deposit": (500, 25000),
    "Withdrawal": (-15000, -100),
    "Transfer In": (200, 20000),
    "Transfer Out": (-18000, -150),
    "Fee": (-50, -5),
    "Interest": (5, 400),
}
channels = ["Branch","ATM","Online","Mobile App","Standing Order"]
transactions = []
tid = 1
today = datetime.date(2026,9,14)
for (acc_id, cust_id, branch_id, acc_type, opened, status, currency) in accounts:
    if status == "Closed":
        continue
    opened_date = datetime.date.fromisoformat(opened)
    start = max(opened_date, today - datetime.timedelta(days=540))
    n_txn = random.randint(3, 45) if status == "Active" else random.randint(0,2)
    for _ in range(n_txn):
        span = (today - start).days
        if span <= 0:
            continue
        tdate = start + datetime.timedelta(days=random.randint(0, span))
        ttype = random.choices(list(txn_types_amt.keys()), [0.28,0.24,0.18,0.18,0.07,0.05])[0]
        lo, hi = txn_types_amt[ttype]
        amount = round(random.uniform(lo, hi), 2)
        channel = random.choice(channels)
        transactions.append((tid, acc_id, tdate.isoformat(), ttype, amount, channel, f"{ttype} via {channel}"))
        tid += 1
cur.executemany("INSERT INTO transactions VALUES (?,?,?,?,?,?,?)", transactions)

# ---------- Loans ----------
loan_types = ["Personal","Auto","Mortgage","Business"]
loans = []
lid = 1
for cid in range(1, N_CUST+1):
    if random.random() < 0.35:
        n_loans = random.choices([1,2],[0.85,0.15])[0]
        for _ in range(n_loans):
            branch_id = random.randint(1,8)
            ltype = random.choices(loan_types,[0.4,0.25,0.2,0.15])[0]
            principal = {"Personal":(50000,500000),"Auto":(200000,1500000),
                         "Mortgage":(1500000,9000000),"Business":(300000,3000000)}[ltype]
            principal_amount = round(random.uniform(*principal), 2)
            rate = round(random.uniform(6.5, 15.5), 2)
            start_date = rand_date(2018, 2025)
            tenure = random.choice([12,24,36,48,60,84,120,180,240])
            status = random.choices(["Active","Closed","Default"],[0.68,0.25,0.07])[0]
            loans.append((lid, cid, branch_id, ltype, principal_amount, rate, start_date, tenure, status))
            lid += 1
cur.executemany("INSERT INTO loans VALUES (?,?,?,?,?,?,?,?,?)", loans)

# ---------- Loan payments ----------
payments = []
pid = 1
for (loan_id, cid, branch_id, ltype, principal, rate, start_date, tenure, status) in loans:
    start = datetime.date.fromisoformat(start_date)
    monthly_due = round(principal / tenure * (1 + rate/100/2), 2)
    months_elapsed = min(tenure, max(0, (today.year-start.year)*12 + (today.month-start.month)))
    for m in range(months_elapsed):
        due_date = (start + datetime.timedelta(days=30*(m+1)))
        r = random.random()
        if status == "Default" and m > months_elapsed - 4:
            pay_status = "Missed"; paid_date = None; amount_paid = 0.0
        elif r < 0.80:
            pay_status = "On Time"; paid_date = due_date.isoformat(); amount_paid = monthly_due
        elif r < 0.94:
            pay_status = "Late"
            paid_date = (due_date + datetime.timedelta(days=random.randint(1,20))).isoformat()
            amount_paid = monthly_due
        else:
            pay_status = "Missed"; paid_date = None; amount_paid = 0.0
        payments.append((pid, loan_id, due_date.isoformat(), paid_date, monthly_due, amount_paid, pay_status))
        pid += 1
cur.executemany("INSERT INTO loan_payments VALUES (?,?,?,?,?,?,?)", payments)

conn.commit()
print("branches:", len(branches))
print("customers:", len(customers))
print("accounts:", len(accounts))
print("transactions:", len(transactions))
print("loans:", len(loans))
print("payments:", len(payments))
conn.close()
