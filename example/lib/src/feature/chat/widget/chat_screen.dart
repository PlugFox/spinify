import 'package:flutter/material.dart';
import 'package:spinifyapp/src/common/controller/state_consumer.dart';
import 'package:spinifyapp/src/feature/authentication/widget/authentication_scope.dart';

/// {@template chat_screen}
/// ChatScreen widget.
/// {@endtemplate}
class ChatScreen extends StatelessWidget {
  /// {@macro chat_screen}
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = AuthenticationScope.controllerOf(context);
    return StateConsumer(
      controller: authController,
      builder: (context, state, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          actions: <Widget>[
            IconButton(
              onPressed: state.user.isNotAuthenticated
                  ? null
                  : () => authController.signOut(),
              icon: const Icon(Icons.logout),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: const Center(
          child: Text('Chat'),
        ),
      ),
    );
  }
}
