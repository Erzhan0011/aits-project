import sqlite3

def check_structure():
    conn = sqlite3.connect('airline.db')
    cursor = conn.cursor()
    
    tables = ['payments', 'tickets', 'bookings']
    for table in tables:
        print(f"--- Structure of {table} ---")
        cursor.execute(f"SELECT sql FROM sqlite_master WHERE type='table' AND name='{table}'")
        result = cursor.fetchone()
        if result:
            print(result[0])
        else:
            print(f"Table {table} not found")
        print("\n")
        
        # Check indices
        print(f"--- Indices of {table} ---")
        cursor.execute(f"PRAGMA index_list({table})")
        indices = cursor.fetchall()
        for idx in indices:
            path = idx[1]
            unique = "UNIQUE" if idx[2] else "NON-UNIQUE"
            print(f"Index: {path} ({unique})")
        print("\n")

    conn.close()

if __name__ == "__main__":
    check_structure()
