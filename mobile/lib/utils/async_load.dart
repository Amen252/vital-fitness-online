/// Helpers so dashboard sections never block forever on one slow/failed API call.
library;

/// Runs [futures] in parallel; each failure becomes [fallback] instead of
/// failing the whole [Future.wait].
Future<List<T>> waitIsolated<T>(
  Iterable<Future<T>> futures, {
  required T fallback,
}) {
  return Future.wait(
    futures.map(
      (f) => f.catchError((Object _) => fallback),
    ),
  );
}

/// Same as [waitIsolated], with an overall deadline so loading UIs always settle.
Future<List<T>> waitIsolatedTimed<T>(
  Iterable<Future<T>> futures, {
  required T fallback,
  Duration timeout = const Duration(seconds: 35),
}) {
  final list = futures.toList(growable: false);
  return waitIsolated(list, fallback: fallback).timeout(
    timeout,
    onTimeout: () => List<T>.filled(list.length, fallback),
  );
}
