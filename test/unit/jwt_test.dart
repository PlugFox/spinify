// ignore_for_file: prefer_const_constructors

import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  group('JWT', () {
    test('Create', () {
      expect(() => SpinifyJWT(sub: 'sub'), returnsNormally);
    });

    test('Encode_and_decode', () {
      final jwt = SpinifyJWT(
        sub: 'sub',
        channel: 'channel',
        iat: 1234567890,
        exp: 1234567890,
        iss: 'iss',
        aud: 'aud',
        jti: 'jti',
        expireAt: 1234567890,
        b64info: 'b64info',
        channels: const <String>[
          'channel1',
          'channel2',
        ],
        subs: const <String, Object?>{},
        info: const <String, Object?>{},
        meta: const <String, Object?>{},
        claims: const {
          'key': 'value',
          'a': 1,
        },
      );
      expect(jwt, isA<SpinifyJWT>());
      expect(jwt.toString(), equals('SpinifyJWT{sub: ${jwt.sub}}'));
      final encoded = jwt.encode('secret');
      expect(encoded, isA<String>());
      final decoded = SpinifyJWT.decode(encoded, 'secret');
      expect(
        decoded,
        isA<SpinifyJWT>()
            .having((e) => e.sub, 'sub', jwt.sub)
            .having((e) => e.channel, 'channel', jwt.channel)
            .having((e) => e.iat, 'iat', jwt.iat)
            .having((e) => e.exp, 'exp', jwt.exp)
            .having((e) => e.iss, 'iss', jwt.iss)
            .having((e) => e.aud, 'aud', jwt.aud)
            .having((e) => e.jti, 'jti', jwt.jti)
            .having((e) => e.expireAt, 'expireAt', jwt.expireAt)
            .having((e) => e.b64info, 'b64info', jwt.b64info)
            .having((e) => e.channels, 'channels', jwt.channels)
            .having((e) => e.subs, 'subs', jwt.subs)
            .having(
              (e) => e.claims,
              'claims',
              allOf(
                containsPair('key', 'value'),
                containsPair('a', 1),
                containsPair('sub', jwt.sub),
                containsPair('channel', jwt.channel),
              ),
            ),
      );
      expect(decoded.toJson(), equals(jwt.toJson()));
      expect(decoded.toString(), equals(jwt.toString()));
      expect(SpinifyJWT(sub: 'sub').toString(), equals('SpinifyJWT{sub: sub}'));
      expect(SpinifyJWT().toString(), equals('SpinifyJWT{}'));
    });
  });
}
