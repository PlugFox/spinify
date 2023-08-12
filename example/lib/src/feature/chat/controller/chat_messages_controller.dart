import 'package:l/l.dart';
import 'package:spinifyapp/src/common/controller/droppable_controller_concurrency.dart';
import 'package:spinifyapp/src/common/controller/state_controller.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_messages_state.dart';
import 'package:spinifyapp/src/feature/chat/data/chat_repository.dart';

final class ChatMessagesController extends StateController<ChatMessagesState>
    with DroppableControllerConcurrency {
  ChatMessagesController({required IChatRepository repository})
      : _repository = repository,
        super(initialState: ChatMessagesState.initial);

  final IChatRepository _repository;

  void sendMessage(AuthenticatedUser user, String message) => handle(
        () async {
          l.v6('Sending message');
          await _repository.sendMessage(user, message);
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
    _repository.disconnect();
    super.dispose();
  }
}
