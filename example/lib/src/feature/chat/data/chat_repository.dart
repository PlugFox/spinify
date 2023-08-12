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
}

final class ChatRepositorySpinifyImpl implements IChatRepository {
  ChatRepositorySpinifyImpl({required Spinify spinify}) : _spinify = spinify;

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
        _ => ChatConnectionState.disconnected,
      };

  @override
  Stream<SpinifyMessage> get messages => throw UnimplementedError();

  @override
  Future<void> connect(String url) => _spinify.connect(url);

  @override
  Future<void> disconnect() => _spinify.disconnect();
}
