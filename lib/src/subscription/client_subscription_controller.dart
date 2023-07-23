import 'dart:async';

import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';
import 'package:centrifuge_dart/src/model/publication.dart';
import 'package:centrifuge_dart/src/model/subscription_config.dart';
import 'package:meta/meta.dart';

/// Constroller responsible for managing subscription.
/// {@nodoc}
@internal
final class ClientSubscriptionController {
  /// {@nodoc}
  ClientSubscriptionController({
    required this.config,
    required this.client,
  });

  /// {@nodoc}
  final CentrifugeSubscriptionConfig config;

  /// {@nodoc}
  final WeakReference<ICentrifuge> client;

  /// Stream of publications.
  /// {@nodoc}
  Stream<CentrifugePublication> get publications =>
      _publicationController.stream;

  /// {@nodoc}
  final StreamController<CentrifugePublication> _publicationController =
      StreamController<CentrifugePublication>.broadcast();

  /// Start subscribing to a channel
  /// {@nodoc}
  Future<void> subscribe() async {
    // TODO(plugfox): implement
  }

  /// Unsubscribe from a channel
  /// {@nodoc}
  Future<void> unsubscribe() async {
    // TODO(plugfox): implement
  }

  /* publish(data) - publish data to Subscription channel
  history(options) - request Subscription channel history
  presence() - request Subscription channel online presence information
  presenceStats() - request Subscription channel online presence stats information (number of client connections and unique users in a channel).
 */

  /// {@nodoc}
  @internal
  void close() {
    _publicationController.close().ignore();
  }
}
