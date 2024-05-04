import 'dart:async';

import 'model/command.dart';
import 'model/reply.dart';
import 'model/transport_interface.dart';

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

  @override
  Future<void> connect(String url) async {
    if (_isConnected) return;
    await _sleep();
    _timer = Timer.periodic(const Duration(seconds: 25), (timer) {});
  }

  @override
  Future<void> send(SpinifyCommand command) async {
    if (!_isConnected) throw StateError('Not connected');
    await _sleep();
    if (command is SpinifyPingRequest)
      Timer(
        Duration(milliseconds: _delay),
        () {
          if (_isConnected)
            _handler?.call(
              SpinifyPingResult(
                id: command.id,
                timestamp: DateTime.now(),
              ),
            );
        },
      );
  }

  @override
  set onReply(void Function(SpinifyReply reply) handler) => _handler = handler;
  void Function(SpinifyReply reply)? _handler;

  @override
  Future<void> disconnect(int code, String reason) async {
    if (!_isConnected) return;
    await _sleep();
    _timer?.cancel();
    _timer = null;
  }
}
