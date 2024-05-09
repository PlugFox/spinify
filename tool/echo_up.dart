import 'dart:async';
import 'dart:io' as io;

/// Start the server.
void main() => Future<void>(() async {
      try {
        if (await _ping()) {
          _info('Server is already running');
          io.exit(0);
        }
        await _startServer();
        if (await _ping()) {
          _info('Server is running');
          io.exit(0);
        }
        _error('Failed to start server: no response from server');
        io.exit(2);
      } on Object catch (e, _) {
        _error('Failed to start server: $e');
        io.exit(1);
      }
    });

void _info(String message) => io.stdout.writeln(message);
void _error(String message) => io.stderr.writeln(message);

Future<bool> _ping() => io.HttpClient()
    .getUrl(Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: 8000,
      path: 'health',
    ))
    .then<io.HttpClientResponse>((request) => request.close())
    .timeout(const Duration(seconds: 15))
    .then((response) => response.statusCode == 200)
    .onError((error, stackTrace) => false);

Future<void> _startServer() async {
  String result;

  final workingDirectory = switch (io.Directory.current) {
    io.Directory directory
        when directory.listSync().whereType<io.File>().any((f) =>
            f.path.split(io.Platform.pathSeparator).lastOrNull ==
            'pubspec.yaml') =>
      '${directory.path}'
          '${io.Platform.pathSeparator}'
          'tool'
          '${io.Platform.pathSeparator}'
          'echo',
    io.Directory directory => directory
        .listSync(recursive: true)
        .whereType<io.File>()
        .firstWhere(
            (f) => f.path.split(io.Platform.pathSeparator).last == 'echo.go')
        .parent
        .path,
  };

  Stream<String> exec(Object /* String | List<String> */ command) {
    final [executable, ...arguments] = switch (command) {
      String string => string.split(' '),
      List<String> list => list,
      _ => throw ArgumentError.value(command, 'command'),
    };
    if (executable.isEmpty) return const Stream<String>.empty();
    //final s = io.Platform.pathSeparator;
    final controller = StreamController<List<int>>();
    Future<void>(() async {
      io.Process? process;
      final subs = <StreamSubscription<List<int>>>[];
      try {
        process = await io.Process.start(
          executable,
          arguments,
          mode: io.ProcessStartMode.normal,
          runInShell: false,
          workingDirectory: workingDirectory,
        );
        process.stdout.listen(controller.add);
        process.stderr.listen(controller.add);
        await process.exitCode;
      } finally {
        for (final sub in subs) sub.cancel().ignore();
        controller.close().ignore();
        process?.kill();
      }
    });
    return controller.stream
        .transform<String>(io.systemEncoding.decoder)
        //.transform<String>(const LineSplitter())
        .map<String>((line) => line.trim().toLowerCase());
  }

  Future<String> execToString(String command) =>
      exec(command).join('\n').then((output) => output.trim().toLowerCase());

  result = await execToString('go version');
  if (result.isNotEmpty && result.startsWith('go version')) {
    final done = await exec('go run echo.go')
        .firstWhere((line) => line.contains('server is running'))
        .timeout(const Duration(seconds: 15))
        .onError((_, __) => '')
        .then<bool>((v) => v.isNotEmpty);
    if (done) return;
    throw Exception('Failed to start go server');
  }

  result = await execToString('docker --version');
  if (result.isNotEmpty && result.startsWith('docker version')) {
    final done = await exec(
      'docker run --rm ' // -it
      '--ulimit nofile=65536:65536 '
      '-p 8000:8000 '
      '--name centrifuge '
      '-v ${io.Directory.current.path.replaceAll(r'\', '/')}/tool/echo:/app '
      '-w /app '
      'golang:latest '
      'go run echo.go',
    )
        .firstWhere((line) => line.contains('server is running'))
        .timeout(const Duration(seconds: 30))
        .onError((_, __) => '')
        .then<bool>((v) => v.isNotEmpty);
    if (done) return;
    throw Exception('Failed to start docker server');
  }

  throw Exception('No go or docker found');
}
