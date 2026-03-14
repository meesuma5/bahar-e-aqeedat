import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'firebase_service.dart';
import 'munqabat_service.dart';

final firebaseServiceProvider = Provider((_) => FirebaseService.instance);
final munqabatServiceProvider = Provider((_) => MunqabatService());

// ─── Auth ─────────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider(
  (ref) => FirebaseService.instance.authStateChanges,
);

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;
  return FirebaseService.instance.getCurrentUser();
});

// ─── Data Streams ─────────────────────────────────────────────────────────

final usersStreamProvider = StreamProvider<List<AppUser>>(
  (_) => FirebaseService.instance.streamAllUsers(),
);

final candidatesStreamProvider = StreamProvider<List<Candidate>>(
  (_) => FirebaseService.instance.streamCandidates(),
);

final sessionsStreamProvider = StreamProvider<List<Session>>(
  (_) => FirebaseService.instance.streamSessions(),
);

final candidateScoresProvider = StreamProvider.family<List<Score>, String>((
  _,
  candidateId,
) {
  return FirebaseService.instance.streamScoresForCandidate(candidateId);
});

final sessionScoresProvider = StreamProvider.family<List<Score>, String>((
  _,
  sessionId,
) {
  return FirebaseService.instance.streamScoresForSession(sessionId);
});

final scoresStreamProvider = StreamProvider<List<Score>>(
  (_) => FirebaseService.instance.streamAllScores(),
);

final munqabatNamesProvider = FutureProvider<List<String>>((ref) async {
  final svc = ref.read(munqabatServiceProvider);
  return svc.loadManqabatNames();
});

// ─── Derived ─────────────────────────────────────────────────────────────

final judgesStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseService.instance.streamAllUsers().map(
    (users) => users.where((u) => u.role == UserRole.judge).toList(),
  );
});

// ─── Judge-specific ───────────────────────────────────────────────────────

/// Active sessions assigned to the current judge
final judgeActiveSessionsProvider =
    StreamProvider.family<List<Session>, String>((_, judgeId) {
      return FirebaseService.instance.streamActiveSessionsForJudge(judgeId);
    });

/// All scores ever submitted by this judge
final judgeScoresProvider = StreamProvider.family<List<Score>, String>((
  _,
  judgeId,
) {
  return FirebaseService.instance.streamScoresByJudge(judgeId);
});

/// Live single score: null = not yet submitted
final singleScoreProvider = StreamProvider.family<Score?, ScoreKey>((_, key) {
  return FirebaseService.instance.streamScore(
    key.judgeId,
    key.candidateId,
    key.sessionId,
  );
});

class ScoreKey {
  final String judgeId, candidateId, sessionId;
  const ScoreKey(this.judgeId, this.candidateId, this.sessionId);

  @override
  bool operator ==(Object other) =>
      other is ScoreKey &&
      judgeId == other.judgeId &&
      candidateId == other.candidateId &&
      sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(judgeId, candidateId, sessionId);
}
