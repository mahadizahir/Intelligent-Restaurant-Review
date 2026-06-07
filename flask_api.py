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
        "message": "Sentiment API is running",
        "status": "ok"
    })

@app.route("/predict", methods=["POST"])
def predict_sentiment():
    data = request.get_json()

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

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)