import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// {@template jwt}
/// A JWT token consists of three parts: the header,
/// the payload, and the signature or encryption data.
/// The first two elements are JSON objects of a specific structure.
/// The third element is calculated based on the first two
/// and depends on the chosen algorithm
/// (in the case of using an unsigned JWT, it can be omitted).
/// Tokens can be re-encoded into a compact representation
/// (JWS/JWE Compact Serialization):
/// the header and payload are subjected to Base64-URL encoding,
/// after which the signature is added,
/// and all three elements are separated by periods (".").
///
/// https://centrifugal.dev/docs/server/authentication#connection-jwt-claims
/// {@endtemplate}
/// {@category Entity}
/// {@subCategory JWT}
@immutable
sealed class SpinifyJWT {
  /// {@macro jwt}
  ///
  /// Creates JWT from [secret] (with HMAC-SHA256 algorithm)
  const factory SpinifyJWT({
    required String sub,
    String? channel,
    int? exp,
    int? iat,
    String? jti,
    String? aud,
    String? iss,
    Map<String, Object?>? info,
    String? b64info,
    List<String>? channels,
    Map<String, Object?>? subs,
    Map<String, Object?>? meta,
    int? expireAt,
  }) = _SpinifyJWTImpl;

  /// {@macro jwt}
  ///
  /// Parses JWT, if [secret] is provided
  /// then checks signature by HMAC-SHA256 algorithm.
  factory SpinifyJWT.decode(String jwt, [String? secret]) =
      _SpinifyJWTImpl.decode;

  const SpinifyJWT._();

  /// This is a standard JWT claim which must contain
  /// an ID of the current application user (as string).
  ///
  /// If a user is not currently authenticated in an application,
  /// but you want to let him connect anyway – you can use
  /// an empty string as a user ID in sub claim.
  /// This is called anonymous access.
  abstract final String sub;

  /// Channel that client tries to subscribe to with this token (string).
  /// Required for channel token authorization.
  abstract final String? channel;

  /// This is a UNIX timestamp seconds when the token will expire.
  /// This is a standard JWT claim - all JWT libraries
  /// for different languages provide an API to set it.
  ///
  /// If exp claim is not provided then Centrifugo won't expire connection.
  /// When provided special algorithm will find connections with exp in the past
  /// and activate the connection refresh mechanism.
  /// Refresh mechanism allows connection to survive and be prolonged.
  /// In case of refresh failure, the client connection
  /// will be eventually closed by Centrifugo
  /// and won't be accepted until new valid and actual
  /// credentials are provided in the connection token.
  ///
  /// You can use the connection expiration mechanism in
  /// cases when you don't want users of your app
  /// to be subscribed on channels after being banned/deactivated in the application.
  /// Or to protect your users from token leakage
  /// (providing a reasonably short time of expiration).
  ///
  /// Choose exp value wisely, you don't need small
  /// values because the refresh mechanism
  /// will hit your application often with refresh requests.
  /// But setting this value too large can lead
  /// to slow user connection deactivation. This is a trade-off.
  ///
  /// Read more about connection expiration below.
  abstract final int? exp;

  /// This is a UNIX time when token was issued (seconds).
  /// See [definition in RFC](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.6).
  /// This claim is optional
  abstract final int? iat;

  /// This is a token unique ID. See [definition in RFC](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.7).
  /// This claim is optional.
  abstract final String? jti;

  /// Audience.
  /// [rfc7519 aud claim](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.3)
  /// By default, Centrifugo does not check JWT audience.
  ///
  /// But you can force this check by setting token_audience string option:
  /// ```json
  /// {
  ///   "token_audience": "centrifugo"
  /// }
  /// ```
  ///
  /// Setting token_audience will also affect subscription tokens
  /// (used for channel token authorization).
  /// If you need to separate connection token configuration
  /// and subscription token configuration
  /// check out separate subscription token config feature.
  ///
  /// This claim is optional.
  abstract final String? aud;

  /// Issuer.
  /// The "iss" (issuer) claim identifies the principal that issued the JWT.
  /// [rfc7519 iss claim](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.1)
  /// By default, Centrifugo does not check JWT issuer (rfc7519 iss claim).
  /// But you can force this check by setting token_issuer string option:
  /// ```json
  /// {
  ///   "token_issuer": "my_app"
  /// }
  /// ```
  ///
  /// Setting token_issuer will also affect subscription tokens
  /// (used for channel token authorization).
  /// If you need to separate connection token configuration
  /// and subscription token configuration
  /// check out separate subscription token config feature.
  ///
  /// This claim is optional.
  abstract final String? iss;

  /// This claim is optional - this is additional information
  /// about client connection
  /// that can be provided for Centrifugo.
  /// This information will be included in presence information,
  /// join/leave events, and channel publication if it was published from a client-side.
  abstract final Map<String, Object?>? info;

  /// If you are using binary Protobuf protocol you may want info
  /// to be custom bytes. Use this field in this case.
  ///
  /// This field contains a `base64` representation of your bytes.
  /// After receiving Centrifugo will decode base64 back to bytes
  /// and will embed the result into various places described above.
  abstract final String? b64info;

  /// An optional array of strings with server-side channels
  /// to subscribe a client to.
  /// See more details about [server-side subscriptions](https://centrifugal.dev/docs/server/server_subs).
  abstract final List<String>? channels;

  /// Subscriptions
  /// An optional map of channels with options. This is like a channels claim
  /// but allows more control over server-side subscription since every channel
  /// can be annotated with info, data, and so on using options.
  /// The claim sub described above is a standart JWT claim to provide a user ID
  /// (it's a shortcut from subject).
  /// While claims have similar names they have
  /// different purpose in a connection JWT.
  ///
  /// Example:
  /// ```json
  /// {
  ///   ...
  ///   "subs": {
  ///     "channel1": {
  ///       "data": {"welcome": "welcome to channel1"}
  ///     },
  ///     "channel2": {
  ///       "data": {"welcome": "welcome to channel2"}
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// Subscribe options:
  /// - (optional) info     - JSON object     - Custom channel info
  /// - (optional) b64info  - string          - Custom channel info in Base64
  /// - (optional) data     - JSON object     - Custom JSON data
  /// - (optional) b64data  - string          - Same as `data` but in Base64
  /// - (optional) override - Override object - Override some channel options.
  ///
  /// Override object:
  /// - (optional) presence   - BoolValue - Override presence
  /// - (optional) join_leave - BoolValue - Override join_leave
  /// - (optional) position   - BoolValue - Override position
  /// - (optional) recover    - BoolValue - Override recover
  ///
  /// BoolValue is an object like this:
  /// ```json
  /// {
  ///  "value": true
  /// }
  /// ```
  abstract final Map<String, Object?>? subs;

  /// Meta is an additional JSON object (ex. `{"key": "value"}`)
  /// that will be attached to a connection.
  /// Unlike `info` it's never exposed to clients inside presence
  /// and join/leave payloads
  /// and only accessible on a backend side. It may be included
  /// in proxy calls from Centrifugo
  /// to the application backend (see `proxy_include_connection_meta` option).
  /// Also, there is a `connections` API method in Centrifugo PRO that returns
  /// this data in the connection description object.
  abstract final Map<String, Object?>? meta;

  /// By default, Centrifugo looks on `exp` claim
  /// to configure connection expiration.
  /// In most cases this is fine, but there could be situations
  /// where you wish to decouple token expiration
  /// check with connection expiration time.
  /// As soon as the `expire_at` claim is provided (set)
  /// in JWT Centrifugo relies on it for setting
  /// connection expiration time
  /// (JWT expiration still checked over `exp` though).
  ///
  /// `expire_at` is a UNIX timestamp seconds when the connection should expire.
  ///
  /// Set it to the future time for expiring connection at some point
  /// Set it to 0 to disable connection expiration
  /// (but still check token exp claim).
  abstract final int? expireAt;

  /// Creates JWT from [secret] (with HMAC-SHA256 algorithm)
  /// and current payload.
  String encode(String secret);

  /// Creates a JSON representation of payload.
  Map<String, Object?> toJson();
}

final class _SpinifyJWTImpl extends SpinifyJWT {
  const _SpinifyJWTImpl({
    required this.sub,
    this.channel,
    this.exp,
    this.iat,
    this.jti,
    this.aud,
    this.iss,
    this.info,
    this.b64info,
    this.channels,
    this.subs,
    this.meta,
    this.expireAt,
  }) : super._();

  factory _SpinifyJWTImpl.decode(String jwt, [String? secret]) {
    // Split token into parts
    var parts = jwt.split('.');
    if (parts.length != 3) {
      // coverage:ignore-line
      throw const FormatException(
          'Invalid token format, expected 3 parts separated by "."');
    }
    final <String>[encodedHeader, encodedPayload, encodedSignature] = parts;

    if (secret != null) {
      // Compute signature
      final key = utf8.encode(secret); // Your 256 bit secret key
      final bytes = utf8.encode('$encodedHeader.$encodedPayload');
      final hmacSha256 = Hmac(sha256, key); // HMAC-SHA256
      final digest = hmacSha256.convert(bytes);
      final computedSignature = const _UnpaddedBase64Converter()
          .convert(base64Url.encode(digest.bytes));

      // Check signature equality
      // coverage:ignore-start
      if (computedSignature != encodedSignature) {
        throw const FormatException('Invalid token signature');
      }
      // coverage:ignore-end
    }

    Map<String, Object?> payload;
    try {
      payload = const Base64Decoder()
          .fuse<String>(const Utf8Decoder())
          .fuse<Map<String, Object?>>(
              const JsonDecoder().cast<String, Map<String, Object?>>())
          .convert(const _NormilizeBase64Converter().convert(encodedPayload));
    } on Object catch (_, stackTrace) {
      // coverage:ignore-start
      Error.throwWithStackTrace(
          const FormatException('Can\'t decode token payload'), stackTrace);
      // coverage:ignore-end
    }
    try {
      return _SpinifyJWTImpl(
        sub: payload['sub'] as String,
        channel: payload['channel'] as String?,
        exp: payload['exp'] as int?,
        iat: payload['iat'] as int?,
        jti: payload['jti'] as String?,
        aud: payload['aud'] as String?,
        iss: payload['iss'] as String?,
        info: payload['info'] as Map<String, Object?>?,
        b64info: payload['b64info'] as String?,
        channels: (payload['channels'] as Iterable<Object?>?)
            ?.whereType<String>()
            .toList(),
        subs: payload['subs'] as Map<String, Object?>?,
        meta: payload['meta'] as Map<String, Object?>?,
        expireAt: payload['expire_at'] as int?,
      );
    } on Object catch (_, stackTrace) {
      // coverage:ignore-start
      Error.throwWithStackTrace(
          const FormatException('Invalid token payload data'), stackTrace);
      // coverage:ignore-end
    }
  }

  static final Converter<Map<String, Object?>, String> _$encoder =
      const JsonEncoder()
          .cast<Map<String, Object?>, String>()
          .fuse<List<int>>(const Utf8Encoder())
          .fuse<String>(const Base64Encoder.urlSafe())
          .fuse<String>(const _UnpaddedBase64Converter());

  static final String _$headerHmacSha256 = _$encoder.convert(<String, Object?>{
    'alg': 'HS256',
    'typ': 'JWT',
  });

  @override
  final String sub;

  @override
  final String? channel;

  @override
  final int? exp;

  @override
  final int? iat;

  @override
  final String? jti;

  @override
  final String? aud;

  @override
  final String? iss;

  @override
  final Map<String, Object?>? info;

  @override
  final String? b64info;

  @override
  final List<String>? channels;

  @override
  final Map<String, Object?>? subs;

  @override
  final Map<String, Object?>? meta;

  @override
  final int? expireAt;

  @override
  String encode(String secret) {
    // Encode header and payload
    final encodedHeader = _$headerHmacSha256;
    final encodedPayload = _$encoder.convert(<String, Object?>{
      'sub': sub,
      if (channel != null) 'channel': channel,
      if (exp != null) 'exp': exp,
      if (iat != null) 'iat': iat,
      if (jti != null) 'jti': jti,
      if (aud != null) 'aud': aud,
      if (iss != null) 'iss': iss,
      if (info != null) 'info': info,
      if (b64info != null) 'b64info': b64info,
      if (channels != null) 'channels': channels,
      if (subs != null) 'subs': subs,
      if (meta != null) 'meta': meta,
      if (expireAt != null) 'expire_at': expireAt,
    });

    // Payload signature
    final key = utf8.encode(secret); // Your 256 bit secret key
    final bytes = utf8.encode('$encodedHeader.$encodedPayload');

    final hmacSha256 = Hmac(sha256, key); // HMAC-SHA256
    final digest = hmacSha256.convert(bytes);

    // Encode signature
    final encodedSignature = const Base64Encoder.urlSafe()
        .fuse<String>(const _UnpaddedBase64Converter())
        .convert(digest.bytes);

    // Return JWT
    return '$encodedHeader.$encodedPayload.$encodedSignature';
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'sub': sub,
        if (channel != null) 'channel': channel,
        if (exp != null) 'exp': exp,
        if (iat != null) 'iat': iat,
        if (jti != null) 'jti': jti,
        if (aud != null) 'aud': aud,
        if (iss != null) 'iss': iss,
        if (info != null) 'info': info,
        if (b64info != null) 'b64info': b64info,
        if (channels != null) 'channels': channels,
        if (subs != null) 'subs': subs,
        if (meta != null) 'meta': meta,
        if (expireAt != null) 'expireAt': expireAt,
      };

  @override
  String toString() => 'SpinifyJWT{sub: $sub}';
}

/// A converter that converts Base64-encoded strings
/// to unpadded Base64-encoded strings.
class _UnpaddedBase64Converter extends Converter<String, String> {
  const _UnpaddedBase64Converter();

  @override
  String convert(String input) {
    final padding = input.indexOf('=', input.length - 2);
    if (padding != -1) return input.substring(0, padding);
    return input;
  }
}

/// A converter thats normalizes Base64-encoded strings
class _NormilizeBase64Converter extends Converter<String, String> {
  const _NormilizeBase64Converter();

  @override
  String convert(String input) {
    final padding = (4 - input.length % 4) % 4;
    return input + '=' * padding;
  }
}
