import 'dart:async';

import 'channel_event.dart';

/// Stream of received pushes from Centrifugo server for a channels.
/// {@category Event}
/// {@category Client}
/// {@category Subscription}
/// {@subCategory Push}
/// {@subCategory Channel}
extension type SpinifyChannelEvents<T extends SpinifyChannelEvent>(
    Stream<T> stream) implements Stream<T> {
  /// Stream of publication events.
  SpinifyChannelEvents<SpinifyPublication> publication({String? channel}) =>
      filter<SpinifyPublication>(channel: channel);

  /// Stream of presence events.
  SpinifyChannelEvents<SpinifyPresence> presence({String? channel}) =>
      filter<SpinifyPresence>(channel: channel);

  /// Stream of unsubscribe events.
  SpinifyChannelEvents<SpinifyUnsubscribe> unsubscribe({String? channel}) =>
      filter<SpinifyUnsubscribe>(channel: channel);

  /// Stream of message events.
  SpinifyChannelEvents<SpinifyMessage> message({String? channel}) =>
      filter<SpinifyMessage>(channel: channel);

  /// Stream of subscribe events.
  SpinifyChannelEvents<SpinifySubscribe> subscribe({String? channel}) =>
      filter<SpinifySubscribe>(channel: channel);

  /// Stream of connect events.
  SpinifyChannelEvents<SpinifyConnect> connect({String? channel}) =>
      filter<SpinifyConnect>(channel: channel);

  /// Stream of disconnect events.
  SpinifyChannelEvents<SpinifyDisconnect> disconnect({String? channel}) =>
      filter<SpinifyDisconnect>(channel: channel);

  /// Stream of refresh events.
  SpinifyChannelEvents<SpinifyRefresh> refresh({String? channel}) =>
      filter<SpinifyRefresh>(channel: channel);

  /// Filtered stream of [SpinifyChannelEvent].
  SpinifyChannelEvents<S> filter<S extends SpinifyChannelEvent>(
          {String? channel}) =>
      SpinifyChannelEvents<S>(transform<S>(StreamTransformer<T, S>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          S valid when channel == null || valid.channel == channel =>
            sink.add(valid),
          _ => null,
        },
      )));
}
