import 'dart:async';

import 'channel_event.dart';

/// Stream of received pushes from Centrifugo server for a channels.
/// {@category Event}
/// {@category Client}
/// {@category Subscription}
/// {@subCategory Push}
/// {@subCategory Channel}
extension type ChannelEvents<T extends SpinifyChannelEvent>(Stream<T> stream)
    implements Stream<T> {
  /// Stream of publication events.
  ChannelEvents<SpinifyPublication> get publication =>
      filter<SpinifyPublication>();

  /// Stream of presence events.
  ChannelEvents<SpinifyPresence> get presence => filter<SpinifyPresence>();

  /// Stream of unsubscribe events.
  ChannelEvents<SpinifyUnsubscribe> get unsubscribe =>
      filter<SpinifyUnsubscribe>();

  /// Stream of message events.
  ChannelEvents<SpinifyMessage> get message => filter<SpinifyMessage>();

  /// Stream of subscribe events.
  ChannelEvents<SpinifySubscribe> get subscribe => filter<SpinifySubscribe>();

  /// Stream of connect events.
  ChannelEvents<SpinifyConnect> get connect => filter<SpinifyConnect>();

  /// Stream of disconnect events.
  ChannelEvents<SpinifyDisconnect> get disconnect =>
      filter<SpinifyDisconnect>();

  /// Stream of refresh events.
  ChannelEvents<SpinifyRefresh> get refresh => filter<SpinifyRefresh>();

  /// Filtered stream of data of [SpinifyChannelEvent].
  ChannelEvents<S> filter<S extends SpinifyChannelEvent>({String? channel}) =>
      ChannelEvents<S>(transform<S>(StreamTransformer<T, S>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          S valid when channel == null || valid.channel == channel =>
            sink.add(valid),
          _ => null,
        },
      )));
}
