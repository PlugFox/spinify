import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';
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

  // TODO(plugfox): implement
}
