import pandas as pd

from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score

# Load cleaned dataset
df = pd.read_csv("cleaned_reviews.csv")

# Remove empty rows
df = df.dropna(subset=["review_text", "label"])

df = df[df["label"] != "neutral"]

# Features and labels
X = df["review_text"]
y = df["label"]

# Split dataset
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# Convert text to numerical vectors
vectorizer = TfidfVectorizer(
    ngram_range=(1, 2),
    lowercase=True
)

X_train_vectorized = vectorizer.fit_transform(X_train)
X_test_vectorized = vectorizer.transform(X_test)

# Train model
model = LogisticRegression(
    max_iter=1000,
    class_weight='balanced'
)

model.fit(X_train_vectorized, y_train)

# Test accuracy
y_pred = model.predict(X_test_vectorized)

accuracy = accuracy_score(y_test, y_pred)

print("Model Accuracy:", accuracy)
print("Model trained successfully!")