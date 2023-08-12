import 'package:flutter/material.dart';
import 'package:spinifyapp/src/common/controller/state_consumer.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_controller.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_state.dart';
import 'package:spinifyapp/src/feature/chat/data/chat_repository.dart';

/// {@template chat_screen}
/// ChatRoom widget.
/// {@endtemplate}
class ChatRoom extends StatefulWidget {
  /// {@macro chat_screen}
  const ChatRoom({required this.user, super.key});

  /// The user that is currently logged in
  final AuthenticatedUser user;

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

/// State for widget ChatRoom.
class _ChatRoomState extends State<ChatRoom> {
  late final IChatRepository _repository;
  late final ChatConnectionController _chatConnectionController;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepositorySpinifyImpl(getToken: () => widget.user.token);
    _chatConnectionController =
        ChatConnectionController(repository: _repository);
    _chatConnectionController.connect(widget.user.endpoint);
  }

  @override
  void didUpdateWidget(covariant ChatRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _chatConnectionController.disconnect();
      _chatConnectionController.connect(widget.user.endpoint);
    }
  }

  @override
  void dispose() {
    _chatConnectionController.dispose();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: StateConsumer(
          controller: _chatConnectionController,
          builder: (context, state, child) => switch (state) {
            ChatConnectionState.connecting => const CircularProgressIndicator(),
            ChatConnectionState.connected => const Text('Connected'),
            ChatConnectionState.disconnected => const Text('Disconnected'),
          },
        ),
      );

  /* @override
  Widget build(BuildContext context) => ListView.builder(
        scrollDirection: Axis.vertical,
        reverse: true,
        itemCount: 1000,
        itemBuilder: (context, index) => ListTile(
          title: Text('Item $index'),
        ),
      ); */
}
