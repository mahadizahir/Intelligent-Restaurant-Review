import 'dart:io';

String getApiBaseUrl() {
  if (Platform.isAndroid) {
    // Android emulator uses 10.0.2.2 to reach your Windows localhost.
    return 'http://10.0.2.2:5000';
  }

  // Windows desktop / Chrome / iOS simulator on same PC.
  return 'http://127.0.0.1:5000';
}

String getSentimentApiUrl() => '${getApiBaseUrl()}/predict';
