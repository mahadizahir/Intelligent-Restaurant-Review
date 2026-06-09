from flask import Flask, request, jsonify
import joblib
import os

app = Flask(__name__)

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

    return jsonify(results)


@app.route("/groq/summary", methods=["POST"])

def groq_summary():
    """Generate a short restaurant owner insight summary using Groq LLM.

    Expects JSON body:
    {
      "totalReviews": int,
      "avgRating": float,
      "positiveCount": int,
      "negativeCount": int,
      "positiveKeywords": [String],
      "negativeKeywords": [String]
    }
    """
    data = request.get_json(force=True) or {}

    total_reviews = int(data.get("totalReviews", 0))
    avg_rating = float(data.get("avgRating", 0.0))
    positive_count = int(data.get("positiveCount", 0))
    negative_count = int(data.get("negativeCount", 0))
    positive_keywords = data.get("positiveKeywords", []) or []
    negative_keywords = data.get("negativeKeywords", []) or []

    if total_reviews <= 0:
        return jsonify({
            "summary": "No reviews available yet. Customer insights will appear once reviews are submitted.",
            "model": None
        })

    # Read Groq API key from environment (do NOT hardcode)
    groq_api_key = os.getenv("GROQ_API_KEY")
    if not groq_api_key:
        return jsonify({
            "error": "GROQ_API_KEY environment variable is missing.",
            "summary": None
        }), 500

    from groq import Groq

    client = Groq(api_key=groq_api_key)

    # Keep prompt short and force 2-4 sentences.
    sentiment_trend = (
        "mostly positive" if positive_count > negative_count else
        "mostly negative" if negative_count > positive_count else
        "mixed"
    )

    # Safety fallback: if keywords are unexpectedly empty, avoid sending empty strings/dashes.
    if not positive_keywords:
        positive_keywords = ["great food", "good service"]
    if not negative_keywords:
        negative_keywords = ["slow service", "cleanliness issues"]

    # Guard against accidental empty/blank entries.
    positive_keywords = [str(x).strip() for x in positive_keywords if str(x).strip()]
    negative_keywords = [str(x).strip() for x in negative_keywords if str(x).strip()]

    if not positive_keywords:
        positive_keywords = ["great food", "good service"]
    if not negative_keywords:
        negative_keywords = ["slow service", "cleanliness issues"]

    # Debug: log what we're sending to Groq.
    print("Flask Groq Debug -> positiveKeywords", positive_keywords)
    print("Flask Groq Debug -> negativeKeywords", negative_keywords)

    pos_kw = ", ".join([str(x) for x in positive_keywords[:5]])
    neg_kw = ", ".join([str(x) for x in negative_keywords[:5]])

    prompt = (
        "You are an analytics assistant for a restaurant owner. "
        "Using the provided analytics, write a professional, friendly insight summary in 2 to 4 concise sentences. "
        "Requirements: Mention overall sentiment ({sentiment_trend}), average rating ({avg_rating}), and total reviews ({total_reviews}). "
        "Mention strengths using the most common positive keywords: {pos_kw}. "
        "Mention concerns using the most common negative keywords: {neg_kw}. "
        "End with exactly one actionable recommendation for improvement. "
        "Do not add bullet points. Use plain English."
    ).format(
        sentiment_trend=sentiment_trend,
        avg_rating=avg_rating,
        total_reviews=total_reviews,
        pos_kw=pos_kw,
        neg_kw=neg_kw,
    )


    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.4,
            max_tokens=220,
        )
        summary = response.choices[0].message.content.strip()
        return jsonify({"summary": summary, "model": "llama-3.1-8b-instant"})

    except Exception as e:
        return jsonify({"error": str(e), "summary": None}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

