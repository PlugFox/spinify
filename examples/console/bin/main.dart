// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io' as io show exit, Platform;

import 'package:args/args.dart' show ArgParser;
import 'package:centrifuge_dart/centrifuge.dart';

void main([List<String>? args]) {
  final options = _extractOptions(args ?? const <String>[]);
  runZonedGuarded<void>(
    () async {
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

      await Future<void>.delayed(const Duration(seconds: 3));

      // TODO(plugfox): Read from stdin and send to channel.

      /* // Close client
      Timer(
        const Duration(seconds: 240),
        () async {
          await client.close();
          await Future<void>.delayed(const Duration(seconds: 1));
          io.exit(0);
        },
      ); */
    },
    (error, stackTrace) {
      print('Critical error: $error');
      io.exit(1);
    },
    zoneValues: {
      #dev.plugfox.centrifuge.log: options.verbose,
    },
  );
}

({String token, bool verbose}) _extractOptions(List<String> args) {
  final result = (ArgParser()
        ..addOption(
          'token',
          abbr: 't',
          help: 'Token to use.',
        )
        ..addFlag(
          'verbose',
          abbr: 'v',
          help: 'Verbose mode.',
          defaultsTo: false,
        ))
      .parse(args);
  final token = result['token']?.toString() ??
      io.Platform.environment['CENTRIFUGE_JWT_TOKEN'];
  if (token == null || token.isEmpty || token.split('.').length != 3) {
    print('Please provide a valid JWT token as argument with --token option '
        'or '
        'CENTRIFUGE_JWT_TOKEN environment variable.');
    io.exit(1);
  }
  return (
    token: token,
    verbose: result['verbose'] == true,
  );
}
