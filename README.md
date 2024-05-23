# Spinify

[![Pub](https://img.shields.io/pub/v/spinify.svg)](https://pub.dev/packages/spinify)
[![Actions Status](https://github.com/PlugFox/spinify/actions/workflows/checkout.yml/badge.svg)](https://github.com/PlugFox/spinify/actions)
[![Coverage](https://codecov.io/gh/PlugFox/spinify/branch/master/graph/badge.svg)](https://codecov.io/gh/PlugFox/spinify)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Linter](https://img.shields.io/badge/style-linter-40c4ff.svg)](https://pub.dev/packages/linter)
[![GitHub stars](https://img.shields.io/github/stars/plugfox/spinify?style=social)](https://github.com/plugfox/spinify/)

Websocket client for [Centrifugo server](https://github.com/centrifugal/centrifugo) and [Centrifuge library](https://github.com/centrifugal/centrifuge) based on [ws library](https://pub.dev/packages/ws).

## Installation

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  spinify: <version>
```

## Features and Roadmap

Connection related features

- ✅ Connect to a server
- ✅ Setting client options
- ✅ Automatic reconnect with backoff algorithm
- ✅ Client state changes
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
- ❌ Handle disconnect advice from the server
- ❌ Batching API
- ❌ Bidirectional WebSocket emulation

### Client-side features

- ✅ Subscribe to a channel
- ✅ Protobuf transport
- ✅ Setting subscription options
- ✅ Automatic resubscribe with backoff algorithm
- ✅ Subscription state changes
- ✅ Subscription command-reply
- ✅ Subscription async pushes
- ✅ Subscription token refresh
- ✅ Handle unsubscribe advice from the server
- ✅ Manage subscription registry
- ✅ Publish data into a channel
- ✅ Enqueue methods
- ✅ Set observer for hooking events & errors
- ✅ Metrics
- ❌ Optimistic subscriptions
- ❌ Run in separate isolate
- ❌ JSON transport
- ❌ DevTools extension

## Example

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

- [Matiunin Mikhail aka Plague Fox](https://plugfox.dev)

## Funding

If you want to support the development of our library, there are several ways you can do it:

- [Buy me a coffee](https://www.buymeacoffee.com/plugfox)
- [Support on Patreon](https://www.patreon.com/plugfox)
- [Subscribe through Boosty](https://boosty.to/plugfox)

We appreciate any form of support, whether it's a financial donation or just a star on GitHub. It helps us to continue developing and improving our library. Thank you for your support!

## License

[The MIT License](https://opensource.org/licenses/MIT)
