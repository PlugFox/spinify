# Centrifuge Dart

Websocket client for [Centrifugo server](https://github.com/centrifugal/centrifugo) and [Centrifuge library](https://github.com/centrifugal/centrifuge) based on [ws library](https://pub.dev/packages/ws).

## How to regenerate protobuf files

Windows:

```ps1
$ choco install protoc
$ dart pub global activate protoc_plugin
$ protoc --proto_path=lib/src/model/protobuf --dart_out=lib/src/model/protobuf lib/src/model/protobuf/client.proto
$ dart format -l 80 lib/src/model/protobuf/
```

Linux:

```bash
$ sudo apt update
$ sudo apt install -y protobuf-compiler dart
$ export PATH="$PATH":"$HOME/.pub-cache/bin"
$ dart pub global activate protoc_plugin
$ protoc --proto_path=lib/src/model/protobuf --dart_out=lib/src/model/protobuf lib/src/model/protobuf/client.proto
$ dart format -l 80 lib/src/model/protobuf/
```

macOS:

```zsh
$ brew update
$ brew install protobuf dart
$ export PATH="$PATH":"$HOME/.pub-cache/bin"
$ dart pub global activate protoc_plugin
$ protoc --proto_path=lib/src/model/protobuf --dart_out=lib/src/model/protobuf lib/src/model/protobuf/client.proto
$ dart format -l 80 lib/src/model/protobuf/
```
