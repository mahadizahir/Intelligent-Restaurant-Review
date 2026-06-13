# TODO - Fix Flask /predict sentiment endpoint

- [ ] Implement production-ready `/predict` endpoint in `flask_api.py`:
  - [ ] Always return a valid Flask response (fix current missing return)
  - [ ] Add robust request validation + error responses
  - [ ] Add required debugging prints:
    - request body
    - review text
    - model prediction
    - confidence score
    - response returned
  - [ ] Compute confidence using `predict_proba` when available
  - [ ] Ensure stable response schema expected by frontend
- [ ] Run a quick local sanity check using curl/Postman-like payload (optional)

