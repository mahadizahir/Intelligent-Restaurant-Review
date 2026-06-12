from flask import Flask, request, jsonify, send_from_directory
from dotenv import load_dotenv
import joblib
import os

load_dotenv("groq.env")

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
import pymysql
from flask_cors import CORS

def get_db_connection():
    return pymysql.connect(
        host="localhost",
        user="root",
        password="",  # Your XAMPP password is blank
        database="RESTAURANT",
        cursorclass=pymysql.cursors.DictCursor
    )

app = Flask(__name__)
CORS(app)
print("FLASK FILE LOADED")

UPLOAD_FOLDER = "uploads"

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    return response


MODEL_PATH = os.path.join(BASE_DIR, "sentiment_model.pkl")
VECTORIZER_PATH = os.path.join(BASE_DIR, "vectorizer.pkl")

model = joblib.load(MODEL_PATH)
vectorizer = joblib.load(VECTORIZER_PATH)


@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "message": "Restaurant sentiment + Groq summary API is running",
        "status": "ok"
    })


@app.route("/predict", methods=["POST"])
def predict_sentiment():
    data = request.get_json(force=True)

    reviews = data["reviews"]

    results = []
    for review in reviews:
        review_vector = vectorizer.transform([review])
        prediction = model.predict(review_vector)[0]
        results.append({
            "review": review,
            "sentiment": prediction
        })

@app.route("/test_db", methods=["GET"])
def test_db():
    try:
        conn = get_db_connection()

        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) AS total FROM users")
            result = cursor.fetchone()

        conn.close()

        return jsonify({
            "status": "success",
            "users": result["total"]
        })

    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route("/login", methods=["POST"])
def login():
    try:
        data = request.get_json()

        email = data.get("email")
        password = data.get("password")
        role = data.get("role")

        conn = get_db_connection()

        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT *
                FROM users
                WHERE email=%s
                AND password=%s
                AND role=%s
            """, (email, password, role))

            user = cursor.fetchone()

            restaurant_id = None

            if user and role == "owner":

                cursor.execute("""
                    SELECT restaurant_id
                    FROM restaurants
                    WHERE owner_id = %s
                """, (user["user_id"],))

                restaurant = cursor.fetchone()

                if restaurant:
                    restaurant_id = restaurant["restaurant_id"]

        conn.close()

        print("LOGIN SUCCESS")
        print("USER =", user)
        print("RESTAURANT_ID =", restaurant_id)

        if user:
            return jsonify({
                "success": True,
                "user_id": user["user_id"],
                "name": user["name"],
                "email": user["email"],
                "phone": user["phone"],
                "role": user["role"],
                "restaurant_id": restaurant_id
            })

        return jsonify({
            "success": False,
            "message": "Invalid email, password, or account type."
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500

@app.route("/restaurants", methods=["GET"])
def get_restaurants():
    print("ENTERED RESTAURANTS ROUTE")

    try:
        conn = get_db_connection()

        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    restaurant_id,
                    owner_id,
                    name,
                    address
                FROM restaurants
            """)

            restaurants = cursor.fetchall()

        conn.close()

        return jsonify(restaurants)

    except Exception as e:
        print("ERROR:", e)

        return jsonify({
            "success": False,
            "message": str(e)
        }), 500

@app.route("/menu_items", methods=["GET"])
def get_menu_items():
    try:
        conn = get_db_connection()

        with conn.cursor() as cursor:
            cursor.execute("""
               SELECT
                    menu_id,
                    restaurant_id,
                    item_name,
                    category,
                    price,
                    image_path
                FROM menu_items
            """)

            items = cursor.fetchall()

        conn.close()

        return jsonify(items)

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500

@app.route("/reviews/<int:restaurant_id>", methods=["GET"])
def get_reviews(restaurant_id):
    try:
        conn = get_db_connection()

        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    r.review_id,
                    r.rating,
                    r.comment,
                    u.name AS customer_name,
                    s.sentiment
                FROM reviews r
                JOIN users u
                    ON r.user_id = u.user_id
                LEFT JOIN sentiment_analysis s
                    ON r.review_id = s.review_id
                WHERE r.restaurant_id = %s
                ORDER BY r.created_at DESC
            """, (restaurant_id,))

            reviews = cursor.fetchall()

        conn.close()

        return jsonify(reviews)

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500

@app.route("/add_review", methods=["POST"])
def add_review():

    print("ADD REVIEW ROUTE ENTERED")

    try:
        data = request.get_json()

        user_id = data["user_id"]
        restaurant_id = data["restaurant_id"]

        rating = data["rating"]
        comment = data["comment"]

        food_rating = data["food_rating"]
        service_rating = data["service_rating"]
        price_rating = data["price_rating"]
        cleanliness_rating = data["cleanliness_rating"]

        # Sentiment prediction
        review_vector = vectorizer.transform([comment])

        sentiment = model.predict(review_vector)[0]

        try:
            score = float(max(model.predict_proba(review_vector)[0]))
        except:
            score = 0.0

        conn = get_db_connection()

        with conn.cursor() as cursor:

            # Insert into reviews
            cursor.execute("""
                INSERT INTO reviews
                (user_id, restaurant_id, rating, comment)
                VALUES (%s,%s,%s,%s)
            """, (
                user_id,
                restaurant_id,
                rating,
                comment
            ))

            review_id = cursor.lastrowid

            # Insert into review_details
            cursor.execute("""
                INSERT INTO review_details
                (
                    review_id,
                    food_rating,
                    service_rating,
                    price_rating,
                    cleanliness_rating
                )
                VALUES (%s,%s,%s,%s,%s)
            """, (
                review_id,
                food_rating,
                service_rating,
                price_rating,
                cleanliness_rating
            ))

            conn.commit()

            print("ABOUT TO INSERT SENTIMENT")
            print("review_id =", review_id)
            print("sentiment =", sentiment)
            print("score =", score)

            # Insert sentiment result
            cursor.execute("""
                INSERT INTO sentiment_analysis
                (
                    review_id,
                    sentiment,
                    score
                )
                VALUES (%s,%s,%s)
            """, (
                review_id,
                sentiment.lower(),
                score
            ))
            
            print("SENTIMENT INSERT SUCCESS")

            conn.commit()

        conn.close()

        return jsonify({
            "success": True,
            "review_id": review_id,
            "sentiment": sentiment
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500

@app.route("/restaurant_rating/<int:restaurant_id>", methods=["GET"])
def restaurant_rating(restaurant_id):
    try:
        conn = get_db_connection()

        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT AVG(rating) AS avg_rating
                FROM reviews
                WHERE restaurant_id = %s
            """, (restaurant_id,))

            result = cursor.fetchone()

        conn.close()

        return jsonify({
            "average_rating": float(result["avg_rating"])
            if result["avg_rating"] is not None
            else 0
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500

@app.route("/uploads/<filename>")
def uploaded_file(filename):
    return send_from_directory(
        "uploads",
        filename
    )

@app.route("/restaurant_metrics/<int:restaurant_id>", methods=["GET"])
def restaurant_metrics(restaurant_id):
    try:
        conn = get_db_connection()

        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT
                    AVG(rd.food_rating) AS food_avg,
                    AVG(rd.service_rating) AS service_avg,
                    AVG(rd.price_rating) AS price_avg,
                    AVG(rd.cleanliness_rating) AS cleanliness_avg
                FROM review_details rd
                JOIN reviews r
                    ON rd.review_id = r.review_id
                WHERE r.restaurant_id = %s
            """, (restaurant_id,))

            result = cursor.fetchone()

        conn.close()

        return jsonify({
            "food": float(result["food_avg"] or 0),
            "service": float(result["service_avg"] or 0),
            "price": float(result["price_avg"] or 0),
            "cleanliness": float(result["cleanliness_avg"] or 0)
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500

@app.route("/update_menu_image", methods=["POST"])
def update_menu_image():

    try:

        menu_id = request.form.get("menu_id")
        image = request.files.get("image")

        if not menu_id or not image:
            return jsonify({
                "success": False,
                "message": "Missing menu_id or image"
            }), 400

        filename = image.filename

        filepath = os.path.join(
            UPLOAD_FOLDER,
            filename
        )

        image.save(filepath)

        conn = get_db_connection()

        with conn.cursor() as cursor:

            print("MENU ID RECEIVED =", menu_id)
            print("FILENAME RECEIVED =", filename)

            cursor.execute("""
                UPDATE menu_items
                SET image_path=%s
                WHERE menu_id=%s
            """, (
                filename,
                menu_id
            ))

            print("ROWS UPDATED =", cursor.rowcount)

            cursor.execute("""
                SELECT
                    menu_id,
                    image_path
                FROM menu_items
                WHERE menu_id=%s
            """, (menu_id,))

            print("AFTER UPDATE =", cursor.fetchone())

        conn.commit()
        conn.close()

        return jsonify({
            "success": True,
            "image_path": filename
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500
    
@app.route("/debug_db")
def debug_db():

    conn = get_db_connection()

    with conn.cursor() as cursor:

        cursor.execute("SELECT DATABASE() AS db")
        result = cursor.fetchone()

    conn.close()

    return jsonify(result)

@app.route("/test_menu_columns")
def test_menu_columns():

    conn = get_db_connection()

    with conn.cursor() as cursor:

        cursor.execute("""
            SHOW COLUMNS FROM menu_items
        """)

        result = cursor.fetchall()

    conn.close()

    return jsonify(result)

@app.route("/check_image/<menu_id>")
def check_image(menu_id):

    conn = get_db_connection()

    with conn.cursor() as cursor:

        cursor.execute("""
            SELECT menu_id, item_name, image_path
            FROM menu_items
            WHERE menu_id=%s
        """, (menu_id,))

        data = cursor.fetchone()

    conn.close()

    return jsonify(data)

@app.route("/debug_menu/<int:menu_id>")
def debug_menu(menu_id):

    conn = get_db_connection()

    with conn.cursor() as cursor:
        cursor.execute("""
            SELECT menu_id, image_path
            FROM menu_items
            WHERE menu_id=%s
        """, (menu_id,))

        result = cursor.fetchone()

    conn.close()

    return jsonify(result)    
    


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

