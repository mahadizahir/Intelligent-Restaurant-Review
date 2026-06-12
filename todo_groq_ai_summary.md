# TODO - Groq-powered AI Summary (server-side proxy)

## Step 1: Update Flask backend
- [x] Add `/groq/summary` endpoint in `flask_api.py`
- [x] Endpoint accepts analytics payload (counts + keywords + ratings)
- [x] Uses Groq model `llama-3.1-8b-instant`
- [x] Returns JSON: `{ summary: string }`
- [x] Add error handling + CORS

## Step 2: Update Flutter Owner Dashboard UI
- [x] Replace `_AISummaryCard` to call Flask `/groq/summary`
- [x] Add loading / success / error states
- [x] Keep fallback rule-based summary when Groq fails
- [x] Empty reviews state must show: `No reviews available yet. Customer insights will appear once reviews are submitted.`

## Step 3: Verify build
- [ ] Run `flutter analyze`
- [ ] Run `flutter test` (if available)
- [ ] Manual check: owner dashboard shows loading then summary


