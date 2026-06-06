from flask import Flask, request, jsonify
import joblib
import os

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(BASE_DIR, "sentiment_model.pkl")
VECTORIZER_PATH = os.path.join(BASE_DIR, "vectorizer.pkl")

model = joblib.load(MODEL_PATH)
vectorizer = joblib.load(VECTORIZER_PATH)

@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "message": "Sentiment API is running",
        "status": "ok"
    })

@app.route("/predict", methods=["POST"])
def predict_sentiment():
    data = request.get_json()

    if not data or "review" not in data:
        return jsonify({
            "error": "Missing 'review' field"
        }), 400

    review = data["review"]

    review_vector = vectorizer.transform([review])
    prediction = model.predict(review_vector)[0]

    return jsonify({
        "review": review,
        "sentiment": prediction
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)