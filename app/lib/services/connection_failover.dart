/// Runs one bounded connection attempt per candidate, in caller-defined order.
/// Exceptions classified as fatal stop immediately; other failures advance to
/// the next candidate. Exception objects are deliberately not retained/logged.
Future<T> connectWithFallback<T>({
  required List<T> candidates,
  required Future<void> Function(T candidate) attempt,
  required bool Function(Object error) isFatal,
  void Function(T candidate, int index)? onAttempt,
}) async {
  if (candidates.isEmpty) throw const NoCandidatesException();

  for (var index = 0; index < candidates.length; index++) {
    final candidate = candidates[index];
    onAttempt?.call(candidate, index);
    try {
      await attempt(candidate);
      return candidate;
    } catch (error) {
      if (isFatal(error)) rethrow;
    }
  }
  throw AllCandidatesFailedException(candidates.length);
}

class NoCandidatesException implements Exception {
  const NoCandidatesException();
}

class AllCandidatesFailedException implements Exception {
  const AllCandidatesFailedException(this.attemptedCount);
  final int attemptedCount;
}
