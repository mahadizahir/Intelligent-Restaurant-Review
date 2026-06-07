TODO

## Plan confirmation
- [ ] Read repo files relevant to sentiment pipeline.
- [ ] Produce/confirm comprehensive edit plan for what the user ultimately wants.

## Sentiment pipeline checks (current code)
- [ ] Verify how `cleaned_reviews.csv` is generated and what label schema is used.
- [ ] Ensure model/vectorizer files are trained with consistent parameters.
- [ ] Verify API endpoint input/output matches Flutter client expectations.

## Tests
- [ ] Run `python train_model.py` to regenerate `sentiment_model.pkl` and `vectorizer.pkl`.
- [ ] Run `python test_model.py` with a sample review to sanity check predictions.
- [ ] Start Flask server and test `/predict` with curl/postman.

## Flutter integration
- [ ] Verify `lib/main.dart`, `lib/db_connect.py`, `lib/data/app_state.dart` correctly call Flask API.
- [ ] Ensure prediction label mapping (positive/negative) is consistent end-to-end.

