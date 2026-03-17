import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../services/firebase_service.dart';
import '../../../services/app_logger.dart';
import '../../../services/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';
import 'candidate_form_screen.dart';

class CandidateDetailSheet extends ConsumerWidget {
  final Candidate candidate;
  const CandidateDetailSheet({super.key, required this.candidate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(candidateScoresProvider(candidate.id));
    final sessionsAsync = ref.watch(sessionsStreamProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Column(
        children: [
          _buildHandleAndHeader(context),
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfo(),
                  const SizedBox(height: 20),
                  scoresAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) {
                      appLogger.e('Candidate scores load error', error: e);
                      return const Text('Unable to load scores.');
                    },
                    data: (scores) => sessionsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, __) {
                        appLogger.e('Sessions load error', error: e);
                        return const SizedBox.shrink();
                      },
                      data: (sessions) =>
                          _buildScoresSection(context, scores, sessions),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandleAndHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AvatarWidget(
                imageUrl: candidate.imageUrl,
                name: candidate.name,
                radius: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'S/O ${candidate.fatherName}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CandidateFormScreen(candidate: candidate),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'PROFILE'),
          const SizedBox(height: 12),
          InfoRow(
            icon: Icons.cake_outlined,
            label: 'Date of Birth',
            value: DateFormat('dd MMM yyyy').format(candidate.dob),
          ),
          InfoRow(
            icon: Icons.access_time_outlined,
            label: 'Age',
            value: candidate.exactAge,
          ),
          InfoRow(
            icon: Icons.emoji_events_outlined,
            label: 'Current Stage',
            value: Session.stageLabel(candidate.stage),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              seniorJuniorBadge(candidate.isSenior),
              const SizedBox(width: 8),
              stageBadge(candidate.stage),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoresSection(
    BuildContext context,
    List<Score> scores,
    List<Session> sessions,
  ) {
    if (scores.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No scores recorded yet',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      );
    }

    // Group scores by session
    final scoresBySession = <String, List<Score>>{};
    for (final s in scores) {
      scoresBySession.putIfAbsent(s.sessionId, () => []).add(s);
    }

    final sessionMap = {for (final s in sessions) s.id: s};
    final orderedSessionIds = scoresBySession.keys.toList()
      ..sort((a, b) {
        final aDate = sessionMap[a]?.date;
        final bDate = sessionMap[b]?.date;
        if (aDate == null && bDate == null) return a.compareTo(b);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverallStats(scores),
        const SizedBox(height: 16),
        ...orderedSessionIds.map(
          (sessionId) => _buildSessionScores(
            context,
            sessionId,
            scoresBySession[sessionId]!,
            sessionMap,
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStats(List<Score> scores) {
    final totalSum = scores.fold<double>(0, (a, s) => a + s.total);
    final totalMax = scores.length * 100.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'OVERALL TOTALS'),
          const SizedBox(height: 12),
          ...kScoreCategories.map((cat) {
            final total = scores.fold<double>(
              0,
              (a, s) => a + scoreValue(s, cat.key),
            );
            final maxValue = scores.length * cat.maxMarks.toDouble();
            return ScoreBar(label: cat.label, value: total, maxValue: maxValue);
          }),
          const Divider(height: 20),
          ScoreBar(
            label: 'Overall',
            value: totalSum,
            maxValue: totalMax,
            color: AppTheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionScores(
    BuildContext context,
    String sessionId,
    List<Score> sessionScores,
    Map<String, Session> sessionMap,
  ) {
    final session = sessionMap[sessionId];

    // Total per category for this session
    final categoryTotals = {
      for (final cat in kScoreCategories)
        cat.key: sessionScores.fold<double>(
          0,
          (a, s) => a + scoreValue(s, cat.key),
        ),
    };
    final sessionTotal = sessionScores.fold<double>(0, (a, s) => a + s.total);
    final sessionMax = sessionScores.length * 100.0;

    final stage = session?.stage ?? sessionScores.first.stage;
    final sessionTitle = session == null
        ? 'Session'
        : 'Session • ${DateFormat('dd MMM yyyy').format(session.date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(sessionTitle, style: Theme.of(context).textTheme.titleMedium),
            stageBadge(stage),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'SESSION TOTALS'),
              const SizedBox(height: 10),
              ...kScoreCategories.map((cat) {
                final maxValue = sessionScores.length * cat.maxMarks.toDouble();
                return ScoreBar(
                  label: cat.label,
                  value: categoryTotals[cat.key]!,
                  maxValue: maxValue,
                );
              }),
              const Divider(height: 16),
              ScoreBar(
                label: 'Session Total',
                value: sessionTotal,
                maxValue: sessionMax,
                color: AppTheme.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Per-judge scores
        ...sessionScores.map((score) => _buildJudgeScore(score)),
      ],
    );
  }

  Widget _buildJudgeScore(Score score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FutureBuilder<List<AppUser>>(
        future: FirebaseService.instance.getUsersByIds([score.judgeId]),
        builder: (_, snap) {
          final judgeName = snap.data?.firstOrNull?.name ?? 'Judge';
          return AppCard(
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AvatarWidget(
                          imageUrl: null,
                          name: judgeName,
                          radius: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          judgeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${score.total.toStringAsFixed(0)}/100',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...kScoreCategories.map(
                  (cat) => ScoreBar(
                    label: cat.label,
                    value: scoreValue(score, cat.key),
                    maxValue: cat.maxMarks.toDouble(),
                  ),
                ),
                if (score.comments.isNotEmpty) ...[
                  const Divider(height: 16),
                  Text(
                    score.comments,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
