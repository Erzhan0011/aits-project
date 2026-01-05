import sqlite3

def check_columns():
    conn = sqlite3.connect('backend/airline.db')
    cursor = conn.cursor()
    cursor.execute("PRAGMA table_info(users)")
    columns = [row[1] for row in cursor.fetchall()]
    print("User columns:", columns)
    
    required = ['passport_number', 'nationality', 'date_of_birth']
    missing = [col for col in required if col not in columns]
    
    if missing:
        print(f"MISSING COLUMNS: {missing}")
    else:
        print("All required columns are present.")
    conn.close()

if __name__ == "__main__":
    check_columns()
