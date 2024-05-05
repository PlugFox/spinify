import 'dart:async';

import 'package:fixnum/fixnum.dart';

import 'model/command.dart';
import 'model/reply.dart';
import 'model/transport_interface.dart';

/// Create a fake Spinify transport.
Future<ISpinifyTransport> $createFakeSpinifyTransport(
  String url,
  Map<String, String> headers,
) async {
  final transport = SpinifyTransportFake();
  await transport._connect(url);
  return transport;
}

/// Spinify fake transport
class SpinifyTransportFake implements ISpinifyTransport {
  /// Create a fake transport.
  SpinifyTransportFake({
    // Delay in milliseconds
    int delay = 10,
  }) : _delay = delay;

  final int _delay;

  Future<void> _sleep() => Future<void>.delayed(Duration(milliseconds: _delay));

  bool get _isConnected => _timer != null;
  Timer? _timer;

  Future<void> _connect(String url) async {
    if (_isConnected) return;
    await _sleep();
    _timer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (!_isConnected) timer.cancel();
      _response((now) => SpinifyPingResult(id: 0, timestamp: now));
    });
  }

  @override
  Future<void> send(SpinifyCommand command) async {
    if (!_isConnected) throw StateError('Not connected');
    await _sleep();
    switch (command) {
      case SpinifyPingRequest(:int id):
        _response((now) => SpinifyPingResult(id: id, timestamp: now));
      case SpinifyConnectRequest(:int id):
        _response((now) => SpinifyConnectResult(
              id: id,
              timestamp: now,
              client: 'fake',
              version: '0.0.1',
              expires: false,
              ttl: null,
              data: null,
              subs: null,
              pingInterval: const Duration(seconds: 25),
              sendPong: false,
              session: 'fake',
              node: 'fake',
            ));
      case SpinifySubscribeRequest(:int id):
        _response((now) => SpinifySubscribeResult(
              id: id,
              timestamp: now,
              data: null,
              expires: false,
              ttl: null,
              positioned: false,
              publications: const [],
              recoverable: false,
              recovered: false,
              since: (epoch: '...', offset: Int64.ZERO),
              wasRecovering: false,
            ));
      case SpinifyUnsubscribeRequest(:int id):
        _response((now) => SpinifyUnsubscribeResult(id: id, timestamp: now));
      case SpinifyPublishRequest(:int id):
        _response((now) => SpinifyPublishResult(id: id, timestamp: now));
      case SpinifyPresenceRequest(:int id):
        _response((now) => SpinifyPresenceResult(
              id: id,
              timestamp: now,
              presence: const {},
            ));
      case SpinifyPresenceStatsRequest(:int id):
        _response((now) => SpinifyPresenceStatsResult(
            id: id, timestamp: now, numClients: 0, numUsers: 0));
      case SpinifyHistoryRequest(:int id):
        _response((now) => SpinifyHistoryResult(
              id: id,
              timestamp: now,
              since: (epoch: '...', offset: Int64.ZERO),
            ));
      case SpinifyRPCRequest(:int id):
        _response(
            (now) => SpinifyRPCResult(id: id, timestamp: now, data: const []));
      case SpinifyRefreshRequest(:int id):
        _response((now) => SpinifyRefreshResult(
              id: id,
              timestamp: now,
              client: 'fake',
              version: '0.0.1',
              expires: false,
              ttl: null,
            ));
      case SpinifySubRefreshRequest(:int id):
        _response((now) => SpinifySubRefreshResult(id: id, timestamp: now));
      case SpinifySendRequest():
      // Asynchronously send a message to the server
    }
  }

  void _response(SpinifyReply Function(DateTime now) reply) => Timer(
        Duration(milliseconds: _delay),
        () {
          if (!_isConnected) return;
          _onReply?.call(reply(DateTime.now()));
        },
      );

  @override
  // ignore: avoid_setters_without_getters
  set onReply(void Function(SpinifyReply reply) handler) => _onReply = handler;
  void Function(SpinifyReply reply)? _onReply;

  @override
  // ignore: avoid_setters_without_getters
  set onDisconnect(void Function() handler) => _onDisconnect = handler;
  void Function()? _onDisconnect;

  @override
  Future<void> disconnect([int? code, String? reason]) async {
    if (!_isConnected) return;
    await _sleep();
    _onDisconnect?.call();
    _timer?.cancel();
    _timer = null;
  }
}
