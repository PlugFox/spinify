# Spinify: contribution guide

## How to regenerate protobuf files

Windows:

```ps1
$ choco install protoc
$ dart pub global activate protoc_plugin
$ dart pub get
$ protoc --proto_path=lib/src/protobuf --dart_out=lib/src/protobuf lib/src/protobuf/client.proto
$ dart pub global activate pubspec_generator
$ dart pub global run pubspec_generator:generate -o lib/src/model/pubspec.yaml.g.dart
$ dart format -l 80 lib/ test/
```

Linux:

```bash
$ sudo apt update
$ sudo apt install -y protobuf-compiler dart
$ export PATH="$PATH":"$HOME/.pub-cache/bin"
$ dart pub global activate protoc_plugin
$ dart pub get
$ protoc --proto_path=lib/src/protobuf --dart_out=lib/src/protobuf lib/src/protobuf/client.proto
$ dart pub global activate pubspec_generator
$ dart pub global run pubspec_generator:generate -o lib/src/model/pubspec.yaml.g.dart
$ dart format -l 80 lib/ test/
```

macOS:

```zsh
$ brew update
$ brew install protobuf dart
$ export PATH="$PATH":"$HOME/.pub-cache/bin"
$ dart pub global activate protoc_plugin
$ dart pub get
$ protoc --proto_path=lib/src/protobuf --dart_out=lib/src/protobuf lib/src/protobuf/client.proto
$ dart pub global activate pubspec_generator
$ dart pub global run pubspec_generator:generate -o lib/src/model/pubspec.yaml.g.dart
$ dart format -l 80 lib/ test/
```
