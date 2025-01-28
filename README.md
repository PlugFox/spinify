# Spinify

[![Pub](https://img.shields.io/pub/v/spinify.svg)](https://pub.dev/packages/spinify)
[![Actions Status](https://github.com/PlugFox/spinify/actions/workflows/checkout.yml/badge.svg)](https://github.com/PlugFox/spinify/actions)
[![Coverage](https://codecov.io/gh/PlugFox/spinify/branch/master/graph/badge.svg)](https://codecov.io/gh/PlugFox/spinify)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Linter](https://img.shields.io/badge/style-linter-40c4ff.svg)](https://pub.dev/packages/linter)
[![GitHub stars](https://img.shields.io/github/stars/plugfox/spinify?style=social)](https://github.com/plugfox/spinify/)

Spinify is a Dart and Flutter library that provides an efficient client implementation for [Centrifugo](https://centrifugal.dev/), a scalable real-time messaging server.
This library allows you to connect your Dart or Flutter applications to [Centrifugo server](https://github.com/centrifugal/centrifugo) and [Centrifuge library](https://github.com/centrifugal/centrifuge), enabling real-time updates, presence information, history fetching, and more.

## Features

- **Connection Management**: Establish, monitor, and close connections to Centrifugo servers.
- **Subscriptions**: Create, manage, and remove client-side and server-side subscriptions.
- **Event Streaming**: Stream channel events for real-time updates.
- **Data Publishing**: Publish messages to specific channels.
- **Asynchronous Messaging**: Send custom asynchronous messages to the server.
- **Presence Management**: Retrieve presence and presence statistics for channels.
- **History Retrieval**: Fetch publication history for specific channels.
- **Remote Procedure Calls (RPC)**: Perform server-side method invocations.
- **Metrics**: Access metrics for client performance and statistics.
- **Reconnecting**: Automatically reconnect to the server in case of a connection failure.
- **Protobuf Transport**: Use Protobuf codec for data serialization.
- **Custom Configuration**: Configure client settings, timeouts, and transport options.
- **Error Handling**: Handle errors and exceptions gracefully.
- **Logging**: Log events, errors, and messages for debugging purposes.
- **Cross-Platform**: Run on Dart VM, Flutter, and Web platforms.
- **Performance**: Achieve high throughput and low latency for real-time messaging.
- **Headers Emulation**: Emulate HTTP headers for WebSocket connections at the Web platform.

## Installation

Add the following dependency to your `pubspec.yaml` file and specify the version:

```yaml
dependencies:
  spinify: ^X.Y.Z
```

Then fetch the package using:

```bash
flutter pub get
```

## Examples

Simple usage of the library:

```dart
final client = Spinify();
await client.connect(url);
// ...
await client.close();
```

Add custom configuration:

```dart
final httpClient = io.HttpClient(
  context: io.SecurityContext(
    withTrustedRoots: true,
  )..setTrustedCertificatesBytes([/* bytes array */]),
);

final client = Spinify(
  config: SpinifyConfig(
    client: (name: 'app', version: '1.0.0'),
    timeout: const Duration(seconds: 15),
    serverPingDelay: const Duration(seconds: 8),
    connectionRetryInterval: (
      min: const Duration(milliseconds: 250),
      max: const Duration(seconds: 15),
    ),
    getToken: () async => '<token>',
    getPayload: () async => utf8.encode('Hello, World!'),
    codec: SpinifyProtobufCodec(),
    transportBuilder: SpinifyTransportAdapter.vm(
      compression: io.CompressionOptions.compressionDefault,
      customClient: httpClient,
      userAgent: 'Dart',
    ),
    logger: (level, event, message, context) => print('[$event] $message'),
  ),
);
```

Subscribe to a channel:

```dart
final sub = client.newSubscription('notifications:index');
sub.stream.publication().map((p) => utf8.decode(p.data)).listen(print);
await sub.subscribe();
await sub.publish(utf8.encode('Hello, World!'));
await sub.unsubscribe();
```

## Benchmarks

This benchmark measures the performance of the [spinify](https://pub.dev/packages/spinify) and [centrifuge-dart](https://pub.dev/packages/centrifuge) libraries by sending and receiving a series of messages to a Centrifugo server and tracking key performance metrics such as throughput and latency.

Environment:

```
Windows 11 Pro 64-bit
CPU 13th Gen Intel Core i7-13700K
Chrome Version 131.0.6778.86 (Official Build) (64-bit)
Docker version 27.1.1
Docker image centrifugo/centrifugo:latest
Flutter 3.24.5 • Dart 3.5.4
Package spinify v0.1.0
Package centrifuge-dart v0.14.1
```

The benchmark sends 10,000 messages of a certain size one after the other and measure the time.
Each message is sent sequentially: the client waits for the server's response before sending the next message.

### Windows (Dart VM)

|       | Spinify             | Centrifuge-Dart     |
| ----- | ------------------- | ------------------- |
| 1 KB  | 5396 msg/s (6MB/s)  | 5433 msg/s (6MB/s)  |
| 14 KB | 3216 msg/s (46MB/s) | 3224 msg/s (46MB/s) |
| 30 KB | 2371 msg/s (71MB/s) | 2352 msg/s (70MB/s) |
| 60 KB | 1558 msg/s (92MB/s) | 1547 msg/s (91MB/s) |

_\* Messages larger than 64 KB are not supported._

### Browser (WASM and JS)

|       | Spinify WASM        | Spinify JS          | Centrifuge-Dart JS  |
| ----- | ------------------- | ------------------- | ------------------- |
| 1 KB  | 3676 msg/s (4MB/s)  | 3590 msg/s (6MB/s)  | 3720 msg/s (6MB/s)  |
| 5 KB  | 2659 msg/s (13MB/s) | 3227 msg/s (18MB/s) | 3223 msg/s (18MB/s) |
| 10 KB | 1926 msg/s (19MB/s) | 3031 msg/s (32MB/s) | 3029 msg/s (32MB/s) |
| 14 KB | 1670 msg/s (22MB/s) | 2750 msg/s (39MB/s) | 2830 msg/s (40MB/s) |

_\* After message sizes exceed 15 KB, there is a noticeable performance drop._

## Roadmap

- ✅ Connect to a server
- ✅ Setting client configuration
- ✅ Automatic reconnect with backoff algorithm
- ✅ Client state changes
- ✅ Protobuf transport
- ✅ Command-reply
- ✅ Command timeouts
- ✅ Async pushes
- ✅ Ping-pong
- ✅ Connection token refresh
- ✅ Server-side subscriptions
- ✅ Presence information
- ✅ Presence stats
- ✅ History information
- ✅ Send custom RPC commands
- ✅ Handle disconnect advice from the server
- ✅ Channel subscription
- ✅ Setting subscription options
- ✅ Automatic resubscribe with backoff algorithm
- ✅ Subscription state changes
- ✅ Subscription command-reply
- ✅ Subscription token refresh
- ✅ Handle unsubscribe advice from the server
- ✅ Manage subscription registry
- ✅ Publish data into a channel
- ✅ Set observer for hooking events & errors
- ✅ Metrics and stats
- ✅ Package errors
- ✅ Meta information about the library
- ✅ Web transport via extension type
- ✅ Benchmarks
- ✅ Performance comparison with other libraries
- ✅ WASM compatibility
- ✅ Headers emulation
- ❌ 95% test coverage
- ❌ JSON codec support for transport
- ❌ DevTools extension
- ❌ Run in separate isolate
- ❌ Middleware support
- ❌ Batching API
- ❌ Bidirectional WebSocket emulation
- ❌ Optimistic subscriptions
- ❌ Delta compression

## More resources

- [Library documentation](https://pub.dev/documentation/spinify/latest/)
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

[![](https://codecov.io/gh/PlugFox/spinify/branch/master/graphs/sunburst.svg)](https://codecov.io/gh/PlugFox/spinify/branch/master)

## Changelog

Refer to the [Changelog](https://github.com/PlugFox/spinify/blob/master/CHANGELOG.md) to get all release notes.

## Maintainers

- [Mike Matiunin aka Plague Fox](https://plugfox.dev)

## Funding

If you want to support the development of our library, there are several ways you can do it:

- [Buy me a coffee](https://www.buymeacoffee.com/plugfox)
- [Support on Patreon](https://www.patreon.com/plugfox)
- [Subscribe through Boosty](https://boosty.to/plugfox)

We appreciate any form of support, whether it's a financial donation or just a star on GitHub. It helps us to continue developing and improving our library. Thank you for your support!

## License

[The MIT License](https://opensource.org/licenses/MIT)
