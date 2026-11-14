import 'package:flutter_test/flutter_test.dart';
import 'package:nova_vpn_app/services/connection_failover.dart';

void main() {
  group('connectWithFallback', () {
    test('tries candidates in order and returns first success', () async {
      final attempts = <int>[];
      final result = await connectWithFallback<int>(
        candidates: [1, 2, 3],
        attempt: (candidate) async {
          attempts.add(candidate);
          if (candidate != 3) throw StateError('unavailable');
        },
        isFatal: (_) => false,
      );
      expect(attempts, [1, 2, 3]);
      expect(result, 3);
    });

    test('does not retry fatal failures such as permission or API errors', () async {
      final attempts = <int>[];
      await expectLater(
        connectWithFallback<int>(
          candidates: [1, 2],
          attempt: (candidate) async {
            attempts.add(candidate);
            throw const FatalTestException();
          },
          isFatal: (error) => error is FatalTestException,
        ),
        throwsA(isA<FatalTestException>()),
      );
      expect(attempts, [1]);
    });

    test('reports exhaustion without exposing attempt exceptions', () async {
      final attempts = <int>[];
      await expectLater(
        connectWithFallback<int>(
          candidates: [1, 2],
          attempt: (candidate) async {
            attempts.add(candidate);
            throw StateError('private profile text must not escape');
          },
          isFatal: (_) => false,
        ),
        throwsA(isA<AllCandidatesFailedException>().having((e) => e.attemptedCount, 'attemptedCount', 2)),
      );
      expect(attempts, [1, 2]);
    });

    test('empty candidate list fails immediately', () async {
      await expectLater(
        connectWithFallback<int>(
          candidates: [],
          attempt: (_) async {},
          isFatal: (_) => false,
        ),
        throwsA(isA<NoCandidatesException>()),
      );
    });
  });
}

class FatalTestException implements Exception {
  const FatalTestException();
}
