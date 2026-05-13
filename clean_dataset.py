import pandas as pd

df = pd.read_csv("IRR-with-sentiment-score.csv")

# Use translated text first, if empty use original review_text
df["final_review"] = df["review_translated_text"].fillna(df["review_text"])

df = df[["final_review", "label"]]

df = df.dropna(subset=["final_review", "label"])
df = df.drop_duplicates()
df = df.reset_index(drop=True)

df = df.rename(columns={"final_review": "review_text"})

print(df.head())
print("Total Clean Rows:", len(df))

df.to_csv("cleaned_reviews.csv", index=False)

print("Cleaned dataset saved successfully!")