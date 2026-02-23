import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ScoreViewScreen extends StatelessWidget {
  final Candidate candidate;
  final Session session;
  final Score myScore;
  final String judgeId;

  const ScoreViewScreen({
    super.key,
    required this.candidate,
    required this.session,
    required this.myScore,
    required this.judgeId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Score Details',
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCandidateHeader(context),
            const SizedBox(height: 16),
            _buildReadOnlyScores(),
            const SizedBox(height: 16),
            if (session.stage > 1) ...[
              _PreviousStageSummaryCard(
                  candidateId: candidate.id, currentStage: session.stage),
              const SizedBox(height: 16),
            ],
            if (myScore.comments.isNotEmpty) _buildCommentsCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateHeader(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          AvatarWidget(
              imageUrl: candidate.imageUrl, name: candidate.name, radius: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text('S/O ${candidate.fatherName}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Row(children: [
                  seniorJuniorBadge(candidate.isSenior),
                  const SizedBox(width: 6),
                  Text(candidate.exactAge,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyScores() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: 'YOUR SCORES'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${myScore.total.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...kScoreCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReadOnlyScoreRow(
                  label: cat.label,
                  value: scoreValue(myScore, cat.key),
                  maxValue: cat.maxMarks.toDouble(),
                ),
              )),
          const Divider(height: 8),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                '${myScore.total.toStringAsFixed(0)} / 100',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: AppTheme.info),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scores have been submitted and cannot be changed.',
                    style: TextStyle(fontSize: 12, color: AppTheme.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'YOUR COMMENTS'),
          const SizedBox(height: 10),
          Text(
            myScore.comments,
            style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyScoreRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;

  const _ReadOnlyScoreRow(
      {required this.label, required this.value, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final pct = (value / maxValue).clamp(0.0, 1.0);
    Color color;
    if (pct >= 0.8) {
      color = AppTheme.success;
    } else if (pct >= 0.6) color = AppTheme.secondary;
    else if (pct >= 0.4) color = AppTheme.warning;
    else color = AppTheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
            Text(
              '${value.toStringAsFixed(0)} / ${maxValue.toInt()}',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _PreviousStageSummaryCard extends StatelessWidget {
  final String candidateId;
  final int currentStage;

  const _PreviousStageSummaryCard(
      {required this.candidateId, required this.currentStage});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Score>>(
      future: FirebaseService.instance
          .getPreviousStageScores(candidateId, currentStage),
      builder: (_, snap) {
        final scores = snap.data ?? [];
        if (scores.isEmpty) return const SizedBox.shrink();

        final byStage = <int, List<Score>>{};
        for (final s in scores) {
          byStage.putIfAbsent(s.stage, () => []).add(s);
        }

        return AppCard(
          color: AppTheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'PREVIOUS STAGE AVERAGES'),
              const SizedBox(height: 12),
              ...byStage.entries.map((e) {
                final stageScores = e.value;
                final overallAvg =
                    stageScores.fold<double>(0, (a, s) => a + s.total) /
                        stageScores.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        stageBadge(e.key),
                        const Spacer(),
                        Text(
                          'All judges avg: ${overallAvg.toStringAsFixed(1)}/100',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...kScoreCategories.map((cat) {
                      final catAvg = stageScores.fold<double>(
                              0, (a, s) => a + scoreValue(s, cat.key)) /
                          stageScores.length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ScoreBar(
                          label: cat.label,
                          value: catAvg,
                          maxValue: cat.maxMarks.toDouble(),
                          color: AppTheme.textSecondary,
                        ),
                      );
                    }),
                    if (byStage.keys.last != e.key) const Divider(height: 20),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
