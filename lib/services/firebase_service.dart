import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_logger.dart';
import '../models/models.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  // Collection refs
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _candidates => _db.collection('candidates');
  CollectionReference get _sessions => _db.collection('sessions');
  CollectionReference get _scores => _db.collection('scores');

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw FirebaseAuthException(
          code: 'google_sign_in_canceled',
          message: 'Google sign-in was canceled.',
        );
      }

      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await _ensureUserDoc(user);
      }
      return userCredential;
    } catch (e, st) {
      appLogger.e('Google sign-in error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  String? get currentUserId => _auth.currentUser?.uid;

  Future<AppUser?> getCurrentUser() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Future<void> _ensureUserDoc(User user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();
    if (doc.exists) return;
    final appUser = AppUser(
      id: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      role: UserRole.neither,
    );
    await docRef.set(appUser.toMap());
  }

  // ─── Users / Judges ───────────────────────────────────────────────────────

  Stream<List<AppUser>> streamAllUsers() =>
      _users.snapshots().map((s) => s.docs.map(AppUser.fromDoc).toList());

  Future<void> updateUserRole(String userId, UserRole role) =>
      _users.doc(userId).update({'role': role.name});

  // ─── Candidates ───────────────────────────────────────────────────────────

  Stream<List<Candidate>> streamCandidates() => _candidates
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Candidate.fromDoc).toList());

  Future<String> createCandidate(Candidate candidate) async {
    final ref = await _candidates.add(candidate.toMap());
    return ref.id;
  }

  Future<void> updateCandidate(String id, Map<String, dynamic> data) =>
      _candidates.doc(id).update(data);

  Future<Candidate?> getCandidate(String id) async {
    final doc = await _candidates.doc(id).get();
    if (!doc.exists) return null;
    return Candidate.fromDoc(doc);
  }

  // ─── Sessions ─────────────────────────────────────────────────────────────

  Stream<List<Session>> streamSessions() => _sessions
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Session.fromDoc).toList());

  Future<String> createSession(Session session) async {
    final ref = await _sessions.add(session.toMap());
    return ref.id;
  }

  Future<void> updateSession(String id, Map<String, dynamic> data) =>
      _sessions.doc(id).update(data);

  Future<Session?> getSession(String id) async {
    final doc = await _sessions.doc(id).get();
    if (!doc.exists) return null;
    return Session.fromDoc(doc);
  }

  /// Deactivates all other sessions before activating one
  Future<void> setSessionActive(String sessionId) async {
    final batch = _db.batch();
    final all = await _sessions.where('isActive', isEqualTo: true).get();
    for (final doc in all.docs) {
      if (doc.id != sessionId) {
        batch.update(doc.reference, {'isActive': false});
      }
    }
    batch.update(_sessions.doc(sessionId), {'isActive': true});
    await batch.commit();
  }

  /// Checks if all judges have scored all candidates; if so marks session conducted
  Future<void> checkAndCompleteSession(String sessionId) async {
    final sessionDoc = await _sessions.doc(sessionId).get();
    if (!sessionDoc.exists) return;
    final session = Session.fromDoc(sessionDoc);
    if (session.isConducted) return;

    final expectedCount = session.judgeIds.length * session.candidateIds.length;
    if (expectedCount == 0) return;

    final scoresSnap = await _scores
        .where('sessionId', isEqualTo: sessionId)
        .get();

    if (scoresSnap.docs.length >= expectedCount) {
      await _sessions.doc(sessionId).update({
        'isActive': false,
        'isConducted': true,
      });
    }
  }

  // ─── Scores ───────────────────────────────────────────────────────────────

  Stream<List<Score>> streamScoresForCandidate(String candidateId) => _scores
      .where('candidateId', isEqualTo: candidateId)
      .orderBy('submittedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Score.fromDoc).toList());

  Stream<List<Score>> streamScoresForSession(String sessionId) => _scores
      .where('sessionId', isEqualTo: sessionId)
      .snapshots()
      .map((s) => s.docs.map(Score.fromDoc).toList());

    Stream<List<Score>> streamAllScores() => _scores
      .snapshots()
      .map((s) => s.docs.map(Score.fromDoc).toList());

  Future<List<Score>> getScoresForJudge(String judgeId) async {
    final snap = await _scores.where('judgeId', isEqualTo: judgeId).get();
    return snap.docs.map(Score.fromDoc).toList();
  }

  Future<List<Score>> getScoresForJudgeInSessions(
    String judgeId,
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) return [];
    final snap = await _scores
        .where('judgeId', isEqualTo: judgeId)
        .where('sessionId', whereIn: sessionIds)
        .get();
    return snap.docs.map(Score.fromDoc).toList();
  }

  Future<List<String>> getSessionsForJudge(String judgeId) async {
    final snap = await _sessions
        .where('judgeIds', arrayContains: judgeId)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<List<Candidate>> getCandidatesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final futures = ids.map((id) => _candidates.doc(id).get());
    final docs = await Future.wait(futures);
    return docs.where((d) => d.exists).map(Candidate.fromDoc).toList();
  }

  Future<List<AppUser>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final futures = ids.map((id) => _users.doc(id).get());
    final docs = await Future.wait(futures);
    return docs.where((d) => d.exists).map(AppUser.fromDoc).toList();
  }

  Future<bool> scoreExists(
    String judgeId,
    String candidateId,
    String sessionId,
  ) async {
    final id = Score.buildId(judgeId, candidateId, sessionId);
    final doc = await _scores.doc(id).get();
    return doc.exists;
  }

  // ─── Judge-specific ───────────────────────────────────────────────────────

  /// Stream active sessions the judge is assigned to (max 2: one senior, one junior)
  Stream<List<Session>> streamActiveSessionsForJudge(String judgeId) =>
      _sessions
          .where('isActive', isEqualTo: true)
          .where('judgeIds', arrayContains: judgeId)
          .snapshots()
          .map((s) => s.docs.map(Session.fromDoc).toList());

  /// Stream all scores submitted by this judge (for history tab)
  Stream<List<Score>> streamScoresByJudge(String judgeId) => _scores
      .where('judgeId', isEqualTo: judgeId)
      .orderBy('submittedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Score.fromDoc).toList());

  /// Stream a specific score document live (null if not yet submitted)
  Stream<Score?> streamScore(
    String judgeId,
    String candidateId,
    String sessionId,
  ) {
    final id = Score.buildId(judgeId, candidateId, sessionId);
    return _scores
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? Score.fromDoc(d) : null);
  }

  /// Submit a new score — immutable, no updates allowed
  Future<void> submitScore(Score score) async {
    final id = Score.buildId(score.judgeId, score.candidateId, score.sessionId);
    await _scores.doc(id).set(score.toMap());
    await checkAndCompleteSession(score.sessionId);
  }

  /// All scores for a candidate in stages strictly before [currentStage]
  Future<List<Score>> getPreviousStageScores(
    String candidateId,
    int currentStage,
  ) async {
    final snap = await _scores
        .where('candidateId', isEqualTo: candidateId)
        .where('stage', isLessThan: currentStage)
        .get();
    return snap.docs.map(Score.fromDoc).toList();
  }
}
