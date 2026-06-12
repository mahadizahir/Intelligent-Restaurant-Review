import 'dart:io';

String getSentimentApiUrl() {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:5000/predict';
  }
  return 'http://127.0.0.1:5000/predict';
}
