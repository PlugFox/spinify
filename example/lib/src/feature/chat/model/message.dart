import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

@immutable
sealed class Message implements Comparable<Message> {
  const Message({
    required this.author,
    required this.text,
    required this.version,
    required this.createdAt,
  });

  /// The type of the message.
  abstract final String type;

  /// The author of the message.
  final String author;

  /// The text of the message.
  final String text;

  /// The version of the message.
  final int version;

  /// The time the message was created.
  final DateTime createdAt;

  Map<String, Object?> toJson();
}

final class PlainMessage extends Message {
  const PlainMessage({
    required super.author,
    required super.text,
    required super.version,
    required super.createdAt,
  });

  factory PlainMessage.fromJson(Map<String, Object?> json) {
    if (json
        case <String, Object?>{
          'type': 'plain',
          'author': String author,
          'text': String text,
          'version': int version,
          'createdAt': int createdAt,
        })
      return PlainMessage(
        author: author,
        text: text,
        version: version,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      );
    throw const FormatException('Invalid message type');
  }

  @override
  String get type => 'plain';

  @override
  int compareTo(Message other) => createdAt.compareTo(other.createdAt);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'author': author,
        'text': text,
        'version': version,
        'createdAt': createdAt.millisecondsSinceEpoch ~/ 1000,
      };

  @override
  String toString() => '$author: $text';
}

final class EncryptedMessage extends Message {
  const EncryptedMessage({
    required super.author,
    required super.text,
    required super.version,
    required super.createdAt,
  });

  factory EncryptedMessage.fromJson(Map<String, Object?> json) {
    if (json
        case <String, Object?>{
          'type': 'encrypted',
          'author': String author,
          'text': String text,
          'version': int version,
          'createdAt': int createdAt,
        })
      return EncryptedMessage(
        author: author,
        text: text,
        version: version,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      );
    throw const FormatException('Invalid message type');
  }

  @override
  int compareTo(Message other) => createdAt.compareTo(other.createdAt);

  @override
  String get type => 'encrypted';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'author': author,
        'text': text,
        'version': version,
        'createdAt': createdAt.millisecondsSinceEpoch ~/ 1000,
      };

  @override
  String toString() => '$author: $text';
}

@immutable
final class PlainMessageCodec extends Codec<PlainMessage, List<int>> {
  const PlainMessageCodec();

  @override
  Converter<List<int>, PlainMessage> get decoder => const PlainMessageDecoder();

  @override
  Converter<PlainMessage, List<int>> get encoder => const PlainMessageEncoder();
}

final class PlainMessageDecoder extends Converter<List<int>, PlainMessage> {
  const PlainMessageDecoder();

  @override
  PlainMessage convert(List<int> input) =>
      PlainMessage.fromJson(_$bytesDecoder.convert(input));
}

final class PlainMessageEncoder extends Converter<PlainMessage, List<int>> {
  const PlainMessageEncoder();

  @override
  List<int> convert(PlainMessage input) =>
      _$bytesEncoder.convert(input.toJson());
}

@immutable
final class EncryptedMessageCodec extends Codec<EncryptedMessage, List<int>> {
  const EncryptedMessageCodec({required this.secretKey});

  final String secretKey;

  @override
  Converter<List<int>, EncryptedMessage> get decoder =>
      EncryptedMessageDecoder(secretKey: secretKey);

  @override
  Converter<EncryptedMessage, List<int>> get encoder =>
      EncryptedMessageEncoder(secretKey: secretKey);
}

final class EncryptedMessageDecoder
    extends Converter<List<int>, EncryptedMessage> {
  EncryptedMessageDecoder({required String secretKey})
      : _secret = utf8.encode(secretKey);

  final List<int> _secret;
  late final int secretLength = _secret.length;
  late final Digest _digest = sha256.convert(_secret);

  @override
  EncryptedMessage convert(List<int> input) {
    if (input.length < 32) throw const FormatException('Message too short');
    final signature = input.sublist(input.length - 32);
    if (_digest != Digest(signature))
      throw const FormatException('Invalid signature');
    final bytes = input.sublist(0, input.length - 32);
    for (var i = 0; i < bytes.length; i++)
      bytes[i] ^= _secret[i % secretLength];
    return EncryptedMessage.fromJson(_$bytesDecoder.convert(bytes));
  }
}

final class EncryptedMessageEncoder
    extends Converter<EncryptedMessage, List<int>> {
  EncryptedMessageEncoder({required String secretKey})
      : _secret = utf8.encode(secretKey);

  final List<int> _secret;
  late final int secretLength = _secret.length;
  late final Digest _digest = sha256.convert(_secret);

  @override
  List<int> convert(EncryptedMessage input) {
    final bytes = _$bytesEncoder.convert(input.toJson());
    for (var i = 0; i < bytes.length; i++)
      bytes[i] ^= _secret[i % secretLength];
    return bytes + _digest.bytes;
  }
}

final Converter<List<int>, Map<String, Object?>> _$bytesDecoder =
    const Utf8Decoder()
        .fuse(const JsonDecoder().cast<String, Map<String, Object?>>());

final Converter<Map<String, Object?>, List<int>> _$bytesEncoder =
    const JsonEncoder()
        .cast<Map<String, Object?>, String>()
        .fuse(const Utf8Encoder());
