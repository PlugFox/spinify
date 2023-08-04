import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// {@template chat_screen}
/// ChatRoom widget.
/// {@endtemplate}
class ChatRoom extends StatefulWidget {
  /// {@macro chat_screen}
  const ChatRoom({super.key});

  /// The state from the closest instance of this class
  /// that encloses the given context, if any.
  @internal
  static _ChatRoomState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_ChatRoomState>();

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

/// State for widget ChatRoom.
class _ChatRoomState extends State<ChatRoom> {
  /* #region Lifecycle */
  @override
  void initState() {
    super.initState();
    // Initial state initialization
  }

  @override
  void didUpdateWidget(ChatRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget configuration changed
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The configuration of InheritedWidgets has changed
    // Also called after initState but before build
  }

  @override
  void dispose() {
    // Permanent removal of a tree stent
    super.dispose();
  }
  /* #endregion */

  @override
  Widget build(BuildContext context) => ListView.builder(
        scrollDirection: Axis.vertical,
        reverse: true,
        itemCount: 1000,
        itemBuilder: (context, index) => ListTile(
          title: Text('Item $index'),
        ),
      );
}
