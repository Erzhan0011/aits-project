import sqlite3
import os

DB_PATH = "backend/airline.db"

def check_schema():
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Check users table
    print("Checking 'users' table columns:")
    cursor.execute("PRAGMA table_info(users)")
    columns = [row[1] for row in cursor.fetchall()]
    print(columns)
    
    missing = []
    for col in ['passport_number', 'nationality', 'date_of_birth']:
        if col not in columns:
            missing.append(col)
            
    if missing:
        print(f"\n❌ MISSING COLUMNS: {missing}")
        print("Please run fix_db_schema.py to add them.")
    else:
        print("\n✅ All required columns present.")
        
    conn.close()



if __name__ == "__main__":
    check_schema()
