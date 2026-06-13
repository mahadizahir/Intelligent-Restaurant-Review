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


from aspect_analyzer import analyze_aspects


@app.route("/predict", methods=["POST"])
def predict_sentiment():
    """Return both overall sentiment (ML) + per-aspect sentiment (rule-based).

    Expected JSON body:
      {"reviews": ["text1", "text2"]}

    Returns JSON array where each item contains:
      {
        "review": "...",
        "sentiment": "positive|negative|neutral",
        "aspects": {"food": ..., "service": ..., "price": ..., "cleanliness": ...},
        "confidence": <float|null>
      }
    """

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
        if review is None:
            return jsonify({"error": "Review item is null"}), 400
        if not isinstance(review, str):
            return jsonify({"error": "Review item must be a string"}), 400

        review = review.strip()
        if not review:
            return jsonify({"error": "Review item is empty"}), 400

        # Debug prints (needed to trace frontend/backend mismatch)
        print("[DEBUG] /predict review=", review)

        review_vector = vectorizer.transform([review])
        prediction = model.predict(review_vector)[0]
        print("[DEBUG] /predict prediction=", prediction)

        # Confidence score (best effort)
        confidence = None
        if hasattr(model, "predict_proba"):
            try:
                probs = model.predict_proba(review_vector)[0]
                classes = list(getattr(model, "classes_", []))
                print("[DEBUG] /predict probs=", probs)
                if classes and prediction in classes:
                    confidence = float(probs[classes.index(prediction)])
                else:
                    confidence = float(max(probs))
            except Exception as e:
                print("[DEBUG] /predict confidence failed=", repr(e))
                confidence = None

        aspects = analyze_aspects(review)

        results.append({
            "review": review,
            "sentiment": prediction,
            "aspects": aspects,
            "confidence": confidence,
        })

    print("[DEBUG] /predict response=", results)
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


@app.route("/groq/suggestions", methods=["POST"])
def groq_suggestions():
    """Generate structured AI suggestions (Strengths, Areas to Improve, Recommended Actions) using Groq."""
    data = request.get_json(force=True) or {}

    total_reviews = int(data.get("totalReviews", 0))
    avg_rating = float(data.get("avgRating", 0.0))
    positive_count = int(data.get("positiveCount", 0))
    negative_count = int(data.get("negativeCount", 0))
    positive_keywords = data.get("positiveKeywords", []) or []
    negative_keywords = data.get("negativeKeywords", []) or []

    if total_reviews <= 0:
        return jsonify({
            "suggestions": {
                "Strengths": ["No reviews yet. Suggestions will appear once customers submit reviews."],
                "Areas to Improve": [],
                "Recommended Actions": ["Encourage customers to leave reviews."]
            }
        })

    groq_api_key = os.getenv("GROQ_API_KEY")
    if not groq_api_key:
        return jsonify({"error": "GROQ_API_KEY missing"}), 500

    from groq import Groq
    client = Groq(api_key=groq_api_key)

    if not positive_keywords:
        positive_keywords = ["satisfied customers", "good experience"]
    if not negative_keywords:
        negative_keywords = ["mixed feedback", "some concerns"]

    positive_keywords = [str(x).strip() for x in positive_keywords if str(x).strip()]
    negative_keywords = [str(x).strip() for x in negative_keywords if str(x).strip()]

    if not positive_keywords:
        positive_keywords = ["satisfied customers"]
    if not negative_keywords:
        negative_keywords = ["mixed feedback"]

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

Important:
The keywords may contain English and Malay.

Malay meanings:
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
3. Generate 3 sections:
   - Strengths
   - Areas to Improve
   - Recommended Actions
4. Each section must contain 2-4 bullet points.
5. Recommendations must be practical and actionable for a restaurant owner.
6. Keep the response under 150 words.
7. Return plain text only.
8.Do NOT assume cultural or language barriers.
9. Do NOT invent information or make assumptions beyond the provided data.

Example format:

Strengths
• Customers frequently mention friendly service.
• Positive feedback highlights fast response times.

Areas to Improve
• Several reviews mention slow service.
• Customers report rude staff interactions.

Recommended Actions
• Conduct customer service training.
• Improve order processing workflow.
• Monitor future reviews for recurring complaints.
"""

    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.4,
            max_tokens=300,
        )
        raw = response.choices[0].message.content.strip()

        # Parse the structured response into sections
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

        # Fallback if parsing produced empty sections
        for key in sections:
            if not sections[key]:
                if key == "Strengths":
                    sections[key] = [f"Positive feedback from {positive_count} customers."]
                elif key == "Areas to Improve":
                    sections[key] = [f"{negative_count} customers noted concerns."]
                else:
                    sections[key] = ["Continue monitoring customer feedback."]

        return jsonify({"suggestions": sections})
    except Exception as e:
        return jsonify({"error": str(e), "suggestions": None}), 500
    
    


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

