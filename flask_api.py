from flask import Flask, request, jsonify
from dotenv import load_dotenv
import joblib
import os

load_dotenv("groq.env")

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

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
    """Generate exactly-3-sentence customer sentiment summary using Groq LLM.

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

    groq_api_key = os.getenv("GROQ_API_KEY")
    if not groq_api_key:
        return jsonify({
            "error": "GROQ_API_KEY environment variable is missing.",
            "summary": None
        }), 500

    from groq import Groq

    client = Groq(api_key=groq_api_key)

    # Safety fallback: avoid sending empty/blank keyword lists.
    if not positive_keywords:
        positive_keywords = ["great food", "good service"]
    if not negative_keywords:
        negative_keywords = ["slow service", "cleanliness issues"]

    positive_keywords = [str(x).strip() for x in positive_keywords if str(x).strip()]
    negative_keywords = [str(x).strip() for x in negative_keywords if str(x).strip()]

    if not positive_keywords:
        positive_keywords = ["great food", "good service"]
    if not negative_keywords:
        negative_keywords = ["slow service", "cleanliness issues"]

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

    print("PROMPT SENT TO GROQ:")
    print(prompt)

    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.4,
            max_tokens=220,
        )
        summary = response.choices[0].message.content.strip()

        print("GROQ RESPONSE:")
        print(summary)

        return jsonify({"summary": summary, "model": "llama-3.1-8b-instant"})
    except Exception as e:
        return jsonify({"error": str(e), "summary": None}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

