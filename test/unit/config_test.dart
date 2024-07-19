import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  group('Config', () {
    test('Create', () {
      expect(SpinifyConfig.new, returnsNormally);
      expect(SpinifyConfig.byDefault, returnsNormally);
      expect(SpinifyConfig(), isA<SpinifyConfig>());
      expect(SpinifyConfig().toString(), equals('SpinifyConfig{}'));
    });

    test('Fields', () {
      final logBuffer = SpinifyLogBuffer(size: 10);
      Future<ISpinifyTransport> transportBuilder({
        required String url,
        required SpinifyConfig config,
        required SpinifyMetrics metrics,
        required Future<void> Function(SpinifyReply reply) onReply,
        required Future<void> Function() onDisconnect,
      }) =>
          throw UnimplementedError();

      final config = SpinifyConfig(
        getToken: () => Future<String>.value('<token>'),
        getPayload: () => Future<List<int>>.value([1, 2, 3]),
        connectionRetryInterval: (
          min: const Duration(seconds: 1),
          max: const Duration(seconds: 2),
        ),
        client: (
          name: 'name',
          version: 'version',
        ),
        timeout: const Duration(seconds: 15),
        serverPingDelay: const Duration(seconds: 8),
        headers: const {'key': 'value'},
        logger: logBuffer.add,
        transportBuilder: transportBuilder,
      );
      expectLater(config.getToken?.call(), completion('<token>'));
      expectLater(config.getPayload?.call(), completion([1, 2, 3]));
      expect(config.connectionRetryInterval.min,
          equals(const Duration(seconds: 1)));
      expect(config.connectionRetryInterval.max,
          equals(const Duration(seconds: 2)));
      expect(config.client.name, equals('name'));
      expect(config.client.version, equals('version'));
      expect(config.timeout, equals(const Duration(seconds: 15)));
      expect(config.serverPingDelay, equals(const Duration(seconds: 8)));
      expect(config.headers, equals(const {'key': 'value'}));
      expect(config.logger, equals(logBuffer.add));
      expect(config.transportBuilder, equals(transportBuilder));
    });
  });
}
