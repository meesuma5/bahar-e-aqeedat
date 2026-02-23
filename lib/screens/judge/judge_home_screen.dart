import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/app_logger.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class JudgeHomeScreen extends ConsumerWidget {
  final AppUser judge;
  const JudgeHomeScreen({super.key, required this.judge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(judgeScoresProvider(judge.id));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(judgeScoresProvider(judge.id).future),
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: scoresAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) {
                  appLogger.e('Judge home load error', error: e);
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text('Unable to load data. Please try again.'),
                    ),
                  );
                },
                data: (scores) => _buildContent(context, scores),
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      AvatarWidget(
                        imageUrl: null,
                        name: judge.name,
                        radius: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              judge.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer(
                        builder: (_, ref, __) {
                          return IconButton(
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => FirebaseService.instance.signOut(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      backgroundColor: AppTheme.primary,
    );
  }

  SliverList _buildContent(BuildContext context, List<Score> scores) {
    final sessionIds = scores.map((s) => s.sessionId).toSet();
    final candidateIds = scores.map((s) => s.candidateId).toSet();

    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 20),
        _buildStatsRow(sessionIds.length, candidateIds.length, scores.length),
        const SizedBox(height: 24),
        _buildAveragesCard(context, scores),
        const SizedBox(height: 24),
        _buildRecentActivity(scores),
      ]),
    );
  }

  Widget _buildStatsRow(int sessions, int candidates, int totalScores) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Sessions',
            value: sessions.toString(),
            icon: Icons.calendar_month_outlined,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Candidates',
            value: candidates.toString(),
            icon: Icons.people_outline,
            color: AppTheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Scores Given',
            value: totalScores.toString(),
            icon: Icons.how_to_vote_outlined,
            color: AppTheme.success,
          ),
        ),
      ],
    );
  }

  Widget _buildAveragesCard(BuildContext context, List<Score> scores) {
    if (scores.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            const SectionHeader(title: 'YOUR SCORING AVERAGES'),
            const SizedBox(height: 20),
            const EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No Scores Yet',
              subtitle: 'Your averages will appear\nonce you start scoring',
            ),
          ],
        ),
      );
    }

    final overallAvg = scores.isEmpty
        ? 0.0
        : scores.fold<double>(0, (a, s) => a + s.total) / scores.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: 'YOUR SCORING AVERAGES'),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${overallAvg.toStringAsFixed(1)}/100 avg',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...kScoreCategories.map((cat) {
            final avg =
                scores.fold<double>(0, (a, s) => a + scoreValue(s, cat.key)) /
                scores.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ScoreBar(
                label: cat.label,
                value: avg,
                maxValue: cat.maxMarks.toDouble(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<Score> scores) {
    if (scores.isEmpty) return const SizedBox.shrink();
    final recent = scores.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'RECENT ACTIVITY'),
        const SizedBox(height: 12),
        ...recent.map((score) => _RecentScoreRow(score: score)),
      ],
    );
  }
}

class _RecentScoreRow extends StatelessWidget {
  final Score score;
  const _RecentScoreRow({required this.score});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Candidate>>(
      future: FirebaseService.instance.getCandidatesByIds([score.candidateId]),
      builder: (_, snap) {
        final candidate = snap.data?.firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: candidate?.imageUrl,
                  name: candidate?.name ?? '?',
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate?.name ?? 'Loading...',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        Session.stageLabel(score.stage),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${score.total.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
