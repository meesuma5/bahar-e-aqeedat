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
import 'candidate_detail_sheet.dart';

enum _SortBy { name, age, sessionDate, totalScore }

enum _GroupBy { none, category, session, stageCategory }

class CandidatesScreen extends ConsumerStatefulWidget {
  const CandidatesScreen({super.key});

  @override
  ConsumerState<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends ConsumerState<CandidatesScreen> {
  _SortBy _sortBy = _SortBy.name;
  _GroupBy _groupBy = _GroupBy.none;
  String _search = '';
  bool _topOnly = false;
  final Map<int, int> _topPerStage = {1: 10, 2: 10, 3: 10};

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(candidatesStreamProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final scoresAsync = ref.watch(scoresStreamProvider);
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Candidates',
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseService.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(candidatesStreamProvider.future),
              child: candidatesAsync.when(
                loading: () => _buildScrollablePlaceholder(
                  const CircularProgressIndicator(),
                ),
                error: (e, _) {
                  appLogger.e('Candidates load error', error: e);
                  return _buildScrollableMessage(
                    'Unable to load candidates. Please try again.',
                  );
                },
                data: (candidates) {
                  final totalsByCandidate = _totalsByCandidate(
                    scoresAsync.value,
                  );
                  final totalsByCandidateStage = _totalsByCandidateStage(
                    scoresAsync.value,
                  );
                  final totalsBySessionCandidate = _totalsBySessionCandidate(
                    scoresAsync.value,
                  );
                  final filtered = _filter(candidates, scoresAsync.value);
                  if (filtered.isEmpty) {
                    return _buildScrollableEmptyState(
                      const EmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'No Candidates Found',
                        subtitle: 'Try adjusting filters or add a candidate',
                      ),
                    );
                  }
                  return _buildList(
                    filtered,
                    sessionsAsync,
                    totalsByCandidate,
                    totalsByCandidateStage,
                    totalsBySessionCandidate,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'candidatesFab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CandidateFormScreen()),
        ),
        child: const Icon(Icons.person_add_outlined),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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

  Widget _buildScrollableEmptyState(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 80),
      children: [child],
    );
  }

  List<Candidate> _filter(List<Candidate> all, List<Score>? allScores) {
    var list = all.where((c) {
      if (_search.isEmpty) return true;
      return c.name.toLowerCase().contains(_search.toLowerCase()) ||
          c.fatherName.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    final totalsByCandidateStage = <String, Map<int, double>>{};
    final totalsByCandidate = <String, double>{};
    if (allScores != null) {
      for (final score in allScores) {
        totalsByCandidate.update(
          score.candidateId,
          (value) => value + score.total,
          ifAbsent: () => score.total,
        );
        final stageTotals = totalsByCandidateStage.putIfAbsent(
          score.candidateId,
          () => <int, double>{},
        );
        stageTotals.update(
          score.stage,
          (value) => value + score.total,
          ifAbsent: () => score.total,
        );
      }
    }

    if (_topOnly) {
      list = _topByStageCategory(list, totalsByCandidateStage);
    }

    switch (_sortBy) {
      case _SortBy.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortBy.age:
        list.sort((a, b) => a.dob.compareTo(b.dob));
        break;
      case _SortBy.sessionDate:
        list.sort((a, b) => a.stage.compareTo(b.stage));
        break;
      case _SortBy.totalScore:
        list.sort((a, b) {
          final totalA = totalsByCandidate[a.id] ?? 0;
          final totalB = totalsByCandidate[b.id] ?? 0;
          final cmp = totalB.compareTo(totalA);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
        });
        break;
    }
    return list;
  }

  Map<String, double> _totalsByCandidate(List<Score>? allScores) {
    final totals = <String, double>{};
    if (allScores == null) return totals;
    for (final score in allScores) {
      totals.update(
        score.candidateId,
        (value) => value + score.total,
        ifAbsent: () => score.total,
      );
    }
    return totals;
  }

  Map<String, Map<String, double>> _totalsBySessionCandidate(
    List<Score>? allScores,
  ) {
    final totals = <String, Map<String, double>>{};
    if (allScores == null) return totals;
    for (final score in allScores) {
      final perCandidate = totals.putIfAbsent(
        score.sessionId,
        () => <String, double>{},
      );
      perCandidate.update(
        score.candidateId,
        (value) => value + score.total,
        ifAbsent: () => score.total,
      );
    }
    return totals;
  }

  Map<String, Map<int, double>> _totalsByCandidateStage(
    List<Score>? allScores,
  ) {
    final totals = <String, Map<int, double>>{};
    if (allScores == null) return totals;
    for (final score in allScores) {
      final perStage = totals.putIfAbsent(
        score.candidateId,
        () => <int, double>{},
      );
      perStage.update(
        score.stage,
        (value) => value + score.total,
        ifAbsent: () => score.total,
      );
    }
    return totals;
  }

  List<Candidate> _topByStageCategory(
    List<Candidate> candidates,
    Map<String, Map<int, double>> totalsByCandidateStage,
  ) {
    final grouped = <String, List<Candidate>>{};
    for (final candidate in candidates) {
      final key = '${candidate.stage}-${candidate.isSenior}';
      grouped.putIfAbsent(key, () => []).add(candidate);
    }

    final result = <Candidate>[];
    final stageOrder =
        grouped.keys.map((k) => int.parse(k.split('-').first)).toSet().toList()
          ..sort();

    for (final stage in stageOrder) {
      for (final isSenior in [true, false]) {
        final key = '$stage-$isSenior';
        final group = grouped[key];
        if (group == null || group.isEmpty) continue;
        group.sort((a, b) {
          final totalA = totalsByCandidateStage[a.id]?[a.stage] ?? 0;
          final totalB = totalsByCandidateStage[b.id]?[b.stage] ?? 0;
          final cmp = totalB.compareTo(totalA);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
        });
        final limit = _topPerStage[stage] ?? 15;
        result.addAll(group.take(limit));
      }
    }

    return result;
  }

  Widget _buildList(
    List<Candidate> candidates,
    AsyncValue<List<Session>> sessionsAsync,
    Map<String, double> totalsByCandidate,
    Map<String, Map<int, double>> totalsByCandidateStage,
    Map<String, Map<String, double>> totalsBySessionCandidate,
  ) {
    if (_groupBy == _GroupBy.none) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: candidates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _CandidateCard(
          candidate: candidates[i],
          totalScore: totalsByCandidate[candidates[i].id],
        ),
      );
    }

    if (_groupBy == _GroupBy.session) {
      final sessions = sessionsAsync.value;
      if (sessions == null) {
        return _buildScrollablePlaceholder(const Text('Loading sessions...'));
      }

      final sortedSessions = [...sessions]
        ..sort((a, b) => b.date.compareTo(a.date));

      final sessionByCandidate = <String, Session>{};
      for (final session in sortedSessions) {
        for (final candidateId in session.candidateIds) {
          sessionByCandidate.putIfAbsent(candidateId, () => session);
        }
      }

      final grouped = <Session?, List<Candidate>>{};
      for (final candidate in candidates) {
        final session = sessionByCandidate[candidate.id];
        grouped.putIfAbsent(session, () => []).add(candidate);
      }

      final groups = grouped.entries.toList()
        ..sort((a, b) {
          if (a.key == null && b.key == null) return 0;
          if (a.key == null) return 1;
          if (b.key == null) return -1;
          return b.key!.date.compareTo(a.key!.date);
        });

      for (final entry in groups) {
        final sessionId = entry.key?.id;
        final sessionTotals = sessionId == null
            ? const <String, double>{}
            : (totalsBySessionCandidate[sessionId] ?? const <String, double>{});
        entry.value.sort((a, b) {
          final scoreA = sessionTotals[a.id] ?? 0;
          final scoreB = sessionTotals[b.id] ?? 0;
          final cmp = scoreB.compareTo(scoreA);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
        });
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          for (final entry in groups) ...[
            _sessionGroupHeader(entry.key, entry.value.length),
            const SizedBox(height: 8),
            ...entry.value.map((c) {
              final sessionId = entry.key?.id;
              final sessionScore = sessionId == null
                  ? null
                  : totalsBySessionCandidate[sessionId]?[c.id];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CandidateCard(candidate: c, totalScore: sessionScore),
              );
            }),
          ],
        ],
      );
    }

    if (_groupBy == _GroupBy.stageCategory) {
      final stages = candidates.map((c) => c.stage).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          for (final stage in stages) ...[
            _stageHeader(stage),
            const SizedBox(height: 8),
            _categoryBlock(
              candidates.where((c) => c.stage == stage && c.isSenior).toList(),
              'Senior',
              AppTheme.seniorBadge,
              totalsByCandidateStage,
              stage,
            ),
            const SizedBox(height: 8),
            _categoryBlock(
              candidates.where((c) => c.stage == stage && !c.isSenior).toList(),
              'Junior',
              AppTheme.juniorBadge,
              totalsByCandidateStage,
              stage,
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    final seniors = candidates.where((c) => c.isSenior).toList();
    final juniors = candidates.where((c) => !c.isSenior).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        if (seniors.isNotEmpty) ...[
          _groupHeader('Senior', AppTheme.seniorBadge, seniors.length),
          const SizedBox(height: 8),
          ...seniors.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CandidateCard(
                candidate: c,
                totalScore: totalsByCandidate[c.id],
              ),
            ),
          ),
        ],
        if (juniors.isNotEmpty) ...[
          _groupHeader('Junior', AppTheme.juniorBadge, juniors.length),
          const SizedBox(height: 8),
          ...juniors.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CandidateCard(
                candidate: c,
                totalScore: totalsByCandidate[c.id],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _groupHeader(String label, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            label == 'Senior' ? Icons.star : Icons.child_care,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '$count candidates',
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _stageHeader(int stage) {
    final label = Session.stageLabel(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBlock(
    List<Candidate> list,
    String label,
    Color color,
    Map<String, Map<int, double>> totalsByCandidateStage,
    int stage,
  ) {
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupHeader(label, color, list.length),
        const SizedBox(height: 8),
        ...list.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CandidateCard(
              candidate: c,
              totalScore: totalsByCandidateStage[c.id]?[stage],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sessionGroupHeader(Session? session, int count) {
    if (session == null) {
      return _groupHeader('No Session', AppTheme.textMuted, count);
    }
    final dateLabel = DateFormat('dd MMM yyyy').format(session.date);
    final stageLabel = Session.stageLabel(session.stage);
    final title = '$dateLabel · $stageLabel';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '$count candidates',
            style: TextStyle(
              color: AppTheme.primary.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters & Sorting',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'SORT BY'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _SortBy.values.map((s) {
                        final labels = {
                          _SortBy.name: 'Name',
                          _SortBy.age: 'Age',
                          _SortBy.sessionDate: 'Stage',
                          _SortBy.totalScore: 'Total Score',
                        };
                        return FilterChip(
                          label: Text(labels[s]!),
                          selected: _sortBy == s,
                          onSelected: (_) =>
                              setModal(() => setState(() => _sortBy = s)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(title: 'GROUP BY'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _GroupBy.values.map((g) {
                        final labels = {
                          _GroupBy.none: 'None',
                          _GroupBy.category: 'Category',
                          _GroupBy.session: 'Session',
                          _GroupBy.stageCategory: 'Stage + Category',
                        };
                        return FilterChip(
                          label: Text(labels[g]!),
                          selected: _groupBy == g,
                          onSelected: (_) =>
                              setModal(() => setState(() => _groupBy = g)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(title: 'TOP PERFORMERS'),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: _topOnly,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show top N per stage and category'),
                      onChanged: (value) =>
                          setModal(() => setState(() => _topOnly = value)),
                    ),
                    if (_topOnly) ...[
                      const SizedBox(height: 8),
                      ...[
                        1,
                        2,
                        3,
                        4,
                      ].map((stage) => _topStageRow(stage, setModal)),
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
          ),
        ),
      ),
    );
  }

  Widget _topStageRow(int stage, void Function(VoidCallback) setModal) {
    final label = Session.stageLabel(stage);
    final value = _topPerStage[stage] ?? 15;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('$label top N', style: const TextStyle(fontSize: 13)),
          ),
          IconButton(
            onPressed: value > 1
                ? () => setModal(
                    () => setState(() => _topPerStage[stage] = value - 1),
                  )
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            onPressed: () =>
                setModal(() => setState(() => _topPerStage[stage] = value + 1)),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final Candidate candidate;
  final double? totalScore;
  const _CandidateCard({required this.candidate, this.totalScore});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => CandidateDetailSheet(candidate: candidate),
      ),
      child: Row(
        children: [
          AvatarWidget(
            imageUrl: candidate.imageUrl,
            name: candidate.name,
            radius: 28,
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
                    stageBadge(candidate.stage),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalScore == null ? '--' : totalScore!.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                candidate.exactAge,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textMuted,
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
