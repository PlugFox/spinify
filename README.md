# Centrifuge Dart

Websocket client for [Centrifugo server](https://github.com/centrifugal/centrifugo) and [Centrifuge library](https://github.com/centrifugal/centrifuge) based on [ws library](https://pub.dev/packages/ws).

## Installation

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  centrifuge_dart: <version>
```

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

## Features and Roadmap

Connection related features

- ✅ Connect to a server
- ❌ Setting client options
- ❌ Automatic reconnect with backoff algorithm
- ❌ Client state changes
- ❌ Command-reply
- ❌ Command timeouts
- ❌ Async pushes
- ❌ Ping-pong
- ❌ Connection token refresh
- ❌ Handle disconnect advice from the server
- ❌ Server-side subscriptions
- ❌ Batching API
- ❌ Bidirectional WebSocket emulation

### Client-side subscription related features

- ❌ Subscribe to a channel
- ❌ Setting subscription options
- ❌ Automatic resubscribe with backoff algorithm
- ❌ Subscription state changes
- ❌ Subscription command-reply
- ❌ Subscription async pushes
- ❌ Subscription token refresh
- ❌ Handle unsubscribe advice from the server
- ❌ Manage subscription registry
- ❌ Optimistic subscriptions

## More resources

- [Library documentation](https://pub.dev/documentation/centrifuge_dart/latest/)
- [RFC 6455: The WebSocket Protocol](https://tools.ietf.org/html/rfc6455)
- [WebSocket API on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
- [Dart HTML WebSocket library](https://api.dart.dev/stable/dart-html/WebSocket-class.html)
- [Dart IO WebSocket library](https://api.dart.dev/stable/dart-io/WebSocket-class.html)
- [Centrifugo site](https://centrifugal.dev/)
- [Client SDK API](https://centrifugal.dev/docs/transports/client_api)
- [Client real-time SDKs](https://centrifugal.dev/docs/transports/client_sdk)
- [Client protocol](https://centrifugal.dev/docs/transports/client_protocol)
- [Protocol Buffers](https://protobuf.dev/)

## Coverage

[![](https://codecov.io/gh/PlugFox/centrifuge-dart/branch/master/graphs/sunburst.svg)](https://codecov.io/gh/PlugFox/centrifuge-dart/branch/master)

## Changelog

Refer to the [Changelog](https://github.com/PlugFox/centrifuge-dart/blob/master/CHANGELOG.md) to get all release notes.

## Maintainers

- [Matiunin Mikhail aka Plague Fox](https://plugfox.dev)

## Funding

If you want to support the development of our library, there are several ways you can do it:

- [Buy me a coffee](https://www.buymeacoffee.com/plugfox)
- [Support on Patreon](https://www.patreon.com/plugfox)
- [Subscribe through Boosty](https://boosty.to/plugfox)

We appreciate any form of support, whether it's a financial donation or just a star on GitHub. It helps us to continue developing and improving our library. Thank you for your support!

## License

[MIT](https://opensource.org/licenses/MIT)
