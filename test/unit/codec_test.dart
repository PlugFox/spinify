import 'package:protobuf/protobuf.dart' as pb;
import 'package:spinify/spinify.dart';
import 'package:spinify/src/protobuf/client.pb.dart' as pb;
import 'package:test/test.dart';

void main() => group('Codec', () {
      test('Command_encoding', () {
        final command = SpinifySendRequest(
          timestamp: DateTime(2021, 1, 1),
          data: [for (var i = 0; i < 256; i++) i],
        );
        const codec = SpinifyProtobufCommandEncoder();
        final bytesFromCodec = codec.convert(command);
        expect(bytesFromCodec.length, greaterThan(0));

        // Try read the bytes back.
        final reader = pb.CodedBufferReader(bytesFromCodec);
        final decoded = pb.Command();
        reader.readMessage(decoded, pb.ExtensionRegistry.EMPTY);

        expect(reader.isAtEnd(), isTrue);
        expect(decoded.id, equals(command.id));
        expect(decoded.send.data, equals(command.data));

        // Compare with direct encoding through protobuf and concatenation.
        final commandData = decoded.writeToBuffer();
        final writer = pb.CodedBufferWriter()
          ..writeInt32NoTag(commandData.lengthInBytes);
        final bytesFromTest = writer.toBuffer() + commandData;
        expect(bytesFromCodec.length, equals(bytesFromTest.length));
        expect(bytesFromCodec, equals(bytesFromTest));
      });
    });
