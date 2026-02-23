import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ScoreEntryScreen extends StatefulWidget {
  final Candidate candidate;
  final Session session;
  final AppUser judge;

  const ScoreEntryScreen({
    super.key,
    required this.candidate,
    required this.session,
    required this.judge,
  });

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  final Map<String, double> _scores = {
    'adaigi': 0,
    'tarz': 0,
    'awaaz': 0,
    'confidence': 0,
    'tazeem': 0,
  };
  final _commentsCtrl = TextEditingController();
  bool _saving = false;

  double get _total => _scores.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Scores',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to submit scores for ${widget.candidate.name}. '
              'This action cannot be undone.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...kScoreCategories.map((cat) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat.label,
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        '${_scores[cat.key]!.toStringAsFixed(0)} / ${cat.maxMarks}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${_total.toStringAsFixed(0)} / 100',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary,
                      fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final score = Score(
        id: Score.buildId(
            widget.judge.id, widget.candidate.id, widget.session.id),
        judgeId: widget.judge.id,
        candidateId: widget.candidate.id,
        sessionId: widget.session.id,
        stage: widget.session.stage,
        isSenior: widget.session.isSenior,
        adaigi: _scores['adaigi']!,
        tarz: _scores['tarz']!,
        awaaz: _scores['awaaz']!,
        confidence: _scores['confidence']!,
        tazeem: _scores['tazeem']!,
        total: _total,
        comments: _commentsCtrl.text.trim(),
        submittedAt: DateTime.now(),
      );
      await FirebaseService.instance.submitScore(score);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to submit: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Score Candidate',
        showBack: true,
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCandidateHeader(),
              const SizedBox(height: 16),
              if (widget.session.stage > 1) ...[
                _PreviousStageSummary(
                    candidateId: widget.candidate.id,
                    currentStage: widget.session.stage),
                const SizedBox(height: 16),
              ],
              _buildScoreSliders(),
              const SizedBox(height: 16),
              _buildTotalCard(),
              const SizedBox(height: 16),
              _buildCommentsField(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmAndSave,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Submit Scores'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateHeader() {
    return AppCard(
      child: Row(
        children: [
          AvatarWidget(
              imageUrl: widget.candidate.imageUrl,
              name: widget.candidate.name,
              radius: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.candidate.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text('S/O ${widget.candidate.fatherName}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    seniorJuniorBadge(widget.candidate.isSenior),
                    const SizedBox(width: 6),
                    Text(widget.candidate.exactAge,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSliders() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'ASSIGN SCORES'),
          const SizedBox(height: 16),
          ...kScoreCategories.map((cat) => _ScoreSlider(
                category: cat,
                value: _scores[cat.key]!,
                onChanged: (v) => setState(() => _scores[cat.key] = v),
              )),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    final pct = _total / 100;
    Color totalColor;
    if (pct >= 0.8) {
      totalColor = AppTheme.success;
    } else if (pct >= 0.6) totalColor = AppTheme.secondary;
    else if (pct >= 0.4) totalColor = AppTheme.warning;
    else totalColor = AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: totalColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: totalColor.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Score',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.textPrimary)),
              Text('Sum of all categories',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          Text(
            '${_total.toStringAsFixed(0)} / 100',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: totalColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsField() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'COMMENTS (Optional)'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _commentsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add any remarks about this candidate...',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Score Slider ─────────────────────────────────────────────────────────────

class _ScoreSlider extends StatelessWidget {
  final ScoreCategory category;
  final double value;
  final ValueChanged<double> onChanged;

  const _ScoreSlider({
    required this.category,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value / category.maxMarks;
    Color color;
    if (pct >= 0.8) {
      color = AppTheme.success;
    } else if (pct >= 0.6) color = AppTheme.secondary;
    else if (pct >= 0.4) color = AppTheme.warning;
    else color = AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  '${value.toStringAsFixed(0)} / ${category.maxMarks}',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              overlayColor: color.withOpacity(0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: category.maxMarks.toDouble(),
              divisions: category.maxMarks,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Previous stage summary (for stage > 1) ───────────────────────────────────

class _PreviousStageSummary extends StatelessWidget {
  final String candidateId;
  final int currentStage;

  const _PreviousStageSummary(
      {required this.candidateId, required this.currentStage});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Score>>(
      future: FirebaseService.instance
          .getPreviousStageScores(candidateId, currentStage),
      builder: (_, snap) {
        final scores = snap.data ?? [];
        if (scores.isEmpty) return const SizedBox.shrink();

        // Group by stage
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
                final avg = stageScores.fold<double>(0, (a, s) => a + s.total) /
                    stageScores.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      stageBadge(e.key),
                      const Spacer(),
                      Text(
                        'Avg: ${avg.toStringAsFixed(1)}/100',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.secondary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${stageScores.length} judges)',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
