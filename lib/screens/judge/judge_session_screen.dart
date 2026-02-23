import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/app_logger.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'score_entry_screen.dart';
import 'score_view_screen.dart';

class JudgeSessionScreen extends ConsumerWidget {
  final AppUser judge;
  const JudgeSessionScreen({super.key, required this.judge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(judgeActiveSessionsProvider(judge.id));

    return sessionsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) {
        appLogger.e('Judge sessions load error', error: e);
        return const Scaffold(
          body: Center(
            child: Text('Unable to load sessions. Please try again.'),
          ),
        );
      },
      data: (sessions) {
        if (sessions.isEmpty) {
          return Scaffold(
            appBar: const GradientAppBar(title: 'Current Session'),
            body: RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(judgeActiveSessionsProvider(judge.id).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 80),
                children: const [
                  EmptyState(
                    icon: Icons.mic_off_outlined,
                    title: 'No Active Session',
                    subtitle:
                        'You have no active sessions assigned.\nCheck back later or contact the admin.',
                  ),
                ],
              ),
            ),
          );
        }

        // Partition into senior / junior
        final senior = sessions.where((s) => s.isSenior).firstOrNull;
        final junior = sessions.where((s) => !s.isSenior).firstOrNull;

        // Single session — no tabs needed
        if (senior == null || junior == null) {
          final session = senior ?? junior!;
          return Scaffold(
            appBar: GradientAppBar(
              title: session.isSenior ? 'Senior Session' : 'Junior Session',
            ),
            body: _SessionCandidateList(session: session, judge: judge),
          );
        }

        // Both active — show tabbed view
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                ),
              ),
              title: const Text('Current Sessions'),
              bottom: TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(text: 'Senior', icon: Icon(Icons.star, size: 16)),
                  Tab(text: 'Junior', icon: Icon(Icons.child_care, size: 16)),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _SessionCandidateList(session: senior, judge: judge),
                _SessionCandidateList(session: junior, judge: judge),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Candidate list for a single session ─────────────────────────────────────

class _SessionCandidateList extends ConsumerWidget {
  final Session session;
  final AppUser judge;
  const _SessionCandidateList({required this.session, required this.judge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.candidateIds.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.refresh(judgeActiveSessionsProvider(judge.id).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 80),
          children: const [
            EmptyState(
              icon: Icons.people_outline,
              title: 'No Candidates',
              subtitle: 'This session has no candidates yet.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.refresh(judgeActiveSessionsProvider(judge.id).future),
      child: FutureBuilder<List<Candidate>>(
        future: FirebaseService.instance.getCandidatesByIds(
          session.candidateIds,
        ),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 120),
              children: const [
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          final candidates = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              _SessionInfoBanner(session: session),
              const SizedBox(height: 16),
              ...candidates.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CandidateSessionCard(
                    candidate: c,
                    session: session,
                    judge: judge,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionInfoBanner extends StatelessWidget {
  final Session session;
  const _SessionInfoBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, dd MMM yyyy').format(session.date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${Session.stageLabel(session.stage)} · ${session.candidateIds.length} Candidates',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const StatusBadge(
            label: 'LIVE',
            color: Colors.white,
            icon: Icons.radio_button_on,
          ),
        ],
      ),
    );
  }
}

// ─── Per-candidate card in session ───────────────────────────────────────────

class _CandidateSessionCard extends ConsumerWidget {
  final Candidate candidate;
  final Session session;
  final AppUser judge;

  const _CandidateSessionCard({
    required this.candidate,
    required this.session,
    required this.judge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live-stream whether this judge has already scored this candidate
    final scoreAsync = ref.watch(
      singleScoreProvider(ScoreKey(judge.id, candidate.id, session.id)),
    );

    return scoreAsync.when(
      loading: () => AppCard(
        child: Row(
          children: [
            AvatarWidget(
              imageUrl: candidate.imageUrl,
              name: candidate.name,
              radius: 26,
            ),
            const SizedBox(width: 12),
            const Expanded(child: LinearProgressIndicator()),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (existingScore) {
        final isScored = existingScore != null;
        return AppCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => isScored
                  ? ScoreViewScreen(
                      candidate: candidate,
                      session: session,
                      myScore: existingScore,
                      judgeId: judge.id,
                    )
                  : ScoreEntryScreen(
                      candidate: candidate,
                      session: session,
                      judge: judge,
                    ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        Text(
                          'S/O ${candidate.fatherName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          candidate.exactAge,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _scoreBadge(isScored, existingScore),
                ],
              ),
              if (session.stage > 1) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _PreviousStageAverage(
                  candidateId: candidate.id,
                  currentStage: session.stage,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _scoreBadge(bool isScored, Score? score) {
    if (isScored) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: Text(
              '${score!.total.toStringAsFixed(0)}/100',
              style: const TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scored',
            style: TextStyle(fontSize: 10, color: AppTheme.success),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Score',
        style: TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ─── Previous stage average pill ─────────────────────────────────────────────

class _PreviousStageAverage extends StatelessWidget {
  final String candidateId;
  final int currentStage;

  const _PreviousStageAverage({
    required this.candidateId,
    required this.currentStage,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Score>>(
      future: FirebaseService.instance.getPreviousStageScores(
        candidateId,
        currentStage,
      ),
      builder: (_, snap) {
        final scores = snap.data ?? [];
        if (scores.isEmpty) return const SizedBox.shrink();

        final avg =
            scores.fold<double>(0, (a, s) => a + s.total) / scores.length;
        final prevStage = scores
            .map((s) => s.stage)
            .reduce((a, b) => a > b ? a : b);

        return Row(
          children: [
            const Icon(
              Icons.history_outlined,
              size: 13,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              '${Session.stageLabel(prevStage)} avg: ',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              '${avg.toStringAsFixed(1)}/100',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondary,
              ),
            ),
          ],
        );
      },
    );
  }
}
