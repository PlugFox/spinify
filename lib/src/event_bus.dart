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
  Future<void> pushEvent(String event, [Object? data]);

  /// Subscribe to an event
  void subscribe(String event, Future<void> Function(Object? data) callback);

  /// Unsubscribe from an event
  void unsubscribe(String event, Future<void> Function() callback);

  /// Dispose the bucket
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
  final Queue<_SpinifyEventBus$Task> _queue = Queue<_SpinifyEventBus$Task>();

  @override
  Future<void> pushEvent(String event, [Object? data]) async {
    final completer = Completer<void>.sync();
    _queue.add(_SpinifyEventBus$Task(completer, event, data));
    log.fine('$_debugLabel Pushing event $event');
    if (!_processing) scheduleMicrotask(_processTasks);
    return completer.future;
  }

  @override
  void subscribe(String event, Future<void> Function(Object? data) callback) {
    _subscribers
        .putIfAbsent(event, () => <Future<void> Function(Object?)>[])
        .add(callback);
  }

  @override
  void unsubscribe(String event, Future<void> Function() callback) {
    final subs = _subscribers[event];
    if (subs == null) return;
    subs.remove(callback);
  }

  bool _processing = false;
  Future<void> _processTasks() async {
    if (_processing) return;
    _processing = true;
    //dev.Timeline.instantSync('$_debugLabel _processEvents() start');
    log.fine('$_debugLabel start processing events');
    while (_queue.isNotEmpty) {
      var task = _queue.removeFirst();
      final event = task.event;
      try {
        // Notify subscribers
        final subs = _subscribers[event];
        if (subs != null) for (final sub in subs) await sub(task.data);
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
    log.fine('$_debugLabel end processing events');
    //dev.Timeline.instantSync('$_debugLabel _processEvents() end');
  }

  @override
  void dispose() {
    _subscribers.clear();
    final error = StateError('$_debugLabel client closed');
    for (final task in _queue) task.completer.completeError(error);
    _queue.clear();
  }
}

/*
/// SpinifyEventBus$Bucket$StreamControllerImpl class
final class SpinifyEventBus$Bucket$StreamControllerImpl
    implements ISpinifyEventBus$Bucket {
  /// Create a new SpinifyEventBus$Bucket$StreamControllerImpl
  SpinifyEventBus$Bucket$StreamControllerImpl(ISpinify client,
      {String? debugLabel})
      : _clientWR = WeakReference<ISpinify>(client),
        _debugLabel = debugLabel ?? '[Spinify#${client.id}]' {
    _subscription = _controller.stream.asyncMap(_processTask).listen((_) {});
  }

  final String _debugLabel;

  /// The client weak reference
  final WeakReference<ISpinify> _clientWR;

  @override
  ISpinify? get client => _clientWR.target;

  /// The subscribers of the events
  final Map<String, List<Future<void> Function(Object?)>> _subscribers =
      <String, List<Future<void> Function(Object?)>>{};

  /// The tasks queue, mutex of the events
  final StreamController<_SpinifyEventBus$Task> _controller =
      StreamController<_SpinifyEventBus$Task>(sync: true);

  late final StreamSubscription<void> _subscription;

  @override
  Future<void> pushEvent(String event, [Object? data]) async {
    final completer = Completer<void>.sync();
    _controller.add(_SpinifyEventBus$Task(completer, event, data));
    log.fine('$_debugLabel Pushing event $event');
    return completer.future;
  }

  @override
  void subscribe(String event, Future<void> Function(Object? data) callback) {
    _subscribers
        .putIfAbsent(event, () => <Future<void> Function(Object?)>[])
        .add(callback);
  }

  @override
  void unsubscribe(String event, Future<void> Function() callback) {
    final subs = _subscribers[event];
    if (subs == null) return;
    subs.remove(callback);
  }

  Future<void> _processTask(_SpinifyEventBus$Task task) async {
    final event = task.event;
    try {
      // Notify subscribers
      final subs = _subscribers[event];
      if (subs != null) for (final sub in subs) await sub(task.data);
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

  @override
  void dispose() {
    _subscribers.clear();
    _subscription.cancel();
    //final error = StateError('$_debugLabel client closed');
    //for (final task in _queue) task.completer.completeError(error);
  }
}
 */