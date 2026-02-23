import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class SessionFormScreen extends ConsumerStatefulWidget {
  final Session? session;
  const SessionFormScreen({super.key, this.session});

  @override
  ConsumerState<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends ConsumerState<SessionFormScreen> {
  Session? get _existing => widget.session;
  bool get _isEditing => _existing != null;

  late DateTime _date;
  late int _stage;
  late bool _isSenior;
  late bool _isActive;
  late bool _isConducted;
  late List<String> _candidateIds;
  late List<String> _judgeIds;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _date = _existing?.date ?? DateTime.now();
    _stage = _existing?.stage ?? 1;
    _isSenior = _existing?.isSenior ?? true;
    _isActive = _existing?.isActive ?? false;
    _isConducted = _existing?.isConducted ?? false;
    _candidateIds = List.from(_existing?.candidateIds ?? []);
    _judgeIds = List.from(_existing?.judgeIds ?? []);
  }

  Future<void> _save() async {
    // Validation
    if (_isActive && _isConducted) {
      _showError('A session cannot be both active and conducted.');
      return;
    }

    setState(() => _loading = true);
    try {
      final svc = FirebaseService.instance;
      final uid = svc.currentUserId!;

      if (_isEditing) {
        if (_isActive) {
          await svc.setSessionActive(_existing!.id);
          await svc.updateSession(_existing!.id, {
            'date': _date,
            'stage': _stage,
            'isSenior': _isSenior,
            'isConducted': _isConducted,
            'candidateIds': _candidateIds,
            'judgeIds': _judgeIds,
          });
        } else {
          await svc.updateSession(_existing!.id, _buildMap(uid));
        }
      } else {
        final newSession = Session(
          id: '',
          date: _date,
          stage: _stage,
          isSenior: _isSenior,
          isActive: _isActive,
          isConducted: _isConducted,
          candidateIds: _candidateIds,
          judgeIds: _judgeIds,
          createdBy: uid,
          createdAt: DateTime.now(),
        );
        final id = await svc.createSession(newSession);
        if (_isActive) await svc.setSessionActive(id);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _buildMap(String uid) => {
        'date': _date,
        'stage': _stage,
        'isSenior': _isSenior,
        'isActive': _isActive,
        'isConducted': _isConducted,
        'candidateIds': _candidateIds,
        'judgeIds': _judgeIds,
        'createdBy': uid,
        'createdAt': DateTime.now(),
      };

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: _isEditing ? 'Edit Session' : 'New Session',
        showBack: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfo(),
              const SizedBox(height: 16),
              _buildStatusSection(),
              const SizedBox(height: 16),
              _buildCandidatesSection(),
              const SizedBox(height: 16),
              _buildJudgesSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'BASIC INFO'),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Date',
            field: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Text(DateFormat('EEE, dd MMM yyyy').format(_date),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Stage / Round',
            field: DropdownButtonFormField<int>(
              initialValue: _stage,
              decoration: const InputDecoration(),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Preliminaries')),
                DropdownMenuItem(value: 2, child: Text('Quarter Finals')),
                DropdownMenuItem(value: 3, child: Text('Semi Finals')),
                DropdownMenuItem(value: 4, child: Text('Finals')),
              ],
              onChanged: (v) => setState(() => _stage = v!),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Category',
            field: Row(
              children: [
                _categoryChip('Senior', true),
                const SizedBox(width: 10),
                _categoryChip('Junior', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, bool isSenior) {
    final selected = _isSenior == isSenior;
    final color = isSenior ? AppTheme.seniorBadge : AppTheme.juniorBadge;
    return GestureDetector(
      onTap: () => setState(() {
        _isSenior = isSenior;
        // Remove candidates that don't match category
        _candidateIds.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : AppTheme.textMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildStatusSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'STATUS'),
          const SizedBox(height: 8),
          _switchRow(
            'Active Session',
            'Judges can score candidates in this session',
            Icons.radio_button_on,
            AppTheme.activeBadge,
            _isActive,
            (v) => setState(() {
              _isActive = v;
              if (v) _isConducted = false;
            }),
          ),
          const Divider(),
          _switchRow(
            'Conducted',
            'Session has been completed',
            Icons.check_circle_outline,
            AppTheme.conductedBadge,
            _isConducted,
            (v) => setState(() {
              _isConducted = v;
              if (v) _isActive = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(String title, String subtitle, IconData icon, Color color,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesSection() {
    final candidatesAsync = ref.watch(candidatesStreamProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'CANDIDATES (${_candidateIds.length})',
            trailing: candidatesAsync.maybeWhen(
              data: (all) {
                final eligible = all.where((c) => c.isSenior == _isSenior).toList();
                return TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: () => _showPickerSheet(
                    context,
                    title: 'Select Candidates',
                    items: eligible
                        .map((c) => _PickerItem(id: c.id, label: c.name, subtitle: c.exactAge))
                        .toList(),
                    selected: _candidateIds,
                    onChanged: (ids) => setState(() => _candidateIds = ids),
                  ),
                );
              },
              orElse: () => null,
            ),
          ),
          const SizedBox(height: 12),
          candidatesAsync.maybeWhen(
            data: (all) {
              final selected = all.where((c) => _candidateIds.contains(c.id)).toList();
              if (selected.isEmpty) {
                return const Text('No candidates added yet',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13));
              }
              return Column(
                children: selected.map((c) => _candidateChip(c)).toList(),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _candidateChip(Candidate c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          AvatarWidget(imageUrl: c.imageUrl, name: c.name, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(c.exactAge,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
            onPressed: () => setState(() => _candidateIds.remove(c.id)),
          ),
        ],
      ),
    );
  }

  Widget _buildJudgesSection() {
    final usersAsync = ref.watch(usersStreamProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'JUDGES (${_judgeIds.length})',
            trailing: usersAsync.maybeWhen(
              data: (all) {
                final judges = all.where((u) => u.role == UserRole.judge).toList();
                return TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: () => _showPickerSheet(
                    context,
                    title: 'Select Judges',
                    items: judges
                        .map((j) => _PickerItem(id: j.id, label: j.name, subtitle: j.email))
                        .toList(),
                    selected: _judgeIds,
                    onChanged: (ids) => setState(() => _judgeIds = ids),
                  ),
                );
              },
              orElse: () => null,
            ),
          ),
          const SizedBox(height: 12),
          usersAsync.maybeWhen(
            data: (all) {
              final selected = all.where((u) => _judgeIds.contains(u.id)).toList();
              if (selected.isEmpty) {
                return const Text('No judges assigned yet',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13));
              }
              return Column(
                children: selected.map((j) => _judgeChip(j)).toList(),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _judgeChip(AppUser judge) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          AvatarWidget(imageUrl: null, name: judge.name, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judge.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(judge.email,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
            onPressed: () => setState(() => _judgeIds.remove(judge.id)),
          ),
        ],
      ),
    );
  }

  void _showPickerSheet(
    BuildContext context, {
    required String title,
    required List<_PickerItem> items,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    final local = List<String>.from(selected);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, ctrl) => Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.headlineSmall),
                    TextButton(
                      onPressed: () {
                        onChanged(local);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('No eligible items',
                            style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final isSelected = local.contains(item.id);
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: AppTheme.primary,
                            title: Text(item.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 14)),
                            subtitle: Text(item.subtitle,
                                style: const TextStyle(fontSize: 12)),
                            onChanged: (v) => setModal(() {
                              v! ? local.add(item.id) : local.remove(item.id);
                            }),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerItem {
  final String id, label, subtitle;
  const _PickerItem({required this.id, required this.label, required this.subtitle});
}
