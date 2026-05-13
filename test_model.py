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

# Predict sentiment
prediction = model.predict(review_vector)

# Show result
print("Predicted Sentiment:", prediction[0])