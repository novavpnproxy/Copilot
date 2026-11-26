import 'package:flutter_test/flutter_test.dart';
import 'package:nova_vpn_app/services/connection_failover.dart';

void main() {
  group('connectWithFallback', () {
    test('returns the first candidate that connects', () async {
      final attempted = <String>[];
      final result = await connectWithFallback<String>(
        candidates: const ['primary', 'secondary'],
        attempt: (candidate) async => attempted.add(candidate),
        isFatal: (_) => false,
      );
      expect(result, 'primary');
      expect(attempted, ['primary']);
    });

    test('advances after a recoverable failure', () async {
      final attempted = <String>[];
      final result = await connectWithFallback<String>(
        candidates: const ['primary', 'secondary', 'tertiary'],
        attempt: (candidate) async {
          attempted.add(candidate);
          if (candidate != 'tertiary') {
            throw StateError('temporary connection failure');
          }
        },
        isFatal: (_) => false,
      );
      expect(result, 'tertiary');
      expect(attempted, ['primary', 'secondary', 'tertiary']);
    });

    test('stops immediately on a fatal error', () async {
      final attempted = <String>[];
      final fatal = ArgumentError('permission denied');
      await expectLater(
        connectWithFallback<String>(
          candidates: const ['primary', 'secondary'],
          attempt: (candidate) async {
            attempted.add(candidate);
            throw fatal;
          },
          isFatal: (error) => error is ArgumentError,
        ),
        throwsA(same(fatal)),
      );
      expect(attempted, ['primary']);
    });

    test('reports the number of candidates after total failure', () async {
      final attempted = <String>[];
      await expectLater(
        connectWithFallback<String>(
          candidates: const ['one', 'two', 'three'],
          attempt: (candidate) async {
            attempted.add(candidate);
            throw StateError('connection failed');
          },
          isFatal: (_) => false,
        ),
        throwsA(isA<AllCandidatesFailedException>().having(
          (error) => error.attemptedCount,
          'attemptedCount',
          3,
        )),
      );
      expect(attempted, ['one', 'two', 'three']);
    });

    test('rejects an empty candidate list', () async {
      await expectLater(
        connectWithFallback<String>(
          candidates: const [],
          attempt: (_) async {},
          isFatal: (_) => false,
        ),
        throwsA(isA<NoCandidatesException>()),
      );
    });

    test('reports attempt callbacks in zero-based order', () async {
      final callbacks = <String>[];
      await connectWithFallback<String>(
        candidates: const ['primary', 'secondary'],
        onAttempt: (candidate, index) => callbacks.add('$candidate:$index'),
        attempt: (candidate) async {
          if (candidate == 'primary') throw StateError('try next');
        },
        isFatal: (_) => false,
      );
      expect(callbacks, ['primary:0', 'secondary:1']);
    });
  });
}
