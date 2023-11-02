import 'dart:async';
import 'dart:collection';

import 'package:l/l.dart';
import 'package:spinifyapp/src/common/controller/droppable_controller_concurrency.dart';
import 'package:spinifyapp/src/common/controller/state_controller.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_messages_state.dart';
import 'package:spinifyapp/src/feature/chat/data/chat_repository.dart';
import 'package:spinifyapp/src/feature/chat/model/message.dart';

final class ChatMessagesController extends StateController<ChatMessagesState>
    with DroppableControllerConcurrency {
  ChatMessagesController(
      {required AuthenticatedUser user, required IChatRepository repository})
      : _user = user,
        _repository = repository,
        super(initialState: ChatMessagesState.initial) {
    final AuthenticatedUser(:channel, :secret) = user;
    _messagesSubscription =
        _repository.getMessages(channel, secret).listen(_onMessage);
  }

  final AuthenticatedUser _user;
  final IChatRepository _repository;
  late final StreamSubscription<Message> _messagesSubscription;
  late final Set<Message> _messages = SplayTreeSet<Message>.of(
    state.data,
    (a, b) => b.compareTo(a),
  );

  void _onMessage(Message message) {
    setState(state.copyWith(
        data: (_messages..add(message)).toList(growable: false)));
  }

  void sendMessage(String message) => handle(
        () async {
          l.v6('Sending message');
          await _repository.sendMessage(_user, message);
          setState(ChatMessagesState.successful(
              data: state.data, message: 'Message sent'));
          l.v6('Message sent');
        },
        (error, stackTrace) {
          l.w('Error sending message: $error', stackTrace);
          setState(
            ChatMessagesState.error(
                data: state.data, message: 'Error sending message'),
          );
        },
        () => setState(ChatMessagesState.idle(data: state.data)),
      );

  void disconnect() => handle(_repository.disconnect);

  @override
  void dispose() {
    _messagesSubscription.cancel();
    _repository.disconnect();
    super.dispose();
  }
}
