# Spinify: contribution guide

## How to regenerate protobuf files

Windows:

```ps1
$ choco install protoc
$ dart pub global activate protoc_plugin
$ dart pub get
$ protoc --proto_path=lib/src/model/protobuf --dart_out=lib/src/model/protobuf lib/src/model/protobuf/client.proto
$ dart run build_runner build --delete-conflicting-outputs
$ dart format -l 80 lib/src/model/pubspec.yaml.g.dart lib/src/model/protobuf/
```

Linux:

```bash
$ sudo apt update
$ sudo apt install -y protobuf-compiler dart
$ export PATH="$PATH":"$HOME/.pub-cache/bin"
$ dart pub global activate protoc_plugin
$ dart pub get
$ protoc --proto_path=lib/src/model/protobuf --dart_out=lib/src/model/protobuf lib/src/model/protobuf/client.proto
$ dart run build_runner build --delete-conflicting-outputs
$ dart format -l 80 lib/src/model/pubspec.yaml.g.dart lib/src/model/protobuf/
```

macOS:

```zsh
$ brew update
$ brew install protobuf dart
$ export PATH="$PATH":"$HOME/.pub-cache/bin"
$ dart pub global activate protoc_plugin
$ dart pub get
$ protoc --proto_path=lib/src/model/protobuf --dart_out=lib/src/model/protobuf lib/src/model/protobuf/client.proto
$ dart run build_runner build --delete-conflicting-outputs
$ dart format -l 80 lib/src/model/pubspec.yaml.g.dart lib/src/model/protobuf/
```
