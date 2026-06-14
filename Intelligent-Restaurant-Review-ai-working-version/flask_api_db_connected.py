from flask import Flask, request, jsonify
from dotenv import load_dotenv
import mysql.connector
from mysql.connector import Error
import joblib
import os
import uuid
from datetime import datetime

load_dotenv("groq.env")

app = Flask(__name__)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# -----------------------------------------------------------------------------
# Database config for XAMPP / phpMyAdmin
# -----------------------------------------------------------------------------
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 3306,
    "user": "root",
    "password": "",
    "database": "my_restaurant_clean",
}


def get_db_connection():
    return mysql.connector.connect(**DB_CONFIG)


def make_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


def normalize_sentiment(value):
    if value is None:
        return "negative"

    text = str(value).strip().lower()

    if "positive" in text or text in ["pos", "1", "good"]:
        return "positive"

    if "negative" in text or text in ["neg", "0", "bad"]:
        return "negative"

    # No neutral allowed in this project
    return "negative"


@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    return response


# -----------------------------------------------------------------------------
# ML model loading
# -----------------------------------------------------------------------------
MODEL_PATH = os.path.join(BASE_DIR, "sentiment_model.pkl")
VECTORIZER_PATH = os.path.join(BASE_DIR, "vectorizer.pkl")

model = joblib.load(MODEL_PATH)
vectorizer = joblib.load(VECTORIZER_PATH)

try:
    from aspect_analyzer import analyze_aspects
except Exception:
    def analyze_aspects(text):
        return {}


# -----------------------------------------------------------------------------
# Basic routes
# -----------------------------------------------------------------------------
@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "message": "Restaurant sentiment + MySQL + Groq API is running",
        "database": DB_CONFIG["database"],
        "status": "ok",
    })


@app.route("/db-test", methods=["GET"])
def db_test():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SHOW TABLES")
        tables = [row[0] for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return jsonify({"status": "ok", "database": DB_CONFIG["database"], "tables": tables})
    except Error as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# -----------------------------------------------------------------------------
# Sentiment prediction route used by current Flutter code
# -----------------------------------------------------------------------------
@app.route("/predict", methods=["POST"])
def predict_sentiment():
    data = request.get_json(force=True) or {}

    if "reviews" not in data:
        return jsonify({"error": "Missing 'reviews'"}), 400

    reviews = data["reviews"]
    if isinstance(reviews, str):
        reviews = [reviews]

    if not isinstance(reviews, list):
        return jsonify({"error": "'reviews' must be a string or list of strings"}), 400

    results = []

    for review in reviews:
        if review is None or not isinstance(review, str) or not review.strip():
            return jsonify({"error": "Review item must be a non-empty string"}), 400

        review = review.strip()
        review_vector = vectorizer.transform([review])
        prediction = model.predict(review_vector)[0]
        sentiment = normalize_sentiment(prediction)

        confidence = None
        if hasattr(model, "predict_proba"):
            try:
                probs = model.predict_proba(review_vector)[0]
                classes = list(getattr(model, "classes_", []))
                if classes and prediction in classes:
                    confidence = float(probs[classes.index(prediction)])
                else:
                    confidence = float(max(probs))
            except Exception:
                confidence = None

        aspects = analyze_aspects(review)

        results.append({
            "review": review,
            "sentiment": sentiment,
            "aspects": aspects,
            "confidence": confidence,
        })

    return jsonify(results)


# -----------------------------------------------------------------------------
# Auth routes
# -----------------------------------------------------------------------------
@app.route("/auth/register", methods=["POST"])
def register():
    data = request.get_json(force=True) or {}

    name = str(data.get("name", "")).strip()
    email = str(data.get("email", "")).strip().lower()
    password = str(data.get("password", ""))
    is_owner = bool(data.get("isOwner", False))
    phone = str(data.get("phone", "")).strip()
    address = str(data.get("address", "")).strip()

    if not name:
        return jsonify({"error": "Name cannot be empty."}), 400
    if not email:
        return jsonify({"error": "Email cannot be empty."}), 400
    if len(password) < 6:
        return jsonify({"error": "Password must be at least 6 characters."}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            return jsonify({"error": "An account with this email already exists."}), 409

        user_id = make_id("u")
        restaurant_id = None
        role = "owner" if is_owner else "customer"

        cursor.execute(
            """
            INSERT INTO users (id, name, email, password, role, restaurant_id, phone)
            VALUES (%s, %s, %s, %s, %s, NULL, %s)
            """,
            (user_id, name, email, password, role, phone),
        )

        if is_owner:
            restaurant_id = make_id("r")
            cursor.execute(
                """
                INSERT INTO restaurants (id, owner_id, name, address, phone, email)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    restaurant_id,
                    user_id,
                    name,
                    address if address else "Address not set – update in profile",
                    phone if phone else "-",
                    email,
                ),
            )
            cursor.execute(
                "UPDATE users SET restaurant_id = %s WHERE id = %s",
                (restaurant_id, user_id),
            )

        conn.commit()

        user = {
            "id": user_id,
            "name": name,
            "email": email,
            "isOwner": is_owner,
            "role": role,
            "restaurantId": restaurant_id,
            "phone": phone,
        }
        return jsonify({"message": "Register successful", "user": user}), 201

    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


@app.route("/auth/login", methods=["POST"])
def login():
    data = request.get_json(force=True) or {}

    email = str(data.get("email", "")).strip().lower()
    password = str(data.get("password", ""))
    is_owner = bool(data.get("isOwner", False))
    role = "owner" if is_owner else "customer"

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT id, name, email, role, restaurant_id, phone
            FROM users
            WHERE email = %s AND password = %s AND role = %s AND is_active = 1
            LIMIT 1
            """,
            (email, password, role),
        )
        row = cursor.fetchone()
        if not row:
            return jsonify({"error": "Invalid email, password, or account type."}), 401

        user = {
            "id": row["id"],
            "name": row["name"],
            "email": row["email"],
            "isOwner": row["role"] == "owner",
            "role": row["role"],
            "restaurantId": row["restaurant_id"],
            "phone": row["phone"] or "",
        }
        return jsonify({"message": "Login successful", "user": user})

    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


# -----------------------------------------------------------------------------
# Restaurant and menu routes
# -----------------------------------------------------------------------------
@app.route("/restaurants", methods=["GET"])
def get_restaurants():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT id, owner_id, name, address, phone, email, average_rating, total_reviews
            FROM restaurants
            WHERE is_active = 1
            ORDER BY name ASC
            """
        )
        restaurants = cursor.fetchall()
        return jsonify(restaurants)
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


@app.route("/restaurants/<restaurant_id>/menu", methods=["GET"])
def get_menu_items(restaurant_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT id, restaurant_id, name, description, price, category, rating, is_available
            FROM menu_items
            WHERE restaurant_id = %s AND is_available = 1
            ORDER BY created_at DESC
            """,
            (restaurant_id,),
        )
        items = cursor.fetchall()
        for item in items:
            item["price"] = str(item["price"])
            item["rating"] = float(item["rating"])
        return jsonify(items)
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


@app.route("/menu-items", methods=["POST"])
def add_menu_item():
    data = request.get_json(force=True) or {}
    restaurant_id = str(data.get("restaurantId", "")).strip()
    name = str(data.get("name", "")).strip()
    description = str(data.get("description", "")).strip()
    price = str(data.get("price", "0")).replace("RM", "").strip()
    category = str(data.get("category", "General")).strip() or "General"

    if not restaurant_id or not name:
        return jsonify({"error": "restaurantId and name are required."}), 400

    conn = None
    try:
        item_id = make_id("m")
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO menu_items (id, restaurant_id, name, description, price, category)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (item_id, restaurant_id, name, description, price or "0", category),
        )
        conn.commit()
        return jsonify({"message": "Menu item added", "id": item_id}), 201
    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


# -----------------------------------------------------------------------------
# Review routes
# -----------------------------------------------------------------------------
@app.route("/restaurants/<restaurant_id>/reviews", methods=["GET"])
def get_reviews(restaurant_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT id, restaurant_id, user_id, customer_name, rating, comment, sentiment, sentiment_score, created_at
            FROM reviews
            WHERE restaurant_id = %s
            ORDER BY created_at DESC
            """,
            (restaurant_id,),
        )
        reviews = cursor.fetchall()
        for review in reviews:
            review["created_at"] = review["created_at"].isoformat() if review["created_at"] else None
            review["sentiment_score"] = float(review["sentiment_score"]) if review["sentiment_score"] is not None else None
        return jsonify(reviews)
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


@app.route("/reviews", methods=["POST"])
def add_review():
    data = request.get_json(force=True) or {}

    restaurant_id = str(data.get("restaurantId", "")).strip()
    user_id = data.get("userId")
    customer_name = str(data.get("customerName", "Guest")).strip() or "Guest"
    rating = int(data.get("stars", data.get("rating", 0)))
    comment = str(data.get("text", data.get("comment", ""))).strip()

    if not restaurant_id:
        return jsonify({"error": "restaurantId is required."}), 400
    if rating < 1 or rating > 5:
        return jsonify({"error": "Rating must be between 1 and 5."}), 400
    if not comment:
        return jsonify({"error": "Review text cannot be empty."}), 400

    review_vector = vectorizer.transform([comment])
    prediction = model.predict(review_vector)[0]
    sentiment = normalize_sentiment(prediction)

    confidence = None
    if hasattr(model, "predict_proba"):
        try:
            probs = model.predict_proba(review_vector)[0]
            confidence = float(max(probs))
        except Exception:
            confidence = None

    aspects = analyze_aspects(comment)
    review_id = make_id("rv")

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            INSERT INTO reviews (id, restaurant_id, user_id, customer_name, rating, comment, sentiment, sentiment_score)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (review_id, restaurant_id, user_id, customer_name, rating, comment, sentiment, confidence),
        )

        if isinstance(aspects, dict):
            for aspect_name, aspect_value in aspects.items():
                aspect_sentiment = normalize_sentiment(aspect_value)
                cursor.execute(
                    """
                    INSERT INTO review_aspects (review_id, aspect, sentiment, score)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (review_id, str(aspect_name), aspect_sentiment, None),
                )

        cursor.execute(
            """
            INSERT INTO sentiment_prediction_logs (review_id, input_text, predicted_sentiment, confidence_score, model_name, api_status)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (review_id, comment, sentiment, confidence, "sentiment_model.pkl", "success"),
        )

        cursor.execute(
            """
            UPDATE restaurants r
            SET
                r.total_reviews = (SELECT COUNT(*) FROM reviews WHERE restaurant_id = %s),
                r.average_rating = (SELECT COALESCE(AVG(rating), 0) FROM reviews WHERE restaurant_id = %s)
            WHERE r.id = %s
            """,
            (restaurant_id, restaurant_id, restaurant_id),
        )

        conn.commit()

        return jsonify({
            "message": "Review added",
            "review": {
                "id": review_id,
                "restaurantId": restaurant_id,
                "customerName": customer_name,
                "stars": rating,
                "text": comment,
                "sentiment": sentiment,
                "sentimentScore": confidence,
                "aspects": aspects,
            }
        }), 201

    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


@app.route("/restaurants/<restaurant_id>/analytics", methods=["GET"])
def restaurant_analytics(restaurant_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT
                COUNT(*) AS totalReviews,
                COALESCE(AVG(rating), 0) AS avgRating,
                SUM(CASE WHEN sentiment = 'positive' THEN 1 ELSE 0 END) AS positiveCount,
                SUM(CASE WHEN sentiment = 'negative' THEN 1 ELSE 0 END) AS negativeCount,
                SUM(CASE WHEN sentiment = 'neutral' THEN 1 ELSE 0 END) AS neutralCount
            FROM reviews
            WHERE restaurant_id = %s
            """,
            (restaurant_id,),
        )
        row = cursor.fetchone() or {}
        row["avgRating"] = float(row["avgRating"] or 0)
        return jsonify(row)
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()



# -----------------------------------------------------------------------------
# Groq AI summary + suggestions routes
# Used by owner dashboard: /groq/summary and /groq/suggestions
# -----------------------------------------------------------------------------
def _get_groq_client():
    groq_api_key = os.getenv("GROQ_API_KEY")
    if not groq_api_key:
        return None, "GROQ_API_KEY environment variable is missing. Create groq.env in the same folder."
    try:
        from groq import Groq
        return Groq(api_key=groq_api_key), None
    except Exception as e:
        return None, f"Groq package/import failed: {e}. Run: pip install groq python-dotenv"


def _safe_keywords(value, fallback):
    if not value:
        return fallback
    if not isinstance(value, list):
        value = [value]
    cleaned = [str(x).strip() for x in value if str(x).strip()]
    return cleaned if cleaned else fallback


@app.route("/groq/summary", methods=["POST", "OPTIONS"])
def groq_summary():
    if request.method == "OPTIONS":
        return ("", 204)

    data = request.get_json(force=True) or {}

    total_reviews = int(data.get("totalReviews", 0) or 0)
    avg_rating = float(data.get("avgRating", 0.0) or 0.0)
    positive_count = int(data.get("positiveCount", 0) or 0)
    negative_count = int(data.get("negativeCount", 0) or 0)
    positive_keywords = _safe_keywords(data.get("positiveKeywords", []), ["satisfied customers", "good experience"])
    negative_keywords = _safe_keywords(data.get("negativeKeywords", []), ["mixed feedback", "some concerns"])
    restaurant_id = data.get("restaurantId") or data.get("restaurant_id")

    if total_reviews <= 0:
        return jsonify({
            "summary": "No reviews available yet. Customer insights will appear once reviews are submitted.",
            "model": None,
        })

    client, err = _get_groq_client()
    if err:
        return jsonify({"error": err, "summary": None}), 500

    prompt = f"""
You are an AI restaurant review analyst.

Review Statistics:
- Total Reviews: {total_reviews}
- Average Rating: {avg_rating}
- Positive Reviews: {positive_count}
- Negative Reviews: {negative_count}

Positive Keywords:
{', '.join(positive_keywords)}

Negative Keywords:
{', '.join(negative_keywords)}

Instructions:
1. Analyze ONLY the information provided.
2. Do NOT mention food unless food-related keywords appear.
3. Do NOT mention service unless service-related keywords appear.
4. Do NOT invent information.
5. Write exactly 3 sentences.
6. First sentence: overall customer sentiment.
7. Second sentence: main strengths.
8. Third sentence: main weaknesses and recommendation.

Return only the summary text.
"""

    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.4,
            max_tokens=220,
        )
        summary = response.choices[0].message.content.strip()

        # Optional DB log. If logging fails, do not break the dashboard.
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO groq_summary_logs (restaurant_id, prompt_text, summary_text, model_name, api_status)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (restaurant_id, prompt, summary, "llama-3.1-8b-instant", "success"),
            )
            conn.commit()
            cursor.close()
            conn.close()
        except Exception:
            pass

        return jsonify({"summary": summary, "model": "llama-3.1-8b-instant"})
    except Exception as e:
        return jsonify({"error": str(e), "summary": None}), 500


@app.route("/groq/suggestions", methods=["POST", "OPTIONS"])
def groq_suggestions():
    if request.method == "OPTIONS":
        return ("", 204)

    data = request.get_json(force=True) or {}

    total_reviews = int(data.get("totalReviews", 0) or 0)
    avg_rating = float(data.get("avgRating", 0.0) or 0.0)
    positive_count = int(data.get("positiveCount", 0) or 0)
    negative_count = int(data.get("negativeCount", 0) or 0)
    positive_keywords = _safe_keywords(data.get("positiveKeywords", []), ["satisfied customers", "good experience"])
    negative_keywords = _safe_keywords(data.get("negativeKeywords", []), ["mixed feedback", "some concerns"])
    restaurant_id = data.get("restaurantId") or data.get("restaurant_id")

    if total_reviews <= 0:
        return jsonify({
            "suggestions": {
                "Strengths": ["No reviews yet. Suggestions will appear once customers submit reviews."],
                "Areas to Improve": [],
                "Recommended Actions": ["Encourage customers to leave reviews."],
            }
        })

    client, err = _get_groq_client()
    if err:
        return jsonify({"error": err, "suggestions": None}), 500

    prompt = f"""
You are a restaurant business analyst.

Analyze the customer review data and generate recommendations for the restaurant owner.

Data:
- Total Reviews: {total_reviews}
- Average Rating: {avg_rating}
- Positive Reviews: {positive_count}
- Negative Reviews: {negative_count}
- Positive Keywords: {', '.join(positive_keywords)}
- Negative Keywords: {', '.join(negative_keywords)}

Important Malay meanings:
- sedap = delicious
- kotor = dirty / unclean
- lambat = slow
- mahal = expensive
- murah = cheap
- mesra = friendly
- kurang ajar = rude
- bersih = clean
- bising = noisy
- basi = stale

Rules:
1. Focus ONLY on the provided keywords and statistics.
2. Do NOT mention food, service, cleanliness, price, or staff unless supported by the keywords.
3. Generate 3 sections: Strengths, Areas to Improve, Recommended Actions.
4. Each section must contain 2-4 bullet points.
5. Recommendations must be practical and actionable for a restaurant owner.
6. Keep the response under 150 words.
7. Return plain text only using this exact format:

Strengths
• point

Areas to Improve
• point

Recommended Actions
• point
"""

    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.4,
            max_tokens=300,
        )
        raw = response.choices[0].message.content.strip()

        sections = {"Strengths": [], "Areas to Improve": [], "Recommended Actions": []}
        current_section = None
        for line in raw.split("\n"):
            line = line.strip()
            if not line:
                continue
            if line in sections:
                current_section = line
            elif current_section and line.startswith("•"):
                sections[current_section].append(line.lstrip("• ").strip())
            elif current_section and line.startswith("-"):
                sections[current_section].append(line.lstrip("- ").strip())

        for key in sections:
            if not sections[key]:
                if key == "Strengths":
                    sections[key] = [f"Positive feedback from {positive_count} customers."]
                elif key == "Areas to Improve":
                    sections[key] = [f"{negative_count} customers noted concerns."]
                else:
                    sections[key] = ["Continue monitoring customer feedback."]

        # Optional DB log. If logging fails, do not break the dashboard.
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO groq_suggestion_logs (restaurant_id, prompt_text, suggestion_text, model_name, api_status)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (restaurant_id, prompt, raw, "llama-3.1-8b-instant", "success"),
            )
            conn.commit()
            cursor.close()
            conn.close()
        except Exception:
            pass

        return jsonify({"suggestions": sections, "raw": raw})
    except Exception as e:
        return jsonify({"error": str(e), "suggestions": None}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
