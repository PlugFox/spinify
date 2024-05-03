import 'dart:async';
import 'dart:convert';

import 'package:l/l.dart';
import 'package:spinify/spinify.old.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_state.dart';
import 'package:spinifyapp/src/feature/chat/model/message.dart';

/// Chat repository
abstract interface class IChatRepository {
  /// Receive messages stream
  Stream<Message> getMessages(String channel, [String? secret]);

  /// Connection state
  ChatConnectionState get connectionState;

  /// Connection states stream
  Stream<ChatConnectionState> get connectionStates;

  /// Connect to chat server
  Future<void> connect(String url);

  /// Disconnect from chat server
  Future<void> disconnect();

  /// Send message to chat server
  Future<void> sendMessage(AuthenticatedUser user, String message);
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
        SpinifyState$Connected _ => const ChatConnectionState.connected(),
        SpinifyState$Connecting _ => const ChatConnectionState.connecting(),
        _ => const ChatConnectionState.disconnected(),
      };

  @override
  Stream<Message> getMessages(String channel, [String? secret]) {
    void ignoreErrors(Object error, StackTrace? stackTrace) {
      l.w('Error receiving message: $error', stackTrace);
    }

    final Converter<List<int>, Message> decoder;
    if (secret != null && secret.isNotEmpty) {
      decoder = EncryptedMessageDecoder(secretKey: secret);
    } else {
      decoder = const PlainMessageDecoder();
    }

    return _spinify.stream.publications
        .where((event) => event.channel == channel)
        .map<List<int>>((event) => event.data)
        .map<Message>(decoder.convert)
        .handleError(ignoreErrors);
  }

  @override
  Future<void> connect(String url) => _spinify.connect(url);

  @override
  Future<void> disconnect() => _spinify.disconnect();

  @override
  Future<void> sendMessage(AuthenticatedUser user, String message) async {
    if (!_spinify.state.isConnected) {
      throw Exception('Spinify is not connected');
    }
    final serverChannels = _spinify.subscriptions.server.values.toList();
    final AuthenticatedUser(:channel, :username, :secret) = user;
    if (!serverChannels.any((c) => c.channel == channel))
      throw Exception('Spinify server channel is not set');
    List<int> data;
    switch (secret) {
      case null || '':
        data = const PlainMessageEncoder().convert(
          PlainMessage(
            author: username,
            text: message,
            createdAt: DateTime.now(),
            version: 1,
          ),
        );
      case String secret:
        data = EncryptedMessageEncoder(secretKey: secret).convert(
          EncryptedMessage(
            author: username,
            text: message,
            createdAt: DateTime.now(),
            version: 1,
          ),
        );
    }
    await _spinify.publish(channel, data);
  }
}
