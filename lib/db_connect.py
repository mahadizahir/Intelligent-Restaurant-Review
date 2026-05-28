import mysql.connector

# Connect to MariaDB/MySQL
conn = mysql.connector.connect(
    host="127.0.0.1",
    port=3306,
    user="root",
    password="",
    database="RESTAURANT"
)

# Create cursor
cursor = conn.cursor()

# Test query
cursor.execute("SHOW TABLES")

# Print tables
for table in cursor:
    print(table)

# Close connection
conn.close()