// ignore_for_file: avoid_classes_with_only_static_members

import 'package:protobuf/protobuf.dart' as pb;

abstract final class ProtobufCodec {
  /// Encode a protobuf message to a list of bytes.
  static List<int> encode(pb.GeneratedMessage msg) {
    final bytes = msg.writeToBuffer();
    return (pb.CodedBufferWriter()
          ..writeInt32NoTag(bytes.lengthInBytes)
          ..writeRawBytes(bytes))
        .toBuffer();
  }

  /// Decode a protobuf message from a list of bytes.
  static T decode<T extends pb.GeneratedMessage>(T msg, List<int> bytes) {
    final reader = pb.CodedBufferReader(bytes);
    assert(!reader.isAtEnd(), 'No data to read');
    reader.readMessage(msg, pb.ExtensionRegistry.EMPTY);
    assert(reader.isAtEnd(), 'Not all data was read');
    return msg;
  }
}
