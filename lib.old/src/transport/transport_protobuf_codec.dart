import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' as pb;

import '../util/logger.dart' as logger;
import 'protobuf/client.pb.dart' as pb;

@internal
final class TransportProtobufCodec extends Codec<Object, List<int>> {
  const TransportProtobufCodec();

  @override
  Converter<List<int>, Iterable<pb.Reply>> get decoder =>
      const TransportProtobufDecoder();

  @override
  Converter<pb.Command, List<int>> get encoder =>
      const TransportProtobufEncoder();
}

@internal
final class TransportProtobufEncoder extends Converter<pb.Command, List<int>> {
  const TransportProtobufEncoder();

  @override
  List<int> convert(pb.GeneratedMessage input) {
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

@internal
final class TransportProtobufDecoder
    extends Converter<List<int>, Iterable<pb.Reply>> {
  const TransportProtobufDecoder();

  @override
  Iterable<pb.Reply> convert(List<int> input) sync* {
    final reader = pb.CodedBufferReader(input);
    while (!reader.isAtEnd()) {
      try {
        final reply = pb.Reply();
        reader.readMessage(reply, pb.ExtensionRegistry.EMPTY);
        yield reply;
      } on Object catch (error, stackTrace) {
        logger.warning(
          error,
          stackTrace,
          'Failed to decode reply: $error',
        );
      }
    }
  }
}
