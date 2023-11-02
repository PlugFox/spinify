import 'package:flutter/material.dart';

/// {@template authentication_screen}
/// AuthenticationScreen widget.
/// {@endtemplate}
class AuthenticationScreen extends StatelessWidget {
  /// {@macro authentication_screen}
  const AuthenticationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Authentication'),
        ),
        body: const Center(
          child: Text('Authentication'),
        ),
      );
}
