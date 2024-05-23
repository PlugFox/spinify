import 'dart:async';
import 'dart:io' as io;

/// Exit the server.
void main() => io.HttpClient()
    .getUrl(Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: 8000,
      path: 'exit',
    ))
    .then<io.HttpClientResponse>((request) => request.close())
    .timeout(const Duration(seconds: 15))
    .then((response) => response.statusCode == 200)
    .onError((error, stackTrace) => false)
    .whenComplete(() => io.exit(0));
