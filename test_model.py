import argparse
import os
import sys
import numpy as np
import pandas as pd
import joblib
from sklearn.metrics import accuracy_score


def load_model_and_vectorizer(model_path="sentiment_model.pkl", vec_path="vectorizer.pkl"):
	model = joblib.load(model_path)
	vectorizer = joblib.load(vec_path)
	return model, vectorizer


def load_dataset(input_path=None):
	if input_path:
		if not os.path.exists(input_path):
			raise FileNotFoundError(f"Input file not found: {input_path}")
		df = pd.read_csv(input_path)
		if "review_text" in df.columns and "text" not in df.columns:
			df = df.rename(columns={"review_text": "text"})
		return df

	df1 = pd.read_csv("cleaned_reviews.csv")
	df1 = df1.rename(columns={"review_text": "text"})
	df2 = pd.read_csv("restaurantdatasetenglish_clean.csv")
	df = pd.concat([df1, df2], ignore_index=True)
	return df


def prepare_xy(df):
	if "text" not in df.columns or "label" not in df.columns:
		raise ValueError("Dataset must contain 'text' and 'label' columns")
	df = df.dropna(subset=["text", "label"]).copy()
	if "neutral" in df["label"].unique():
		df = df[df["label"] != "neutral"]
	X = df["text"]
	y = df["label"]
	return X, y


def predict_single(model, vectorizer, text):
	X_vec = vectorizer.transform([text])
	pred = model.predict(X_vec)[0]
	prob = None
	classes = list(getattr(model, "classes_", []))
	# Try predict_proba
	if hasattr(model, "predict_proba"):
		try:
			probs = model.predict_proba(X_vec)[0]
			if classes:
				prob = probs[classes.index(pred)]
			else:
				# assume binary: take max
				prob = float(max(probs))
		except Exception:
			prob = None
	elif hasattr(model, "decision_function"):
		try:
			scores = model.decision_function(X_vec)
			if isinstance(scores, np.ndarray) and scores.ndim == 1:
				# binary classifier, convert via sigmoid
				score = float(scores[0])
				prob_pos = 1 / (1 + np.exp(-score))
				if classes and len(classes) == 2:
					# assign based on which class is considered positive
					if classes[1] == pred:
						prob = prob_pos
					else:
						prob = 1 - prob_pos
				else:
					prob = prob_pos
			else:
				# multiclass: softmax
				arr = np.asarray(scores)
				ex = np.exp(arr - np.max(arr, axis=1, keepdims=True))
				probs = ex / ex.sum(axis=1, keepdims=True)
				if classes:
					prob = float(probs[0, classes.index(pred)])
				else:
					prob = float(np.max(probs))
		except Exception:
			prob = None

	return pred, prob


def main():
	parser = argparse.ArgumentParser(description="Test sentiment model or classify a single review interactively")
	parser.add_argument("--input", "-i", help="Path to input CSV file for batch evaluation (optional)")
	parser.add_argument("--model", default="sentiment_model.pkl", help="Path to trained model file")
	parser.add_argument("--vectorizer", default="vectorizer.pkl", help="Path to vectorizer file")
	parser.add_argument("--interactive", action="store_true", help="Enter interactive single-review mode")
	args = parser.parse_args()

	model, vectorizer = load_model_and_vectorizer(args.model, args.vectorizer)

	# If no input file provided, default to interactive mode
	if not args.input:
		args.interactive = True

	if args.interactive:
		try:
			review = input("Please enter review: ")
		except KeyboardInterrupt:
			print("\nAborted.")
			sys.exit(0)
		pred, prob = predict_single(model, vectorizer, review)
		if prob is not None:
			print(f"Prediction: {pred} ({prob*100:.1f}%)")
		else:
			print(f"Prediction: {pred}")
		return

	# Batch evaluation (default)
	df = load_dataset(args.input)
	X, y = prepare_xy(df)
	X_vectorized = vectorizer.transform(X)
	y_pred = model.predict(X_vectorized)
	accuracy = accuracy_score(y, y_pred)
	print("Test Accuracy:", accuracy)


if __name__ == "__main__":
	main()