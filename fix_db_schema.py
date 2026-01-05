import sqlite3
import os

DB_PATH = "backend/airline.db"

def fix_schema():
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}")
        return

    print(f"Connecting to {DB_PATH}...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    try:
        cursor.execute("BEGIN TRANSACTION")

        # 1. Rename existing table
        print("Renaming 'payments' to 'payments_old'...")
        cursor.execute("ALTER TABLE payments RENAME TO payments_old")

        # 2. Create new table properly (WITHOUT UNIQUE on transaction_id)
        # Note: We keep Index definitions separate usually, but here is the CREATE statement.
        # Based on previous model definition.
        print("Creating new 'payments' table...")
        create_sql = """
        CREATE TABLE payments (
            id INTEGER NOT NULL, 
            transaction_id VARCHAR NOT NULL, 
            booking_id INTEGER NOT NULL, 
            passenger_id INTEGER NOT NULL, 
            amount FLOAT NOT NULL, 
            currency VARCHAR NOT NULL, 
            method VARCHAR(10) NOT NULL, 
            status VARCHAR(8) NOT NULL, 
            created_at DATETIME, 
            PRIMARY KEY (id), 
            FOREIGN KEY(booking_id) REFERENCES bookings (id), 
            FOREIGN KEY(passenger_id) REFERENCES users (id)
        );
        """
        cursor.execute(create_sql)

        # 3. Copy data
        print("Copying data...")
        # Get columns from old table to ensure we map correctly if order changed or new cols added (though we assume same schema minus constraint)
        # simplistic approach: insert into select *
        cursor.execute("INSERT INTO payments SELECT id, transaction_id, booking_id, passenger_id, amount, currency, method, status, created_at FROM payments_old")

        # 4. Drop old table
        print("Dropping 'payments_old'...")
        cursor.execute("DROP TABLE payments_old")

        # 5. Recreate Indices
        print("Recreating indices...")
        cursor.execute("CREATE INDEX ix_payments_id ON payments (id)")
        # CRITICAL: This index must NOT be unique
        cursor.execute("CREATE INDEX ix_payments_transaction_id ON payments (transaction_id)")

        # 6. Check and Fix Users Table
        print("Checking 'users' table schema...")
        cursor.execute("PRAGMA table_info(users)")
        columns = [row[1] for row in cursor.fetchall()]
        
        user_migrations = [
            ("passport_number", "VARCHAR"),
            ("nationality", "VARCHAR"),
            ("date_of_birth", "DATE")
        ]
        
        for col_name, col_type in user_migrations:
            if col_name not in columns:
                print(f"Adding missing column '{col_name}' to 'users'...")
                cursor.execute(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}")
        
        # 7. Commit
        conn.commit()
        print("Migration successful! valid DB state ensured.")

    except Exception as e:
        conn.rollback()
        print(f"An error occurred: {e}")
        import traceback
        traceback.print_exc()
    finally:
        conn.close()

if __name__ == "__main__":
    fix_schema()
