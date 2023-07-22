import 'dart:convert';

import 'package:centrifuge_dart/src/model/protobuf/client.pb.dart' as pb;
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' as pb;

/// {@nodoc}
@internal
final class TransportProtobufCodec extends Codec<Object, List<int>> {
  /// {@nodoc}
  const TransportProtobufCodec();

  @override
  Converter<List<int>, Iterable<pb.Reply>> get decoder =>
      const TransportProtobufDecoder();

  @override
  Converter<pb.Command, List<int>> get encoder =>
      const TransportProtobufEncoder();
}

/// {@nodoc}
@internal
final class TransportProtobufEncoder extends Converter<pb.Command, List<int>> {
  /// {@nodoc}
  const TransportProtobufEncoder();

  @override
  List<int> convert(pb.GeneratedMessage input) {
    // TODO(plugfox): Find out better way to encode.
    /* final buffer = pb.CodedBufferWriter();
    input.writeToCodedBufferWriter(buffer);
    return buffer.toBuffer(); */
    final commandData = input.writeToBuffer();
    final length = commandData.lengthInBytes;
    final writer = pb.CodedBufferWriter()
      ..writeInt32NoTag(length); //..writeRawBytes(commandData);
    return writer.toBuffer() + commandData;
  }
}

/// {@nodoc}
@internal
final class TransportProtobufDecoder
    extends Converter<List<int>, Iterable<pb.Reply>> {
  /// {@nodoc}
  const TransportProtobufDecoder();

  @override
  Iterable<pb.Reply> convert(List<int> input) sync* {
    final reader = pb.CodedBufferReader(input);
    while (!reader.isAtEnd()) {
      final reply = pb.Reply();
      reader.readMessage(reply, pb.ExtensionRegistry.EMPTY);
      yield reply;
    }
  }
}
