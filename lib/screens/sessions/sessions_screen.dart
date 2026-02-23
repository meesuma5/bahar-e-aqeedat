import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../services/firebase_service.dart';
import '../../../services/app_logger.dart';
import '../../../services/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';
import '../session_form_screen.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Sessions',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SessionFormScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseService.instance.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(sessionsStreamProvider.future),
        child: sessionsAsync.when(
          loading: () => _buildScrollablePlaceholder(
            const CircularProgressIndicator(),
          ),
          error: (e, _) {
            appLogger.e('Sessions load error', error: e);
            return _buildScrollableMessage(
              'Unable to load sessions. Please try again.',
            );
          },
          data: (sessions) {
            if (sessions.isEmpty) {
              return _buildScrollableEmptyState(
                const EmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No Sessions Yet',
                  subtitle: 'Tap + to create your first session',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _SessionCard(session: sessions[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'sessionsFab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SessionFormScreen()),
        ),
        child: const Icon(Icons.add),
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

class _SessionCard extends StatelessWidget {
  final Session session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(session.date);
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SessionFormScreen(session: session)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Session.stageLabel(session.stage),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              sessionStatusBadge(session.isActive, session.isConducted),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _iconStat(
                Icons.people_outline,
                '${session.candidateIds.length} Candidates',
              ),
              const SizedBox(width: 16),
              _iconStat(
                Icons.gavel_outlined,
                '${session.judgeIds.length} Judges',
              ),
              const Spacer(),
              seniorJuniorBadge(session.isSenior),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconStat(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 15, color: AppTheme.textMuted),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
    ],
  );
}
