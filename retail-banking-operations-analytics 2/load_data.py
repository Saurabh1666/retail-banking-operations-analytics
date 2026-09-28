"""
Builds banking.db from schema.sql + the CSV files in data/csv/.
Run this first: python load_data.py
"""
import sqlite3, csv, os

HERE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(HERE, "data", "banking.db")
SCHEMA_PATH = os.path.join(HERE, "schema.sql")
CSV_DIR = os.path.join(HERE, "data", "csv")

TABLES = ["branches", "customers", "accounts", "transactions", "loans", "loan_payments"]

def main():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    with open(SCHEMA_PATH) as f:
        cur.executescript(f.read())

    for table in TABLES:
        csv_path = os.path.join(CSV_DIR, f"{table}.csv")
        with open(csv_path, newline="") as f:
            reader = csv.reader(f)
            header = next(reader)
            placeholders = ",".join("?" * len(header))
            rows = list(reader)
            cur.executemany(f"INSERT INTO {table} VALUES ({placeholders})", rows)
        print(f"Loaded {len(rows):>6} rows into {table}")

    conn.commit()
    conn.close()
    print(f"\nDone. Database written to {DB_PATH}")

if __name__ == "__main__":
    main()
