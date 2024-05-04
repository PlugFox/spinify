import 'dart:async';
import 'dart:collection';

//import 'dart:developer' as dev;

import 'package:meta/meta.dart';

import 'logger.dart' as log;
import 'model/spinify_interface.dart';

/// SpinifyBus Singleton class
/// That class is used to manage the event queue and work as a singleton
/// event bus to process, dispatch and manage all the events
/// in the Spinify clients.
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
  final Expando<ISpinifyEventBus$Bucket> _buckets =
      Expando<ISpinifyEventBus$Bucket>('SpinifyEventBus');

  /// Register a new client to the SpinifyBus
  ISpinifyEventBus$Bucket registerClient(ISpinify client) =>
      _buckets[client] = SpinifyEventBus$Bucket$QueueImpl(client);

  /// Unregister a client from the SpinifyBus
  void unregisterClient(ISpinify client) {
    _buckets[client]?.dispose();
    _buckets[client] = null;
  }

  /// Get the bucket for the client
  ISpinifyEventBus$Bucket getBucket(ISpinify client) =>
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

/// SpinifyEventBus$Bucket interface
abstract interface class ISpinifyEventBus$Bucket {
  /// The current client instance
  abstract final ISpinify? client;

  /// Push an event to the client
  Future<void> push(Enum event, [Object? data]);

  /// Push an event to the client with priority
  Future<void> pushPriority(Enum event, [Object? data]);

  /// Subscribe to an event
  void subscribe(Enum event, Future<void> Function(Object? data) callback);

  /// Unsubscribe from an event
  void unsubscribe(Enum event, Future<void> Function() callback);

  /// Dispose the bucket
  /// Do not use it directly
  @internal
  @visibleForTesting
  void dispose();
}

/// SpinifyEventBus$Bucket$QueueImpl class
final class SpinifyEventBus$Bucket$QueueImpl
    implements ISpinifyEventBus$Bucket {
  /// Create a new SpinifyEventBus$Bucket
  SpinifyEventBus$Bucket$QueueImpl(ISpinify client, {String? debugLabel})
      : _clientWR = WeakReference<ISpinify>(client),
        _debugLabel = debugLabel ?? '[Spinify#${client.id}]';

  final String _debugLabel;

  /// The client weak reference
  final WeakReference<ISpinify> _clientWR;

  @override
  ISpinify? get client => _clientWR.target;

  /// The subscribers of the events
  final Map<String, List<Future<void> Function(Object?)>> _subscribers =
      <String, List<Future<void> Function(Object?)>>{};

  /// The tasks queue, mutex of the events
  final Queue<_SpinifyEventBus$Task> _events = Queue<_SpinifyEventBus$Task>();

  /// The priority queue, mutex of the events
  final Queue<_SpinifyEventBus$Task> _priority = Queue<_SpinifyEventBus$Task>();

  @override
  Future<void> push(Enum event, [Object? data]) async {
    final completer = Completer<void>.sync();
    _events.add(_SpinifyEventBus$Task(completer, event.name, data));
    log.fine('$_debugLabel pushing event $event');
    if (!_processing) scheduleMicrotask(_processTasks);
    return completer.future;
  }

  @override
  Future<void> pushPriority(Enum event, [Object? data]) {
    final completer = Completer<void>.sync();
    _priority.add(_SpinifyEventBus$Task(completer, event.name, data));
    log.fine('$_debugLabel pushing priority event $event');
    if (!_processing) scheduleMicrotask(_processTasks);
    return completer.future;
  }

  @override
  void subscribe(Enum event, Future<void> Function(Object? data) callback) {
    _subscribers
        .putIfAbsent(event.name, () => <Future<void> Function(Object?)>[])
        .add(callback);
  }

  @override
  void unsubscribe(Enum event, Future<void> Function() callback) {
    final subs = _subscribers[event.name];
    if (subs == null) return;
    subs.remove(callback);
  }

  bool _processing = false;
  Future<void> _processTasks() async {
    if (_processing) return;
    _processing = true;
    //dev.Timeline.instantSync('$_debugLabel _processEvents() start');
    //log.fine('$_debugLabel start processing events');

    _SpinifyEventBus$Task? getNext() {
      if (_priority.isNotEmpty) return _priority.removeFirst();
      if (_events.isNotEmpty) return _events.removeFirst();
      return null;
    }

    Future<void> notifySubscribers(String event, Object? data) async {
      final subs = _subscribers[event];
      if (subs != null) for (final sub in subs) await sub(data);
    }

    while (true) {
      var task = getNext();
      if (task == null) break;
      final event = task.event;
      try {
        // Notify subscribers
        //await notifySubscribers('$event:begin', task.data);
        await notifySubscribers(event, task.data);
        //await notifySubscribers('$event:end', task.data);
        task.completer.complete();
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
    //log.fine('$_debugLabel end processing events');
    //dev.Timeline.instantSync('$_debugLabel _processEvents() end');
  }

  @override
  void dispose() {
    _subscribers.clear();
    final error = StateError('$_debugLabel client closed');
    for (final task in _events) task.completer.completeError(error);
    _events.clear();
  }
}
