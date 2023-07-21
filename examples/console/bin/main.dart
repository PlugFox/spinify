// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io' as io show exit, Platform;

import 'package:args/args.dart' show ArgParser;
import 'package:centrifuge_dart/centrifuge.dart';

void main([List<String>? args]) => runZonedGuarded<void>(() async {
      final token = _getToken(args ?? const <String>[]);
      final client = Centrifuge(
        CentrifugeConfig(
          client: (
            name: 'Centrifuge Console Example',
            version: '0.0.1',
          ),
        ),
      );
      await client
          .connect('ws://localhost:8000/connection/websocket?format=protobuf');

      // TODO(plugfox): Read from stdin and send to channel.

      // Close client after 5 seconds.
      Timer(
        const Duration(seconds: 5),
        () async {
          await client.close();
          await Future<void>.delayed(const Duration(seconds: 1));
          io.exit(0);
        },
      );
    }, (error, stackTrace) {
      print('Error: $error');
      print('Stacktrace: $stackTrace');
      io.exit(1);
    });

String _getToken(List<String> args) {
  final result = (ArgParser()
        ..addOption('token', abbr: 't', help: 'Token to use.'))
      .parse(args);
  final token = result['token']?.toString() ??
      io.Platform.environment['CENTRIFUGE_JWT_TOKEN'];
  if (token == null || token.isEmpty || token.split('.').length != 3) {
    print('Please provide a valid JWT token as argument with --token option '
        'or '
        'CENTRIFUGE_JWT_TOKEN environment variable.');
    io.exit(1);
  }
  return token;
}
