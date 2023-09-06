import 'package:flutter/material.dart';
import 'package:spinifyapp/src/common/controller/state_consumer.dart';
import 'package:spinifyapp/src/common/util/date_util.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_controller.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_state.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_messages_controller.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_messages_state.dart';
import 'package:spinifyapp/src/feature/chat/model/message.dart';
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
  late ChatMessagesController _messagesController;
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repository = DependenciesScope.of(context).chatRepository;
    _connectionController = ChatConnectionController(repository: repository);
    _messagesController =
        ChatMessagesController(user: widget.user, repository: repository);
    _connectionController.connect(widget.user.endpoint);
  }

  @override
  void didUpdateWidget(covariant ChatRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _connectionController.disconnect();
      _connectionController.connect(widget.user.endpoint);
      _messagesController.dispose();
      _messagesController = ChatMessagesController(
        user: widget.user,
        repository: DependenciesScope.of(context).chatRepository,
      );
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
            child: StateConsumer<ChatMessagesState>(
              controller: _messagesController,
              builder: (context, messagesState, child) => RepaintBoundary(
                child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  reverse: true,
                  itemCount: messagesState.data.length,
                  itemBuilder: (context, index) => ChatMessageBubble(
                    message: messagesState.data[index],
                    currentUser: widget.user,
                  ),
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
                      buildWhen: (previous, current) =>
                          !(previous.isIdling && current.isIdling),
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
                                    ? () => _messagesController
                                        .sendMessage(value.text)
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

/// {@template chat_room}
/// ChatMessageBubble widget.
/// {@endtemplate}
class ChatMessageBubble extends StatelessWidget {
  /// {@macro chat_room}
  const ChatMessageBubble(
      {required this.message, required this.currentUser, super.key});

  final Message message;
  final AuthenticatedUser currentUser;

  static const List<Color> _$colors = Colors.primaries;
  static Color _getColorForUsername(String username) =>
      _$colors[username.codeUnitAt(0) % _$colors.length];

  @override
  Widget build(BuildContext context) => Align(
        alignment: message.author == currentUser.username
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(
            const Size.fromWidth(512),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Stack(
              fit: StackFit.loose,
              children: <Widget>[
                Positioned(
                  top: 4,
                  left: 8,
                  child: Text(
                    message.author,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _getColorForUsername(message.author),
                      letterSpacing: 1,
                      height: 1,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 128),
                    child: Text(message.text),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Text(
                    message.createdAt.format(),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
