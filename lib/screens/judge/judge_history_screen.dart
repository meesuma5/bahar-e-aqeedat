import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/app_logger.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

enum _HistorySortBy { name, date, averageScore }

class JudgeHistoryScreen extends ConsumerStatefulWidget {
  final AppUser judge;
  const JudgeHistoryScreen({super.key, required this.judge});

  @override
  ConsumerState<JudgeHistoryScreen> createState() => _JudgeHistoryScreenState();
}

class _JudgeHistoryScreenState extends ConsumerState<JudgeHistoryScreen> {
  _HistorySortBy _sortBy = _HistorySortBy.date;
  DateTime? _filterDate;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final scoresAsync = ref.watch(judgeScoresProvider(widget.judge.id));

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Grading History',
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(judgeScoresProvider(widget.judge.id).future),
              child: scoresAsync.when(
                loading: () => _buildScrollablePlaceholder(
                  const CircularProgressIndicator(),
                ),
                error: (e, _) {
                  appLogger.e('Judge history load error', error: e);
                  return _buildScrollableMessage(
                    'Unable to load history. Please try again.',
                  );
                },
                data: (scores) {
                  // Exclude current-session scores (only past sessions)
                  return _buildScoreList(scores);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search candidates...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
              ),
            ),
          ),
          if (_filterDate != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _filterDate = null),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd MMM').format(_filterDate!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.close, size: 14, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrollablePlaceholder(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 120),
      children: [Center(child: child)],
    );
  }

  Widget _buildScrollableMessage(String message) {
    return _buildScrollablePlaceholder(Text(message));
  }

  Widget _buildScoreList(List<Score> allScores) {
    // Group by candidateId — one card per candidate (latest score per candidate)
    final Map<String, Score> latestByCandidate = {};
    for (final score in allScores) {
      final existing = latestByCandidate[score.candidateId];
      if (existing == null || score.submittedAt.isAfter(existing.submittedAt)) {
        latestByCandidate[score.candidateId] = score;
      }
    }

    // Collect all scores per candidate for average calculation
    final Map<String, List<Score>> allByCandidate = {};
    for (final score in allScores) {
      allByCandidate.putIfAbsent(score.candidateId, () => []).add(score);
    }

    return FutureBuilder<List<Candidate>>(
      future: FirebaseService.instance.getCandidatesByIds(
        latestByCandidate.keys.toList(),
      ),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var candidates = snap.data ?? [];

        // Filter by search
        if (_search.isNotEmpty) {
          candidates = candidates
              .where(
                (c) =>
                    c.name.toLowerCase().contains(_search.toLowerCase()) ||
                    c.fatherName.toLowerCase().contains(_search.toLowerCase()),
              )
              .toList();
        }

        // Filter by date
        if (_filterDate != null) {
          candidates = candidates.where((c) {
            final score = latestByCandidate[c.id];
            if (score == null) return false;
            final d = score.submittedAt;
            return d.year == _filterDate!.year &&
                d.month == _filterDate!.month &&
                d.day == _filterDate!.day;
          }).toList();
        }

        // Sort
        switch (_sortBy) {
          case _HistorySortBy.name:
            candidates.sort((a, b) => a.name.compareTo(b.name));
            break;
          case _HistorySortBy.date:
            candidates.sort((a, b) {
              final sa = latestByCandidate[a.id]?.submittedAt ?? DateTime(0);
              final sb = latestByCandidate[b.id]?.submittedAt ?? DateTime(0);
              return sb.compareTo(sa);
            });
            break;
          case _HistorySortBy.averageScore:
            candidates.sort((a, b) {
              double avgA(String id) {
                final scores = allByCandidate[id] ?? [];
                return scores.isEmpty
                    ? 0
                    : scores.fold<double>(0, (x, s) => x + s.total) /
                          scores.length;
              }

              return avgA(b.id).compareTo(avgA(a.id));
            });
            break;
        }

        if (candidates.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 80),
            children: const [
              EmptyState(
                icon: Icons.history_outlined,
                title: 'No History Yet',
                subtitle: 'Candidates you have scored\nwill appear here.',
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: candidates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final c = candidates[i];
            final scores = allByCandidate[c.id] ?? [];
            return _HistoryCandidateCard(
              candidate: c,
              scores: scores,
              judgeId: widget.judge.id,
            );
          },
        );
      },
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort & Filter',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'SORT BY'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _HistorySortBy.values.map((s) {
                  final labels = {
                    _HistorySortBy.name: 'Name',
                    _HistorySortBy.date: 'Date',
                    _HistorySortBy.averageScore: 'Avg Score',
                  };
                  return FilterChip(
                    label: Text(labels[s]!),
                    selected: _sortBy == s,
                    onSelected: (_) =>
                        setModal(() => setState(() => _sortBy = s)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'FILTER BY DATE'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _filterDate != null
                      ? DateFormat('dd MMM yyyy').format(_filterDate!)
                      : 'Pick a date',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: _filterDate ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setModal(() => setState(() => _filterDate = picked));
                  }
                },
              ),
              if (_filterDate != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      setModal(() => setState(() => _filterDate = null)),
                  child: const Text('Clear date filter'),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── History candidate card ───────────────────────────────────────────────────

class _HistoryCandidateCard extends StatelessWidget {
  final Candidate candidate;
  final List<Score> scores;
  final String judgeId;

  const _HistoryCandidateCard({
    required this.candidate,
    required this.scores,
    required this.judgeId,
  });

  @override
  Widget build(BuildContext context) {
    // Average across all scores this judge gave this candidate
    final avg = scores.isEmpty
        ? 0.0
        : scores.fold<double>(0, (a, s) => a + s.total) / scores.length;

    // Latest session score
    final latest = scores.isNotEmpty
        ? scores.reduce((a, b) => a.submittedAt.isAfter(b.submittedAt) ? a : b)
        : null;

    return AppCard(
      onTap: () => _showDetailSheet(context, latest),
      child: Row(
        children: [
          AvatarWidget(
            imageUrl: candidate.imageUrl,
            name: candidate.name,
            radius: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'S/O ${candidate.fatherName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    seniorJuniorBadge(candidate.isSenior),
                    const SizedBox(width: 6),
                    if (scores.length > 1)
                      Text(
                        '${scores.length} sessions',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Avg ${avg.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (latest != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yy').format(latest.submittedAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, Score? latest) {
    if (latest == null) return;

    // Find the session for the latest score
    FirebaseService.instance.getSession(latest.sessionId).then((session) {
      if (session == null || !context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.97,
          builder: (_, ctrl) => _HistoryDetailSheet(
            candidate: candidate,
            scores: scores,
            session: session,
            judgeId: judgeId,
            scrollController: ctrl,
          ),
        ),
      );
    });
  }
}

// ─── History detail bottom sheet ─────────────────────────────────────────────

class _HistoryDetailSheet extends StatelessWidget {
  final Candidate candidate;
  final List<Score> scores;
  final Session session;
  final String judgeId;
  final ScrollController scrollController;

  const _HistoryDetailSheet({
    required this.candidate,
    required this.scores,
    required this.session,
    required this.judgeId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Group scores by stage
    final byStage = <int, Score>{};
    for (final s in scores) {
      // One score per stage from this judge
      byStage[s.stage] = s;
    }

    // Fetch previous-stage scores from all judges for averages
    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                ...byStage.entries.map(
                  (e) => _buildStageBlock(context, e.key, e.value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final overallAvg = scores.isEmpty
        ? 0.0
        : scores.fold<double>(0, (a, s) => a + s.total) / scores.length;
    return Row(
      children: [
        AvatarWidget(
          imageUrl: candidate.imageUrl,
          name: candidate.name,
          radius: 30,
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
              const SizedBox(height: 4),
              Text(
                'Overall avg across all stages: ${overallAvg.toStringAsFixed(1)}/100',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageBlock(BuildContext context, int stage, Score myScore) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        stageBadge(stage),
        const SizedBox(height: 10),
        // My score breakdown
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionHeader(title: 'YOUR SCORE'),
                  Text(
                    '${myScore.total.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...kScoreCategories.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ScoreBar(
                    label: cat.label,
                    value: scoreValue(myScore, cat.key),
                    maxValue: cat.maxMarks.toDouble(),
                  ),
                ),
              ),
              if (myScore.comments.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  '"${myScore.comments}"',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        // All-judge average for this stage
        const SizedBox(height: 10),
        _AllJudgeStageAverage(candidateId: candidate.id, stage: stage),
      ],
    );
  }
}

class _AllJudgeStageAverage extends StatelessWidget {
  final String candidateId;
  final int stage;

  const _AllJudgeStageAverage({required this.candidateId, required this.stage});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Score>>(
      future: FirebaseService.instance.getPreviousStageScores(
        candidateId,
        stage + 1,
      ),
      builder: (_, snap) {
        final all = (snap.data ?? []).where((s) => s.stage == stage).toList();
        if (all.isEmpty) return const SizedBox.shrink();

        final avg = all.fold<double>(0, (a, s) => a + s.total) / all.length;
        return AppCard(
          color: AppTheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionHeader(title: 'ALL JUDGES AVG (${all.length} judges)'),
                  Text(
                    '${avg.toStringAsFixed(1)}/100',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...kScoreCategories.map((cat) {
                final catAvg =
                    all.fold<double>(0, (a, s) => a + scoreValue(s, cat.key)) /
                    all.length;
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
            ],
          ),
        );
      },
    );
  }
}
