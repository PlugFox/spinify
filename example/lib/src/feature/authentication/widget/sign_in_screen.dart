import 'package:flutter/material.dart';
import 'package:spinifyapp/src/feature/authentication/widget/authentication_scope.dart';

/// {@template sign_in_screen}
/// SignInScreen widget.
/// {@endtemplate}
class SignInScreen extends StatelessWidget {
  /// {@macro sign_in_screen}
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Sign In'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                AuthenticationScope.controllerOf(context).signInAnonymously(),
            child: const Text('Sign In Anonymously'),
          ),
        ),
      );
}
