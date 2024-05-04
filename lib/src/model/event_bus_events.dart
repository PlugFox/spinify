import 'package:meta/meta.dart';

/// Spinify client events.
@internal
enum ClientEvent {
  /// Client initialization (constructor).
  init('client_init'),

  /// Interactively connect to the server.
  connect('client_connect'),

  /// Interactively disconnect from the server.
  disconnect('client_disconnect'),

  /// Interactively send a command to the server.
  command('client_command'),

  /// Interactively close the client.
  close('client_close');

  const ClientEvent(this.name);

  /// Event name.
  final String name;

  @override
  String toString() => name;
}
