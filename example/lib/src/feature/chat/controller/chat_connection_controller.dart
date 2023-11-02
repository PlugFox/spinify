import 'package:spinifyapp/src/common/controller/droppable_controller_concurrency.dart';
import 'package:spinifyapp/src/common/controller/state_controller.dart';
import 'package:spinifyapp/src/feature/chat/controller/chat_connection_state.dart';
import 'package:spinifyapp/src/feature/chat/data/chat_repository.dart';

final class ChatConnectionController
    extends StateController<ChatConnectionState>
    with DroppableControllerConcurrency {
  ChatConnectionController({required IChatRepository repository})
      : _repository = repository,
        super(initialState: repository.connectionState) {
    _repository.connectionStates.distinct().listen(setState);
  }

  final IChatRepository _repository;

  void connect(String url) => handle(() => _repository.connect(url));

  void disconnect() => handle(_repository.disconnect);

  @override
  void dispose() {
    _repository.disconnect();
    super.dispose();
  }
}
