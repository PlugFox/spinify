import 'package:meta/meta.dart';

/// Spinify client events.
@internal
abstract interface class ClientEvents {
  static const String prefix = 'client';
  static const String init = '${prefix}_init';
  static const String close = '${prefix}_close';
  static const String connecting = '${prefix}_connecting';
  static const String connected = '${prefix}_connected';
  static const String disconnecting = '${prefix}_disconnecting';
  static const String disconnected = '${prefix}_disconnected';
  static const String stateChanged = '${prefix}_state_changed';
}
