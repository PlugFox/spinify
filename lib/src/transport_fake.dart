// ignore_for_file: avoid_setters_without_getters
// coverage:ignore-file

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fixnum/fixnum.dart';

import 'model/channel_event.dart';
import 'model/command.dart';
import 'model/metric.dart';
import 'model/reply.dart';
import 'model/transport_interface.dart';

/// Create a fake Spinify transport.
SpinifyTransportBuilder $createFakeSpinifyTransport({
  SpinifyReply? Function(SpinifyCommand command)? overrideCommand,
  void Function(ISpinifyTransport? transport)? out,
}) =>
    ({
      /// URL for the connection
      required url,

      /// Spinify client configuration
      required config,

      /// Metrics
      required metrics,

      /// Callback for reply messages
      required Future<void> Function(SpinifyReply reply) onReply,

      /// Callback for disconnect event
      required Future<void> Function({required bool temporary}) onDisconnect,
    }) async {
      final transport = SpinifyTransportFake(
        overrideCommand: overrideCommand,
      )
        ..metrics = metrics
        ..onReply = onReply
        ..onDisconnect = ({required temporary}) {
          out?.call(null);
          return onDisconnect(temporary: temporary);
        };
      await transport._connect(url);
      out?.call(transport);
      return transport;
    };

/// Spinify fake transport
class SpinifyTransportFake implements ISpinifyTransport {
  /// Create a fake transport.
  SpinifyTransportFake({
    // Delay in milliseconds
    this.delay = 10,
    SpinifyReply? Function(SpinifyCommand command)? overrideCommand,
  })  : _random = math.Random(),
        _overrideCommand = overrideCommand;

  final SpinifyReply? Function(SpinifyCommand command)? _overrideCommand;

  /// Delay in milliseconds in the fake transport to simulate network latency.
  int delay;
  final math.Random _random;

  Future<void> _sleep() => Future<void>.delayed(
      Duration(milliseconds: _random.nextInt(delay ~/ 2) + delay ~/ 2));

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
    metrics
      ..bytesSent += 1
      ..messagesSent += 1;
    await _sleep();
    if (_overrideCommand != null) {
      final reply = _overrideCommand.call(command);
      if (reply != null) _onReply?.call(reply).ignore();
      return;
    }
    switch (command) {
      case SpinifyPingRequest(:int id):
        _response(
          (now) => SpinifyPingResult(
            id: id,
            timestamp: now,
          ),
        );
      case SpinifyConnectRequest(:int id):
        _response(
          (now) => SpinifyConnectResult(
            id: id,
            timestamp: now,
            client: 'fake',
            version: '0.0.1',
            expires: false,
            ttl: null,
            data: null,
            subs: <String, SpinifySubscribeResult>{
              'notification:index': SpinifySubscribeResult(
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
              ),
            },
            pingInterval: const Duration(seconds: 25),
            sendPong: false,
            session: 'fake',
            node: 'fake',
          ),
        );
      case SpinifySubscribeRequest(:int id):
        _response(
          (now) => SpinifySubscribeResult(
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
          ),
        );
      case SpinifyUnsubscribeRequest(:int id):
        _response(
          (now) => SpinifyUnsubscribeResult(
            id: id,
            timestamp: now,
          ),
        );
      case SpinifyPublishRequest(:int id):
        _response(
          (now) => SpinifyPublishResult(
            id: id,
            timestamp: now,
          ),
        );
      case SpinifyPresenceRequest(:int id):
        _response(
          (now) => SpinifyPresenceResult(
            id: id,
            timestamp: now,
            presence: const {},
          ),
        );
      case SpinifyPresenceStatsRequest(:int id):
        _response(
          (now) => SpinifyPresenceStatsResult(
            id: id,
            timestamp: now,
            numClients: 0,
            numUsers: 0,
          ),
        );
      case SpinifyHistoryRequest(:int id):
        _response(
          (now) => SpinifyHistoryResult(
            id: id,
            timestamp: now,
            since: (epoch: '...', offset: Int64.ZERO),
            publications: const <SpinifyPublication>[],
          ),
        );
      case SpinifyRPCRequest(:int id, :String method, :List<int> data):
        _response(
          (now) => SpinifyRPCResult(
            id: id,
            timestamp: now,
            data: switch (method) {
              'getCurrentYear' =>
                utf8.encode('{"year": ${DateTime.now().year}}'),
              'echo' => data,
              _ => throw ArgumentError('Unknown method: $method'),
            },
          ),
        );
      case SpinifyRefreshRequest(:int id):
        _response(
          (now) => SpinifyRefreshResult(
            id: id,
            timestamp: now,
            client: 'fake',
            version: '0.0.1',
            expires: false,
            ttl: null,
          ),
        );
      case SpinifySubRefreshRequest(:int id):
        _response(
          (now) => SpinifySubRefreshResult(
            id: id,
            timestamp: now,
            expires: false,
            ttl: null,
          ),
        );
      case SpinifySendRequest():
      // Asynchronously send a message to the server
    }
  }

  void _response(SpinifyReply Function(DateTime now) reply) => Timer(
        Duration(milliseconds: delay),
        () {
          if (!_isConnected) return;
          metrics
            ..bytesReceived += 1
            ..messagesReceived += 1;
          _onReply?.call(reply(DateTime.now())).ignore();
        },
      );

  /// Metrics
  late SpinifyMetrics$Mutable metrics;

  /// Callback for reply messages
  set onReply(Future<void> Function(SpinifyReply reply) handler) =>
      _onReply = handler;
  Future<void> Function(SpinifyReply reply)? _onReply;

  /// Callback for disconnect event
  set onDisconnect(Future<void> Function({required bool temporary}) handler) =>
      _onDisconnect = handler;
  Future<void> Function({required bool temporary})? _onDisconnect;

  @override
  Future<void> disconnect([int? code, String? reason]) async {
    if (!_isConnected) return;
    await _sleep();
    int? closeCode;
    String? closeReason;
    var reconnect = true;
    if (code case int value when value > 0) {
      switch (value) {
        case 1009:
          // reconnect is true by default
          closeCode = 3; // disconnectCodeMessageSizeLimit;
          closeReason = 'message size limit exceeded';
          reconnect = true;
        case < 3000:
          // We expose codes defined by Centrifuge protocol,
          // hiding details about transport-specific error codes.
          // We may have extra optional transportCode field in the future.
          // reconnect is true by default
          closeCode = 1; // connectingCodeTransportClosed;
          closeReason = reason;
          reconnect = true;
        case >= 3000 && <= 3499:
          // reconnect is true by default
          closeCode = value;
          closeReason = reason;
          reconnect = true;
        case >= 3500 && <= 3999:
          // application terminal codes
          closeCode = value;
          closeReason = reason ?? 'application terminal code';
          reconnect = false;
        case >= 4000 && <= 4499:
          // custom disconnect codes
          // reconnect is true by default
          closeCode = value;
          closeReason = reason;
          reconnect = true;
        case >= 4500 && <= 4999:
          // custom disconnect codes
          // application terminal codes
          closeCode = value;
          closeReason = reason ?? 'application terminal code';
          reconnect = false;
        case >= 5000:
          // reconnect is true by default
          closeCode = value;
          closeReason = reason;
          reconnect = true;
        default:
          closeCode = value;
          closeReason = reason;
          reconnect = false;
      }
    }
    closeCode ??= 1; // connectingCodeTransportClosed
    closeReason ??= 'transport closed';
    await _onDisconnect?.call(temporary: reconnect);
    _timer?.cancel();
    _timer = null;
  }
}
