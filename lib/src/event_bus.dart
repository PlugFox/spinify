import 'dart:async';
import 'dart:collection';

//import 'dart:developer' as dev;

import 'package:meta/meta.dart';

import 'logger.dart' as log;
import 'spinify_interface.dart';

/// SpinifyBus Singleton class
/// That class is used to manage the event queue and work as a singleton
/// event bus to process, dispatch and manage all the events
/// in the Spinify clients.
@internal
@immutable
final class SpinifyEventBus {
  SpinifyEventBus._internal();
  static final SpinifyEventBus _internalSingleton = SpinifyEventBus._internal();

  /// Get the instance of the SpinifyEventBus
  static SpinifyEventBus get instance => _internalSingleton;

  /// Error when client not found
  static Never _clientNotFound(int clientId) =>
      throw StateError('Client $clientId not found');

  /// The buckets of the clients
  final Expando<SpinifyEventBus$Bucket> _buckets =
      Expando<SpinifyEventBus$Bucket>('SpinifyEventBus');

  /// Register a new client to the SpinifyBus
  SpinifyEventBus$Bucket registerClient(ISpinify client) =>
      _buckets[client] = SpinifyEventBus$Bucket(client);

  /// Unregister a client from the SpinifyBus
  void unregisterClient(ISpinify client) {
    _buckets[client]?.dispose();
    _buckets[client] = null;
  }

  /// Get the bucket for the client
  SpinifyEventBus$Bucket getBucket(ISpinify client) =>
      _buckets[client] ?? _clientNotFound(client.id);

  @override
  int get hashCode => 0;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => 'SpinifyEventBus{}';
}

/// SpinifyEventBus$Event class
@immutable
final class _SpinifyEventBus$Task {
  /// Create a new SpinifyEventBus$Event
  const _SpinifyEventBus$Task(this.completer, this.event, this.data);

  /// The completer
  final Completer<void> completer;

  /// The event name
  final String event;

  /// The event data
  final Object? data;
}

/// SpinifyEventBus$Bucket class
final class SpinifyEventBus$Bucket {
  /// Create a new SpinifyEventBus$Bucket
  SpinifyEventBus$Bucket(ISpinify client, {String? debugLabel})
      : _clientWR = WeakReference<ISpinify>(client),
        _debugLabel = debugLabel ?? '[Spinify#${client.id}]';

  final String _debugLabel;

  /// The client weak reference
  final WeakReference<ISpinify> _clientWR;

  /// The current client instance
  ISpinify? get client => _clientWR.target;

  /// The tasks queue, mutex of the events
  final Queue<_SpinifyEventBus$Task> _queue = Queue<_SpinifyEventBus$Task>();
  final Map<String, List<Future<void> Function(Object?)>> _subscribers =
      <String, List<Future<void> Function(Object?)>>{};

  /// Push an event to the client
  Future<void> pushEvent(String event, [Object? data]) async {
    final completer = Completer<void>.sync();
    _queue.add(_SpinifyEventBus$Task(completer, event, data));
    log.fine('$_debugLabel Pushing event $event');
    if (!_processing) scheduleMicrotask(_processEvents);
    return completer.future;
  }

  /// Subscribe to an event
  void subscribe(String event, Future<void> Function(Object? data) callback) {
    _subscribers
        .putIfAbsent(event, () => <Future<void> Function(Object?)>[])
        .add(callback);
  }

  /// Unsubscribe from an event
  void unsubscribe(String event, Future<void> Function() callback) {
    final subs = _subscribers[event];
    if (subs == null) return;
    subs.remove(callback);
  }

  bool _processing = false;
  Future<void> _processEvents() async {
    if (_processing) return;
    _processing = true;
    //dev.Timeline.instantSync('$_debugLabel _processEvents() start');
    log.fine('$_debugLabel start processing events');
    while (_queue.isNotEmpty) {
      var task = _queue.removeFirst();
      final event = task.event;
      try {
        await _notifySubscribers(event, task.data);
        task.completer.complete(null);
        //dev.Timeline.instantSync('$_debugLabel $event');
        log.fine('$_debugLabel $event');
      } on Object catch (error, stackTrace) {
        final reason = '$_debugLabel $event error';
        //dev.Timeline.instantSync(reason);
        log.warning(error, stackTrace, reason);
        task.completer.completeError(error, stackTrace);
      }
    }
    _processing = false;
    log.fine('$_debugLabel end processing events');
    //dev.Timeline.instantSync('$_debugLabel _processEvents() end');
  }

  /// Notify the subscribers
  Future<void> _notifySubscribers(String event, Object? data) async {
    final subs = _subscribers[event];
    if (subs == null) return;
    for (final sub in subs) await sub(data);
  }

  /// Dispose the bucket
  @protected
  @visibleForTesting
  void dispose() {
    _subscribers.clear();
    final error = StateError('$_debugLabel client closed');
    for (final task in _queue) task.completer.completeError(error);
    _queue.clear();
  }
}
