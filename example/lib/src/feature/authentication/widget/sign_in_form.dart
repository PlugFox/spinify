import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spinifyapp/src/common/constant/config.dart';
import 'package:spinifyapp/src/common/controller/state_consumer.dart';
import 'package:spinifyapp/src/common/localization/localization.dart';
import 'package:spinifyapp/src/feature/authentication/controller/authentication_controller.dart';
import 'package:spinifyapp/src/feature/authentication/model/sign_in_data.dart';
import 'package:spinifyapp/src/feature/authentication/widget/authentication_scope.dart';

/// {@template sign_in_form}
/// SignInScreen widget.
/// {@endtemplate}
class SignInForm extends StatelessWidget implements PreferredSizeWidget {
  /// {@macro sign_in_form}
  const SignInForm({super.key});

  /// Width of the sign in form.
  static const double width = 480;

  /// Height of the sign in form.
  static const double height = 720;

  @override
  Size get preferredSize => const Size(width, height);

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final space = math.min(constraints.maxHeight - preferredSize.height,
            constraints.maxWidth - preferredSize.width);
        final padding = switch (space) {
          > 32 => 24.0,
          > 24 => 16.0,
          > 16 => 8.0,
          _ => 0.0,
        };
        Widget wrap({required Widget child}) => padding > 0
            ? SizedBox(
                width: width,
                height: height,
                child: child,
              )
            : SizedBox.expand(
                child: child,
              );
        return wrap(
          child: Card(
            elevation: padding > 0 ? 8 : 0,
            margin: EdgeInsets.all(padding),
            shape: padding > 0
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(padding),
                  )
                : const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            child: const _SignInForm(),
          ),
        );
      });
}

class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

/// State for widget _SignInForm.
class _SignInFormState extends State<_SignInForm> {
  // Make it static so that it doesn't get disposed when the widget is rebuilt.
  static final TextEditingController _endpointController =
          TextEditingController(text: Config.centrifugeBaseUrl),
      _tokenController = TextEditingController(text: Config.centrifugeToken),
      _channelController =
          TextEditingController(text: Config.centrifugeChannel),
      _usernameController =
          TextEditingController(text: Config.centrifugeUsername),
      _secretController = TextEditingController();

  final FocusNode _endpointFocusNode = FocusNode(),
      _tokenFocusNode = FocusNode(),
      _channelFocusNode = FocusNode(),
      _usernameFocusNode = FocusNode(),
      _secretFocusNode = FocusNode();

  final ValueNotifier<String?> _endpointError = ValueNotifier<String?>(null),
      _tokenError = ValueNotifier<String?>(null),
      _channelError = ValueNotifier<String?>(null),
      _usernameError = ValueNotifier<String?>(null),
      _secretError = ValueNotifier<String?>(null);

  final ValueNotifier<bool> _validNotifier = ValueNotifier<bool>(false);

  late final AuthenticationController authenticationController;
  late final Listenable _observer;

  @override
  void initState() {
    super.initState();
    authenticationController = AuthenticationScope.controllerOf(context);
    _observer = Listenable.merge(<TextEditingController>[
      _endpointController,
      _tokenController,
      _channelController,
      _usernameController,
      _secretController,
    ])
      ..addListener(_onChanged);
    _onChanged();
  }

  @override
  void dispose() {
    _observer.removeListener(_onChanged);
    _validNotifier.dispose();
    super.dispose();
  }

  late SignInData _data;

  void _onChanged() {
    if (!mounted) return;
    _data = SignInData(
      endpoint: _endpointController.text,
      token: _tokenController.text,
      channel: _channelController.text,
      username: _usernameController.text,
      secret: _secretController.text,
    );
    _validNotifier.value = _validate(_data);
  }

  late final List<String? Function(SignInData data)> _validators =
      <String? Function(SignInData data)>[
    (data) => _endpointError.value = data.isValidEndpoint(),
    (data) => _tokenError.value = data.isValidToken(),
    (data) => _usernameError.value = data.isValidUsername(),
    (data) => _channelError.value = data.isValidChannel(),
    (data) => _secretError.value = data.isValidSecret(),
  ];
  bool _validate(SignInData data) {
    for (final validator in _validators) {
      if (validator(data) != null) return false;
    }
    return true;
  }

  void _submit() {
    final data = _data;
    if (!_validate(data)) return;
    authenticationController.signIn(data);
  }

  @override
  Widget build(BuildContext context) => FocusScope(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Text(
                      Localization.of(context).signInButton,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(height: 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SignInTextField(
                    focusNode: _endpointFocusNode,
                    controller: _endpointController,
                    error: _endpointError,
                    autofillHints: const <String>[
                      AutofillHints.url,
                    ],
                    maxLength: 1024,
                    keyboardType: TextInputType.url,
                    labelText: 'Endpoint',
                    hintText: 'Enter your endpoint',
                  ),
                  SignInTextField(
                    focusNode: _tokenFocusNode,
                    controller: _tokenController,
                    error: _tokenError,
                    maxLength: 64,
                    autofillHints: const <String>[
                      AutofillHints.password,
                    ],
                    keyboardType: TextInputType.visiblePassword,
                    labelText: 'Token',
                    hintText: 'Enter HMAC secret token',
                    obscureText: true,
                  ),
                  SignInTextField(
                    focusNode: _channelFocusNode,
                    controller: _channelController,
                    error: _channelError,
                    maxLength: 64,
                    labelText: 'Channel',
                    hintText: 'Enter your channel',
                    autofillHints: const <String>[
                      AutofillHints.username,
                    ],
                    keyboardType: TextInputType.name,
                    formatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^[a-zA-Z0-9_-]+$'),
                      ),
                    ],
                  ),
                  SignInTextField(
                    focusNode: _usernameFocusNode,
                    controller: _usernameController,
                    error: _usernameError,
                    maxLength: 64,
                    labelText: 'Username',
                    hintText: 'Select your username',
                    autofillHints: const <String>[
                      AutofillHints.username,
                    ],
                    keyboardType: TextInputType.name,
                    formatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        /// Allow only letters, numbers,
                        /// and the following characters: @.-_+
                        RegExp(r'\@|[A-Z]|[a-z]|[0-9]|\.|\-|\_|\+'),
                      ),
                    ],
                  ),
                  // TODO(plugfox): generate & copy
                  SignInTextField(
                    focusNode: _secretFocusNode,
                    controller: _secretController,
                    error: _secretError,
                    maxLength: 64,
                    autofillHints: const <String>[
                      AutofillHints.password,
                    ],
                    keyboardType: TextInputType.visiblePassword,
                    labelText: 'Secret (optional)',
                    hintText: 'For private channels only',
                    obscureText: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 64,
                  child: ValueListenableBuilder(
                    valueListenable: _validNotifier,
                    builder: (context, valid, _) => AnimatedOpacity(
                      opacity: valid ? 1 : .5,
                      duration: const Duration(milliseconds: 350),
                      child: ElevatedButton(
                        onPressed: valid ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(24),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Sign In'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class SignInTextField extends StatefulWidget {
  const SignInTextField({
    required this.controller,
    this.formatters,
    this.focusNode,
    this.error,
    this.autofillHints,
    this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLength,
    super.key,
  });

  final TextEditingController controller;
  final List<TextInputFormatter>? formatters;
  final FocusNode? focusNode;
  final ValueListenable<String?>? error;
  final List<String>? autofillHints;
  final String? labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  State<SignInTextField> createState() => _SignInTextFieldState();
}

class _SignInTextFieldState extends State<SignInTextField> {
  bool _obscurePassword = false;
  FocusNode? focusNode;

  @override
  void initState() {
    super.initState();
    _obscurePassword = widget.obscureText;
    focusNode = widget.focusNode?..addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    focusNode?.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (focusNode?.hasFocus == false &&
        mounted &&
        widget.obscureText &&
        !_obscurePassword) {
      setState(() => _obscurePassword = true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: StateConsumer(
          controller: AuthenticationScope.controllerOf(context),
          builder: (context, state, _) => AnimatedOpacity(
            opacity: state.isIdling ? 1 : .5,
            duration: const Duration(milliseconds: 250),
            child: ValueListenableBuilder<String?>(
              valueListenable: widget.error ?? ValueNotifier<String?>(null),
              builder: (context, error, child) => StatefulBuilder(
                builder: (context, setState) => TextField(
                  focusNode: widget.focusNode,
                  enabled: state.isIdling,
                  maxLines: 1,
                  minLines: 1,
                  maxLength: widget.maxLength,
                  controller: widget.controller,
                  autocorrect: false,
                  autofillHints: widget.autofillHints,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.formatters,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    constraints: const BoxConstraints(maxHeight: 84),
                    labelText: widget.labelText,
                    hintText: widget.hintText,
                    helperText: '',
                    helperMaxLines: 1,
                    errorText: error ?? state.error,
                    errorMaxLines: 1,
                    suffixIcon: widget.obscureText
                        ? IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
