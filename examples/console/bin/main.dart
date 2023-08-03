// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io' as io show exit, Platform;

import 'package:args/args.dart' show ArgParser;
import 'package:spinify/spinify.dart';

const url = 'ws://localhost:8000/connection/websocket?format=protobuf';

void main([List<String>? args]) {
  final options = _extractOptions(args ?? const <String>[]);
  runZonedGuarded<void>(
    () async {
      // Create Spinify client.
      final client = Spinify(
        SpinifyConfig(
          client: (
            name: 'Spinify Console Example',
            version: '0.0.1',
          ),
          getToken: () =>
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkYXJ0IiwiZXhwIj'
              'oyMjk0OTE1MTMyLCJpYXQiOjE2OTAxMTUxMzJ9.hIGDXKn-eMdsdj57wn6-4y5p'
              'k0tZcKoJCu0qxuuWSoQ',
        ),
      );

      // Connect to centrifuge server using provided URL.
      await client.connect(url);

      // Output current client state.
      print('Current state after connect: ${client.state}');

      // State changes.
      // Or you can observe specific state changes.
      // e.g. `client.states.connected`
      client.states.listen((state) => print('State changed to: $state'));

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
      #dev.plugfox.spinify.log: options.verbose,
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
      io.Platform.environment['SPINIFY_JWT_TOKEN'];
  if (token == null || token.isEmpty || token.split('.').length != 3) {
    print('Please provide a valid JWT token as argument with --token option '
        'or '
        'SPINIFY_JWT_TOKEN environment variable.');
    io.exit(1);
  }
  return (
    token: token,
    verbose: result['verbose'] == true,
  );
}
