import pickle

# Load trained model
with open("sentiment_model.pkl", "rb") as file:
    model = pickle.load(file)

# Load vectorizer
with open("vectorizer.pkl", "rb") as file:
    vectorizer = pickle.load(file)

# User input
review = input("Enter your restaurant review: ")

# Convert text into vector
review_vector = vectorizer.transform([review])

# Predict probabilities
probabilities = model.predict_proba(review_vector)[0]

# Get class labels
classes = model.classes_

# Highest confidence
max_probability = max(probabilities)

# Predicted class index
predicted_index = probabilities.argmax()

# Predicted sentiment
model_prediction = classes[predicted_index]

# Low confidence = neutral
if max_probability < 0.70:
    prediction = "neutral"
    source = "low confidence fallback"

else:
    prediction = model_prediction
    source = "machine learning model"

print("Predicted Sentiment:", prediction)
print("Confidence:", round(max_probability * 100, 2), "%")
print("Probabilities:", probabilities)
print("Source:", source)