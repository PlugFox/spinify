import 'package:flutter/material.dart';

@immutable
final class SignInData {
  SignInData({
    required this.endpoint,
    required this.token,
    required this.username,
    required this.channel,
    String? secret,
  }) : secret = secret == null || secret.isEmpty ? null : secret;

  /// Centrifuge endpoint
  final String endpoint;

  /// Centrifuge HMAC token for JWT authentication.
  /// **BEWARE**: You should not store the token in the real app!
  final String token;

  /// Centrifuge username.
  final String username;

  /// Centrifuge channel.
  final String channel;

  /// Centrifuge secret (optional)
  final String? secret;

  static final RegExp _urlValidator = RegExp(
    r'^(https?:\/\/)?(localhost|((([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|((\d{1,3}\.){3}\d{1,3})))?(:\d+)?(\/[-a-z\d%_.~+]*)*(\?[;&a-z\d%_.~+=-]*)?(\#[-a-z\d_]*)?$',
    caseSensitive: false,
    multiLine: false,
  );
  String? isValidEndpoint() {
    if (endpoint.isEmpty) return 'Endpoint is required';
    if (endpoint.length < 6) return 'Endpoint is too short';
    if (endpoint.length > 1024) return 'Endpoint is too long';
    if (!_urlValidator.hasMatch(endpoint)) return 'Endpoint is invalid';
    return null;
  }

  String? isValidToken() {
    if (token.isEmpty) return 'Token is required';
    if (token.length < 6) return 'Token is too short';
    if (token.length > 64) return 'Token is too long';
    return null;
  }

  static final RegExp _usernameValidator = RegExp(
    r'\@|[A-Z]|[a-z]|[0-9]|\.|\-|\_|\+',
    caseSensitive: false,
    multiLine: false,
  );
  String? isValidUsername() {
    if (username.isEmpty) return 'Username is required';
    if (username.length < 4) return 'Username is too short';
    if (username.length > 64) return 'Username is too long';
    if (!_usernameValidator.hasMatch(username)) return 'Username is invalid';
    return null;
  }

  static final RegExp _channelValidator = RegExp(
    r'^[a-zA-Z0-9_-]+$',
    caseSensitive: false,
    multiLine: false,
  );
  String? isValidChannel() {
    if (channel.isEmpty) return 'Channel is required';
    if (channel.length < 4) return 'Channel is too short';
    if (channel.length > 64) return 'Channel is too long';
    if (!_channelValidator.hasMatch(channel)) return 'Channel is invalid';
    return null;
  }

  String? isValidSecret() {
    final secret = this.secret;
    if (secret == null || secret.isEmpty) return null;
    if (secret.length < 4) return 'Secret is too short';
    if (secret.length > 64) return 'Secret is too long';
    return null;
  }
}
