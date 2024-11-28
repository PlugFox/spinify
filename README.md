# Spinify

[![Pub](https://img.shields.io/pub/v/spinify.svg)](https://pub.dev/packages/spinify)
[![Actions Status](https://github.com/PlugFox/spinify/actions/workflows/checkout.yml/badge.svg)](https://github.com/PlugFox/spinify/actions)
[![Coverage](https://codecov.io/gh/PlugFox/spinify/branch/master/graph/badge.svg)](https://codecov.io/gh/PlugFox/spinify)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Linter](https://img.shields.io/badge/style-linter-40c4ff.svg)](https://pub.dev/packages/linter)
[![GitHub stars](https://img.shields.io/github/stars/plugfox/spinify?style=social)](https://github.com/plugfox/spinify/)

Websocket client for [Centrifugo server](https://github.com/centrifugal/centrifugo) and [Centrifuge library](https://github.com/centrifugal/centrifuge).

## Installation

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  spinify: <version>
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
Docker image centrifugo/centrifugo:v5
Flutter 3.24.5 • Dart 3.5.4
Package spinify v0.1.0
Package centrifuge-dart v0.14.1
```

The benchmark sends 10,000 messages of a certain size one after the other and measure the time.
Each message is sent sequentially: the client waits for the server's response before sending the next message.

### Windows

|       | Spinify             | Centrifuge-Dart     |
| ----- | ------------------- | ------------------- |
| 1 KB  | 5763 msg/s (7MB/s)  | 5361 msg/s (6MB/s)  |
| 5 KB  | 4405 msg/s (22MB/s) | 3731 msg/s (18MB/s) |
| 10 KB | 3717 msg/s (37MB/s) | 2857 msg/s (28MB/s) |
| 14 KB | 3305 msg/s (45MB/s) | 2564 msg/s (35MB/s) |
| 16 KB | 3091 msg/s (50MB/s) | 1982 msg/s (32MB/s) |
| 20 KB | 2812 msg/s (56MB/s) | 1811 msg/s (36MB/s) |
| 30 KB | 2463 msg/s (72MB/s) | 1470 msg/s (43MB/s) |
| 40 KB | 1937 msg/s (76MB/s) | 1089 msg/s (42MB/s) |
| 50 KB | 1740 msg/s (85MB/s) | 967 msg/s (47MB/s)  |
| 60 KB | 1583 msg/s (92MB/s) | 877 msg/s (51MB/s)  |

_\* Messages larger than 64 KB are not supported._

### Browser

|       | Spinify WASM        | Spinify JS          | Centrifuge-Dart JS  |
| ----- | ------------------- | ------------------- | ------------------- |
| 1 KB  | 3676 msg/s (4MB/s)  | 3502 msg/s (4MB/s)  | 3067 msg/s (3MB/s)  |
| 5 KB  | 2659 msg/s (13MB/s) | 3484 msg/s (17MB/s) | 2207 msg/s (11MB/s) |
| 10 KB | 1926 msg/s (19MB/s) | 3189 msg/s (31MB/s) | 1584 msg/s (15MB/s) |
| 14 KB | 1670 msg/s (22MB/s) | 2890 msg/s (39MB/s) | 1287 msg/s (17MB/s) |
| 16 KB | 39 msg/s (662KB/s)  | 39 msg/s (662KB/s)  | 39 msg/s (662KB/s)  |

_\* After message sizes exceed 15 KB, there is a noticeable performance drop._

## Features and Roadmap

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
- ❌ 95% test coverage
- ❌ JSON codec support
- ❌ Flutter package
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
