- [x] Inspect keyword extraction + Groq summary pipeline in Flutter and Flask.
- [x] Add required debug logging (total/pos/neg + extracted positive/negative keywords) in Flutter.
- [x] Normalize sentiment casing using `trim().toUpperCase()` before counting/extracting.
- [x] Guarantee `positiveKeywords`/`negativeKeywords` are never empty before sending to Flask (fallback keywords used when extraction is empty).
- [x] Update Flask prompt wiring to avoid dash placeholders when keywords are unexpectedly empty.
- [ ] Run the app, open Owner Dashboard → Analytics/AISummary, and verify console logs and that keywords no longer display as “—”.

