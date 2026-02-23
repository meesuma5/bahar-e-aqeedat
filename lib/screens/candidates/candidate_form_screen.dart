import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class CandidateFormScreen extends ConsumerStatefulWidget {
  final Candidate? candidate;
  const CandidateFormScreen({super.key, this.candidate});

  @override
  ConsumerState<CandidateFormScreen> createState() => _CandidateFormScreenState();
}

class _CandidateFormScreenState extends ConsumerState<CandidateFormScreen> {
  Candidate? get _existing => widget.candidate;
  bool get _isEditing => _existing != null;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _fatherNameCtrl;
  late TextEditingController _imageUrlCtrl;
  DateTime? _dob;
  late int _stage;
  bool _loading = false;

  CandidateCategory? get _category =>
      _dob != null ? Candidate.categoryFromDob(_dob!) : null;
  bool? get _isSenior =>
      _category == CandidateCategory.senior ? true :
      _category == CandidateCategory.junior ? false : null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _existing?.name ?? '');
    _fatherNameCtrl = TextEditingController(text: _existing?.fatherName ?? '');
    _imageUrlCtrl = TextEditingController(text: _existing?.imageUrl ?? '');
    _dob = _existing?.dob;
    _stage = _existing?.stage ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fatherNameCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      _showError('Please select a date of birth');
      return;
    }
    if (_category == CandidateCategory.ineligible) {
      _showError('Candidate age is not within eligible range (under 26)');
      return;
    }

    setState(() => _loading = true);
    try {
      final svc = FirebaseService.instance;
      final uid = svc.currentUserId!;

      if (_isEditing) {
        await svc.updateCandidate(_existing!.id, {
          'fatherName': _fatherNameCtrl.text.trim(),
          'dob': _dob,
          'imageUrl': _imageUrlCtrl.text.trim(),
          'isSenior': _isSenior,
          'stage': _stage,
        });
      } else {
        final candidate = Candidate(
          id: '',
          name: _nameCtrl.text.trim(),
          fatherName: _fatherNameCtrl.text.trim(),
          dob: _dob!,
          imageUrl: _imageUrlCtrl.text.trim(),
          isSenior: _isSenior!,
          stage: _stage,
          createdBy: uid,
          createdAt: DateTime.now(),
        );
        await svc.createCandidate(candidate);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
  }

  Future<void> _pickDob() async {
    final maxDate = DateTime.now();
    final minDate = DateTime(maxDate.year - 30);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(maxDate.year - 18),
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: _isEditing ? 'Edit Candidate' : 'New Candidate',
        showBack: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileSection(),
                const SizedBox(height: 16),
                _buildDobSection(),
                const SizedBox(height: 16),
                _buildEligibilityCard(),
                const SizedBox(height: 16),
                _buildStageSection(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'PROFILE INFO'),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Full Name',
            field: TextFormField(
              controller: _nameCtrl,
              enabled: !_isEditing, // name locked after creation
              decoration: InputDecoration(
                hintText: 'Enter full name',
                suffixIcon: _isEditing
                    ? const Tooltip(
                        message: 'Name cannot be changed after creation',
                        child: Icon(Icons.lock_outline, size: 16, color: AppTheme.textMuted),
                      )
                    : null,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: "Father's Name",
            field: TextFormField(
              controller: _fatherNameCtrl,
              decoration: const InputDecoration(hintText: "Enter father's name"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Father's name is required" : null,
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Profile Image URL',
            field: TextFormField(
              controller: _imageUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://drive.google.com/...',
                prefixIcon: Icon(Icons.image_outlined),
              ),
            ),
          ),
          if (_imageUrlCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildImagePreview(),
          ],
          const SizedBox(height: 6),
          const Text(
            '💡 Tip: Use Google Drive → Right click image → Share → Get link, change to "Anyone with link" and paste here.',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ListenableBuilder(
      listenable: _imageUrlCtrl,
      builder: (_, __) {
        if (_imageUrlCtrl.text.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _imageUrlCtrl.text,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDobSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'DATE OF BIRTH'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: _dob == null ? Colors.grey.shade200 : AppTheme.primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined,
                      size: 18,
                      color: _dob == null ? AppTheme.textMuted : AppTheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    _dob != null
                        ? DateFormat('dd MMM yyyy').format(_dob!)
                        : 'Select date of birth',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _dob == null ? AppTheme.textMuted : AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          if (_dob != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _buildExactAge(),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildExactAge() {
    if (_dob == null) return '';
    // Age calculated as of the competition reference date: 13 Dec 2025
    final ref = Candidate.ageReferenceDate;
    int years = ref.year - _dob!.year;
    int months = ref.month - _dob!.month;
    int days = ref.day - _dob!.day;
    if (days < 0) {
      months--;
      days += DateTime(ref.year, ref.month, 0).day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    return 'Age as of 13 Dec 2025: $years years, $months months, $days days';
  }

  Widget _buildEligibilityCard() {
    if (_dob == null) return const SizedBox.shrink();
    final category = _category!;
    Color color;
    IconData icon;
    String label;
    String desc;
    switch (category) {
      case CandidateCategory.junior:
        color = AppTheme.juniorBadge;
        icon = Icons.child_care;
        label = 'Junior Category';
        desc = 'Age is under 15 years — eligible for Junior';
        break;
      case CandidateCategory.senior:
        color = AppTheme.seniorBadge;
        icon = Icons.star;
        label = 'Senior Category';
        desc = 'Age is 15–25 years — eligible for Senior';
        break;
      case CandidateCategory.ineligible:
        color = AppTheme.error;
        icon = Icons.block;
        label = 'Not Eligible';
        desc = 'Age is 26 or above — not eligible to participate';
        break;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text(desc,
                    style: TextStyle(color: color.withOpacity(0.75), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'STAGE / ROUND'),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _stage,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.emoji_events_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Preliminaries')),
              DropdownMenuItem(value: 2, child: Text('Quarter Finals')),
              DropdownMenuItem(value: 3, child: Text('Semi Finals')),
              DropdownMenuItem(value: 4, child: Text('Finals')),
            ],
            onChanged: (v) => setState(() => _stage = v!),
          ),
          const SizedBox(height: 8),
          const Text(
            'All candidates start at Preliminaries by default.',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
