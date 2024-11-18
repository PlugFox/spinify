import 'dart:convert';

import 'command.dart';
import 'reply.dart';

/// A codec for encoding and decoding Spinify commands and replies.
abstract interface class SpinifyCodec {
  /// The protocol used by the codec.
  /// e.g. 'centrifuge-protobuf'
  abstract final String protocol;

  /// Decodes a Spinify replies from a list of bytes.
  abstract final Converter<List<int>, Iterable<SpinifyReply>> decoder;

  /// Encodes a Spinify command to a list of bytes.
  abstract final Converter<SpinifyCommand, List<int>> encoder;
}
