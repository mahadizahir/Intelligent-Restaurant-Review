import pickle

with open("sentiment_model.pkl", "rb") as file:
    model = pickle.load(file)

with open("vectorizer.pkl", "rb") as file:
    vectorizer = pickle.load(file)

negative_words = [
    "basi", "expired", "busuk", "tak sedap", "tidak sedap",
    "lambat", "mahal", "kotor", "teruk", "sejuk",
    "bad", "slow", "dirty", "expensive", "cold",
    "worst", "terrible", "disappointing"
]

review = input("Enter your restaurant review: ")
review_lower = review.lower()

if any(word in review_lower for word in negative_words):
    prediction = "negative"
else:
    review_vector = vectorizer.transform([review])
    prediction = model.predict(review_vector)[0]

print("Predicted Sentiment:", prediction)