import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../../../services/firebase_service.dart';
import '../../../services/app_logger.dart';
import '../../../services/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';

class JudgesScreen extends ConsumerWidget {
  const JudgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersStreamProvider);
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Users & Roles',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseService.instance.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(usersStreamProvider.future),
        child: usersAsync.when(
          loading: () => _buildScrollablePlaceholder(
            const CircularProgressIndicator(),
          ),
          error: (e, _) {
            appLogger.e('Users load error', error: e);
            return _buildScrollableMessage(
              'Unable to load users. Please try again.',
            );
          },
          data: (users) {
            if (users.isEmpty) {
              return _buildScrollableEmptyState(
                const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No Users Yet',
                  subtitle: 'Users will appear here after signing up',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _UserCard(user: users[i]),
            );
          },
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
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  const _UserCard({required this.user});

  Color get _roleColor {
    switch (user.role) {
      case UserRole.admin:
        return AppTheme.primary;
      case UserRole.judge:
        return AppTheme.secondary;
      case UserRole.neither:
        return AppTheme.textMuted;
    }
  }

  IconData get _roleIcon {
    switch (user.role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.judge:
        return Icons.gavel;
      case UserRole.neither:
        return Icons.person_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _UserDetailSheet(user: user),
      ),
      child: Row(
        children: [
          AvatarWidget(imageUrl: null, name: user.name, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: user.role.label,
            color: _roleColor,
            icon: _roleIcon,
          ),
        ],
      ),
    );
  }
}

class _UserDetailSheet extends ConsumerStatefulWidget {
  final AppUser user;
  const _UserDetailSheet({required this.user});

  @override
  ConsumerState<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends ConsumerState<_UserDetailSheet> {
  late UserRole _selectedRole;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
  }

  Future<void> _saveRole() async {
    if (_selectedRole == widget.user.role) return;
    setState(() => _saving = true);
    try {
      await FirebaseService.instance.updateUserRole(
        widget.user.id,
        _selectedRole,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role updated successfully')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          _buildHandle(),
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildRoleSection(),
                  const SizedBox(height: 20),
                  _buildStatsSection(),
                  const SizedBox(height: 20),
                  _buildScoreAveragesSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader() {
    return Row(
      children: [
        AvatarWidget(imageUrl: null, name: widget.user.name, radius: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                widget.user.email,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'ASSIGN ROLE'),
          const SizedBox(height: 12),
          Row(
            children: UserRole.values
                .map(
                  (role) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _roleChip(role),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveRole,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update Role'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(UserRole role) {
    final isSelected = _selectedRole == role;
    final colors = {
      UserRole.admin: AppTheme.primary,
      UserRole.judge: AppTheme.secondary,
      UserRole.neither: AppTheme.textMuted,
    };
    final color = colors[role]!;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          role.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? color : AppTheme.textMuted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<_JudgeStats>(
      future: _loadJudgeStats(),
      builder: (ctx, snap) {
        final stats = snap.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'ACTIVITY'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Sessions',
                    value: stats?.sessionCount.toString() ?? '--',
                    icon: Icons.calendar_month_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Graded',
                    value: stats?.candidatesGraded.toString() ?? '--',
                    icon: Icons.how_to_vote_outlined,
                    color: AppTheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildScoreAveragesSection() {
    return FutureBuilder<_JudgeStats>(
      future: _loadJudgeStats(),
      builder: (ctx, snap) {
        final stats = snap.data;
        if (stats == null || stats.scores.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'AVERAGE SCORES GIVEN'),
              const SizedBox(height: 12),
              ...kScoreCategories.map((cat) {
                final avg = stats.averageFor(cat.key);
                return ScoreBar(
                  label: cat.label,
                  value: avg,
                  maxValue: cat.maxMarks.toDouble(),
                );
              }),
              const Divider(height: 20),
              ScoreBar(
                label: 'Overall',
                value: stats.overallAverage,
                maxValue: 100,
                color: AppTheme.secondary,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_JudgeStats> _loadJudgeStats() async {
    final svc = FirebaseService.instance;
    final sessionIds = await svc.getSessionsForJudge(widget.user.id);
    final scores = await svc.getScoresForJudgeInSessions(
      widget.user.id,
      sessionIds,
    );
    final uniqueCandidates = scores.map((s) => s.candidateId).toSet();
    return _JudgeStats(
      sessionCount: sessionIds.length,
      candidatesGraded: uniqueCandidates.length,
      scores: scores,
    );
  }
}

class _JudgeStats {
  final int sessionCount;
  final int candidatesGraded;
  final List<Score> scores;

  _JudgeStats({
    required this.sessionCount,
    required this.candidatesGraded,
    required this.scores,
  });

  double averageFor(String key) {
    if (scores.isEmpty) return 0;
    final sum = scores.fold<double>(0, (a, s) => a + scoreValue(s, key));
    return sum / scores.length;
  }

  double get overallAverage {
    if (scores.isEmpty) return 0;
    return scores.fold<double>(0, (a, s) => a + s.total) / scores.length;
  }
}
