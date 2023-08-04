import 'package:flutter/material.dart';
import 'package:spinifyapp/src/common/controller/state_consumer.dart';
import 'package:spinifyapp/src/common/localization/localization.dart';
import 'package:spinifyapp/src/feature/authentication/controller/authentication_controller.dart';
import 'package:spinifyapp/src/feature/authentication/widget/authentication_scope.dart';
import 'package:spinifyapp/src/feature/chat/widget/chat_room.dart';

/// {@template chat_screen}
/// ChatScreen widget.
/// {@endtemplate}
class ChatScreen extends StatefulWidget {
  /// {@macro chat_screen}
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final AuthenticationController authController;

  @override
  void initState() {
    super.initState();
    authController = AuthenticationScope.controllerOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthenticationScope.controllerOf(context);
    return StateConsumer(
      controller: authController,
      builder: (context, state, _) => Scaffold(
        appBar: AppBar(
          title: Text(Localization.of(context).title),
          centerTitle: true,
          automaticallyImplyLeading: false,
          /* elevation: 4, */
          /* pinned: MediaQuery.of(context).size.height > 600, */
          actions: <Widget>[
            IconButton(
              onPressed: () =>
                  AuthenticationScope.controllerOf(context).signOut(),
              icon: const Icon(Icons.logout),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: state.user.map<Widget>(
            authenticated: (user) => const ChatRoom(),
            unauthenticated: (_) => const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
