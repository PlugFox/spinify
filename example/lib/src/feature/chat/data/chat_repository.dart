import 'dart:async';

import 'package:spinify/spinify.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_state.dart';

/// Chat repository
abstract interface class IChatRepository {
  Stream<SpinifyMessage> get messages;

  /// Connection state
  ChatConnectionState get connectionState;

  /// Connection states stream
  Stream<ChatConnectionState> get connectionStates;

  /// Connect to chat server
  Future<void> connect(String url);

  /// Disconnect from chat server
  Future<void> disconnect();

  /// Dispose
  Future<void> dispose();
}

final class ChatRepositorySpinifyImpl implements IChatRepository {
  ChatRepositorySpinifyImpl({required FutureOr<String?> Function()? getToken})
      : _spinify = Spinify(
          SpinifyConfig(
            getToken: getToken,
          ),
        );

  /// Centrifugo client
  final Spinify _spinify;

  @override
  ChatConnectionState get connectionState =>
      _spinifyStateToConnectionState(_spinify.state);

  @override
  late final Stream<ChatConnectionState> connectionStates =
      _spinify.states.map<ChatConnectionState>(_spinifyStateToConnectionState);

  ChatConnectionState _spinifyStateToConnectionState(SpinifyState state) =>
      switch (state) {
        SpinifyState$Connected _ => ChatConnectionState.connected,
        SpinifyState$Connecting _ => ChatConnectionState.connecting,
        SpinifyState$Disconnected _ => ChatConnectionState.disconnected,
        SpinifyState$Closed _ => ChatConnectionState.disconnected,
      };

  @override
  Stream<SpinifyMessage> get messages => throw UnimplementedError();

  @override
  Future<void> connect(String url) => _spinify.connect(url);

  @override
  Future<void> disconnect() => _spinify.disconnect();

  @override
  Future<void> dispose() async {
    await _spinify.close();
  }
}
