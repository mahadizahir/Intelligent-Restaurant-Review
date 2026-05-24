import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression

# Load and prepare dataset
df = pd.read_csv("cleaned_reviews.csv")
df = df.dropna(subset=["review_text", "label"])

df = df[df["label"] != "neutral"]

X = df["review_text"]
y = df["label"]

# Split dataset
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# Train vectorizer and model
vectorizer = TfidfVectorizer(max_features=5000)
X_train_vectorized = vectorizer.fit_transform(X_train)

model = LogisticRegression(max_iter=1000, class_weight='balanced')
model.fit(X_train_vectorized, y_train)

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