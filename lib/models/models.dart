import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Enums ──────────────────────────────────────────────────────────────────

enum UserRole { admin, judge, neither }

extension UserRoleExt on UserRole {
  String get label => name[0].toUpperCase() + name.substring(1);
  static UserRole fromString(String s) =>
      UserRole.values.firstWhere((e) => e.name == s, orElse: () => UserRole.neither);
}

enum CandidateCategory { junior, senior, ineligible }

// ─── AppUser ────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      role: UserRoleExt.fromString(d['role'] ?? 'neither'),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role.name,
      };

  AppUser copyWith({String? name, String? email, UserRole? role}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
      );
}

// ─── Candidate ───────────────────────────────────────────────────────────────

class Candidate {
  final String id;
  final String name;
  final String fatherName;
  final DateTime dob;
  final String imageUrl;
  final bool isSenior;
  final int stage;
  final String createdBy;
  final DateTime createdAt;

  const Candidate({
    required this.id,
    required this.name,
    required this.fatherName,
    required this.dob,
    required this.imageUrl,
    required this.isSenior,
    required this.stage,
    required this.createdBy,
    required this.createdAt,
  });

  /// The fixed reference date used for all age calculations
  static final DateTime ageReferenceDate = DateTime(2025, 12, 13);

  /// Returns age in years as of Dec 13, 2025
  int get ageInYears {
    final ref = ageReferenceDate;
    int years = ref.year - dob.year;
    if (ref.month < dob.month || (ref.month == dob.month && ref.day < dob.day)) {
      years--;
    }
    return years;
  }

  /// Exact age as of Dec 13, 2025: X yrs Y mos Z days
  String get exactAge {
    final ref = ageReferenceDate;
    int years = ref.year - dob.year;
    int months = ref.month - dob.month;
    int days = ref.day - dob.day;
    if (days < 0) {
      months--;
      days += DateTime(ref.year, ref.month, 0).day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    return '$years yrs $months mos $days days';
  }

  static CandidateCategory categoryFromDob(DateTime dob) {
    final ref = ageReferenceDate;
    int years = ref.year - dob.year;
    if (ref.month < dob.month || (ref.month == dob.month && ref.day < dob.day)) {
      years--;
    }
    if (years < 15) return CandidateCategory.junior;
    if (years < 26) return CandidateCategory.senior;
    return CandidateCategory.ineligible;
  }

  factory Candidate.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Candidate(
      id: doc.id,
      name: d['name'] ?? '',
      fatherName: d['fatherName'] ?? '',
      dob: (d['dob'] as Timestamp).toDate(),
      imageUrl: d['imageUrl'] ?? '',
      isSenior: d['isSenior'] ?? false,
      stage: d['stage'] ?? 1,
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'fatherName': fatherName,
        'dob': Timestamp.fromDate(dob),
        'imageUrl': imageUrl,
        'isSenior': isSenior,
        'stage': stage,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Candidate copyWith({
    String? fatherName,
    DateTime? dob,
    String? imageUrl,
    bool? isSenior,
    int? stage,
  }) =>
      Candidate(
        id: id,
        name: name,
        fatherName: fatherName ?? this.fatherName,
        dob: dob ?? this.dob,
        imageUrl: imageUrl ?? this.imageUrl,
        isSenior: isSenior ?? this.isSenior,
        stage: stage ?? this.stage,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

// ─── Session ─────────────────────────────────────────────────────────────────

class Session {
  final String id;
  final DateTime date;
  final int stage; // 1=Prelims, 2=Semis, 3=Finals
  final bool isSenior;
  final bool isActive;
  final bool isConducted;
  final List<String> candidateIds;
  final List<String> judgeIds;
  final Map<String, List<String>> candidateManqabatSelections;
  final Map<String, String> candidateRecitationSelections;
  final String createdBy;
  final DateTime createdAt;

  const Session({
    required this.id,
    required this.date,
    required this.stage,
    required this.isSenior,
    required this.isActive,
    required this.isConducted,
    required this.candidateIds,
    required this.judgeIds,
    required this.candidateManqabatSelections,
    required this.candidateRecitationSelections,
    required this.createdBy,
    required this.createdAt,
  });

  static String stageLabel(int stage) {
    const labels = {1: 'Preliminaries', 2: 'Semi Finals', 3: 'Finals'};
    return labels[stage] ?? 'Stage $stage';
  }

  factory Session.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final manqabatSelections = <String, List<String>>{};
    final rawManqabatSelections =
        Map<String, dynamic>.from(d['candidateManqabatSelections'] ?? {});
    rawManqabatSelections.forEach((key, value) {
      if (value is List) {
        manqabatSelections[key] = value.map((e) => e.toString()).toList();
      }
    });

    return Session(
      id: doc.id,
      date: (d['date'] as Timestamp).toDate(),
      stage: d['stage'] ?? 1,
      isSenior: d['isSenior'] ?? false,
      isActive: d['isActive'] ?? false,
      isConducted: d['isConducted'] ?? false,
      candidateIds: List<String>.from(d['candidateIds'] ?? []),
      judgeIds: List<String>.from(d['judgeIds'] ?? []),
      candidateManqabatSelections: manqabatSelections,
      candidateRecitationSelections:
          Map<String, String>.from(d['candidateRecitationSelections'] ?? {}),
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'stage': stage,
        'isSenior': isSenior,
        'isActive': isActive,
        'isConducted': isConducted,
        'candidateIds': candidateIds,
        'judgeIds': judgeIds,
        'candidateManqabatSelections': candidateManqabatSelections,
        'candidateRecitationSelections': candidateRecitationSelections,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Session copyWith({
    DateTime? date,
    int? stage,
    bool? isSenior,
    bool? isActive,
    bool? isConducted,
    List<String>? candidateIds,
    List<String>? judgeIds,
    Map<String, List<String>>? candidateManqabatSelections,
    Map<String, String>? candidateRecitationSelections,
  }) =>
      Session(
        id: id,
        date: date ?? this.date,
        stage: stage ?? this.stage,
        isSenior: isSenior ?? this.isSenior,
        isActive: isActive ?? this.isActive,
        isConducted: isConducted ?? this.isConducted,
        candidateIds: candidateIds ?? this.candidateIds,
        judgeIds: judgeIds ?? this.judgeIds,
        candidateManqabatSelections:
            candidateManqabatSelections ?? this.candidateManqabatSelections,
        candidateRecitationSelections:
            candidateRecitationSelections ?? this.candidateRecitationSelections,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

// ─── Score ───────────────────────────────────────────────────────────────────

class Score {
  final String id; // {judgeId}_{candidateId}_{sessionId}
  final String judgeId;
  final String candidateId;
  final String sessionId;
  final int stage;
  final bool isSenior;

  final double adaigi;
  final double tarz;
  final double awaaz;
  final double confidence;
  final double tazeem;
  final double total;

  final String comments;
  final DateTime submittedAt;

  const Score({
    required this.id,
    required this.judgeId,
    required this.candidateId,
    required this.sessionId,
    required this.stage,
    required this.isSenior,
    required this.adaigi,
    required this.tarz,
    required this.awaaz,
    required this.confidence,
    required this.tazeem,
    required this.total,
    required this.comments,
    required this.submittedAt,
  });

  static String buildId(String judgeId, String candidateId, String sessionId) =>
      '${judgeId}_${candidateId}_$sessionId';

  factory Score.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Score(
      id: doc.id,
      judgeId: d['judgeId'] ?? '',
      candidateId: d['candidateId'] ?? '',
      sessionId: d['sessionId'] ?? '',
      stage: d['stage'] ?? 1,
      isSenior: d['isSenior'] ?? false,
      adaigi: (d['adaigi'] ?? 0).toDouble(),
      tarz: (d['tarz'] ?? 0).toDouble(),
      awaaz: (d['awaaz'] ?? 0).toDouble(),
      confidence: (d['confidence'] ?? 0).toDouble(),
      tazeem: (d['tazeem'] ?? 0).toDouble(),
      total: (d['total'] ?? 0).toDouble(),
      comments: d['comments'] ?? '',
      submittedAt: (d['submittedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'judgeId': judgeId,
        'candidateId': candidateId,
        'sessionId': sessionId,
        'stage': stage,
        'isSenior': isSenior,
        'adaigi': adaigi,
        'tarz': tarz,
        'awaaz': awaaz,
        'confidence': confidence,
        'tazeem': tazeem,
        'total': total,
        'comments': comments,
        'submittedAt': Timestamp.fromDate(submittedAt),
      };
}

// ─── ScoreCategory helper ─────────────────────────────────────────────────────

class ScoreCategory {
  final String key;
  final String label;
  final int maxMarks;

  const ScoreCategory({required this.key, required this.label, required this.maxMarks});
}

const kScoreCategories = [
  ScoreCategory(key: 'adaigi', label: 'Adaigi', maxMarks: 20),
  ScoreCategory(key: 'tarz', label: 'Tarz', maxMarks: 20),
  ScoreCategory(key: 'awaaz', label: 'Awaaz', maxMarks: 20),
  ScoreCategory(key: 'confidence', label: 'Confidence', maxMarks: 20),
  ScoreCategory(key: 'tazeem', label: 'Tazeem', maxMarks: 20),
];

double scoreValue(Score s, String key) {
  switch (key) {
    case 'adaigi': return s.adaigi;
    case 'tarz': return s.tarz;
    case 'awaaz': return s.awaaz;
    case 'confidence': return s.confidence;
    case 'tazeem': return s.tazeem;
    default: return 0;
  }
}
