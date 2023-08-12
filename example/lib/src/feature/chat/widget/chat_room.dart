import 'package:flutter/material.dart';
import 'package:spinifyapp/src/common/controller/state_consumer.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_controller.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_state.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_messages_controller.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_messages_state.dart';
import 'package:spinifyapp/src/feature/dependencies/widget/dependencies_scope.dart';

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
  late final ChatConnectionController _connectionController;
  late final ChatMessagesController _messagesController;
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repository = DependenciesScope.of(context).chatRepository;
    _connectionController = ChatConnectionController(repository: repository);
    _messagesController = ChatMessagesController(repository: repository);
    _connectionController.connect(widget.user.endpoint);
  }

  @override
  void didUpdateWidget(covariant ChatRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _connectionController.disconnect();
      _connectionController.connect(widget.user.endpoint);
    }
  }

  @override
  void dispose() {
    _messagesController.dispose();
    _connectionController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Expanded(
            child: RepaintBoundary(
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                reverse: true,
                itemCount: 1000,
                itemBuilder: (context, index) => ListTile(
                  title: Text('Item $index'),
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: .5),
          RepaintBoundary(
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: ColoredBox(
                color: Colors.grey.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StateConsumer<ChatConnectionState>(
                    controller: _connectionController,
                    builder: (context, connectionState, _) =>
                        StateConsumer<ChatMessagesState>(
                      controller: _messagesController,
                      listener: (context, previous, current) {
                        switch (current) {
                          case ChatMessagesState$Successful _:
                            _textEditingController.clear();
                          case ChatMessagesState$Error state:
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          default:
                            break;
                        }
                      },
                      builder: (context, messagesState, child) => Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _textEditingController,
                              enabled: connectionState.isConnected,
                              maxLength: 128,
                              maxLines: 1,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                                hintText: 'Write a message...',
                              ),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _textEditingController,
                            builder: (context, value, _) {
                              final enabled = connectionState.isConnected &&
                                  messagesState.isIdling &&
                                  value.text.isNotEmpty;
                              return IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  child: switch (connectionState) {
                                    ChatConnectionState$Connecting _ =>
                                      const CircularProgressIndicator(),
                                    ChatConnectionState$Connected _ =>
                                      const Icon(Icons.send),
                                    ChatConnectionState$Disconnected _ =>
                                      const Icon(Icons.send_outlined),
                                  },
                                ),
                                onPressed: enabled
                                    ? () => _messagesController.sendMessage(
                                          widget.user,
                                          value.text,
                                        )
                                    : null,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
