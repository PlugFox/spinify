import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:protobuf/protobuf.dart' as pb;
import 'package:spinify/src/protobuf/client.pb.dart' as pb;

void main() {
  final command = pb.Command(
    send: pb.SendRequest(
      data: Uint16List.fromList([for (var i = 0; i < 256; i++) i]),
    ),
  );

  final a = _EncdingBenchmark$Concatination(command)..report();
  final b = _EncdingBenchmark$Builder(command)..report();

  if (a.bytes.length != b.bytes.length) {
    throw StateError('Bytes length mismatch');
  }
  for (var i = 0; i < a.bytes.length; i++) {
    if (a.bytes[i] != b.bytes[i]) {
      throw StateError('Bytes mismatch at index $i');
    }
  }
}

class _EncdingBenchmark$Concatination extends BenchmarkBase {
  _EncdingBenchmark$Concatination(this.command)
      : super('Encoding concatination');

  final pb.Command command;

  List<int> bytes = Uint8List(0);

  @override
  void run() {
    final commandData = command.writeToBuffer();
    final length = commandData.lengthInBytes;
    final writer = pb.CodedBufferWriter()..writeInt32NoTag(length);
    bytes = writer.toBuffer() + commandData;
  }
}

class _EncdingBenchmark$Builder extends BenchmarkBase {
  _EncdingBenchmark$Builder(this.command) : super('Encoding builder');

  final pb.Command command;

  List<int> bytes = Uint8List(0);

  @override
  void run() {
    final commandData = command.writeToBuffer();
    final length = commandData.lengthInBytes;
    final writer = pb.CodedBufferWriter()
      ..writeInt32NoTag(length)
      ..writeRawBytes(commandData);
    bytes = writer.toBuffer();
  }
}
