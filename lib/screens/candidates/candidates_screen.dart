import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../../../services/firebase_service.dart';
import '../../../services/app_logger.dart';
import '../../../services/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';
import 'candidate_form_screen.dart';
import 'candidate_detail_sheet.dart';

enum _SortBy { name, age, sessionDate, averageScore }

enum _GroupBy { none, category }

class CandidatesScreen extends ConsumerStatefulWidget {
  const CandidatesScreen({super.key});

  @override
  ConsumerState<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends ConsumerState<CandidatesScreen> {
  _SortBy _sortBy = _SortBy.name;
  _GroupBy _groupBy = _GroupBy.none;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(candidatesStreamProvider);
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
                  final filtered = _filter(candidates);
                  if (filtered.isEmpty) {
                    return _buildScrollableEmptyState(
                      const EmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'No Candidates Found',
                        subtitle: 'Try adjusting filters or add a candidate',
                      ),
                    );
                  }
                  return _buildList(filtered);
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

  List<Candidate> _filter(List<Candidate> all) {
    var list = all.where((c) {
      if (_search.isEmpty) return true;
      return c.name.toLowerCase().contains(_search.toLowerCase()) ||
          c.fatherName.toLowerCase().contains(_search.toLowerCase());
    }).toList();

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
      case _SortBy.averageScore:
        // Sorted by stage desc as proxy; real avg requires async
        list.sort((a, b) => b.stage.compareTo(a.stage));
        break;
    }
    return list;
  }

  Widget _buildList(List<Candidate> candidates) {
    if (_groupBy == _GroupBy.none) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: candidates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _CandidateCard(candidate: candidates[i]),
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
              child: _CandidateCard(candidate: c),
            ),
          ),
        ],
        if (juniors.isNotEmpty) ...[
          _groupHeader('Junior', AppTheme.juniorBadge, juniors.length),
          const SizedBox(height: 8),
          ...juniors.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CandidateCard(candidate: c),
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
                    _SortBy.averageScore: 'Score',
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
                  };
                  return FilterChip(
                    label: Text(labels[g]!),
                    selected: _groupBy == g,
                    onSelected: (_) =>
                        setModal(() => setState(() => _groupBy = g)),
                  );
                }).toList(),
              ),
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

class _CandidateCard extends StatelessWidget {
  final Candidate candidate;
  const _CandidateCard({required this.candidate});

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
