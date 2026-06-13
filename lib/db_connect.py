import mysql.connector

try:
    conn = mysql.connector.connect(
        host="127.0.0.1",
        port=3306,
        user="root",
        password="",
        database="my_restaurant_clean"
    )

    cursor = conn.cursor()
    cursor.execute("SHOW TABLES")

    print("✅ Database connected successfully")
    print("Tables:")

    for table in cursor:
        print(table[0])

    cursor.close()
    conn.close()

except Exception as e:
    print("❌ Database connection failed")
    print(e)