import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/branch.dart';
import '../services/test_service.dart';

class UploadTestScreen extends StatefulWidget {
  const UploadTestScreen({super.key});

  @override
  State<UploadTestScreen> createState() => _UploadTestScreenState();
}

class _UploadTestScreenState extends State<UploadTestScreen> {
  static const int _maxUploadBytes = 4 * 1024 * 1024;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _timeLimitController = TextEditingController(text: '60');
  final _service = TestService();

  List<Branch> _branches = [];
  Branch? _selectedBranch;
  int _selectedSemester = 1;
  DateTime? _start;
  DateTime? _end;
  String? _pdfPath;
  List<int>? _pdfBytes;
  String? _pdfName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Test PDF'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Schedule a House Test',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          Text(
                            'Upload a PDF and set the exam window.',
                            style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ──
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Test title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (value) => value == null || value.trim().length < 3 ? 'Enter a title (min 3 chars)' : null,
              ),
              const SizedBox(height: 16),

              // ── Branch dropdown ──
              DropdownButtonFormField<Branch>(
                initialValue: _selectedBranch,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: _branches.map((branch) {
                  return DropdownMenuItem(value: branch, child: Text(branch.name));
                }).toList(),
                onChanged: (branch) => setState(() => _selectedBranch = branch),
                validator: (value) => value == null ? 'Choose a branch' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                initialValue: _selectedSemester,
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: List.generate(6, (index) => index + 1)
                    .map((semester) => DropdownMenuItem(value: semester, child: Text('Semester $semester')))
                    .toList(),
                onChanged: (semester) => setState(() => _selectedSemester = semester ?? 1),
              ),
              const SizedBox(height: 16),

              // ── Time limit ──
              TextFormField(
                controller: _timeLimitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Time limit (minutes)',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                validator: (value) {
                  final minutes = int.tryParse(value ?? '');
                  return minutes == null || minutes <= 0 ? 'Enter valid minutes' : null;
                },
              ),
              const SizedBox(height: 20),

              // ── Schedule picker ──
              _ActionTile(
                icon: Icons.calendar_month_rounded,
                label: _start == null
                    ? 'Choose date & time'
                    : '${_formatDate(_start!)} — ${_formatDate(_end!)}',
                subtitle: _start == null ? 'Required' : null,
                onTap: _pickSchedule,
              ),
              const SizedBox(height: 12),

              // ── PDF picker ──
              _ActionTile(
                icon: Icons.picture_as_pdf_rounded,
                label: _pdfName ?? 'Choose PDF file',
                subtitle: _pdfPath == null && _pdfBytes == null ? 'Required' : null,
                trailing: _pdfPath != null || _pdfBytes != null
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20)
                    : null,
                onTap: _pickPdf,
              ),
              const SizedBox(height: 32),

              // ── Submit ──
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.publish_rounded),
                  label: Text(_saving ? 'Scheduling…' : 'Schedule Test'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day} ${months[d.month - 1]}, $h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _loadBranches() async {
    final branches = await _service.fetchBranches();
    setState(() {
      _branches = branches;
      _selectedBranch = branches.isEmpty ? null : branches.first;
    });
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null) {
      final file = result.files.single;
      if (file.size > _maxUploadBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF is too large for mobile upload. Use a PDF under 4 MB.')),
        );
        return;
      }
      setState(() {
        _pdfPath = file.path;
        _pdfBytes = file.bytes;
        _pdfName = file.name;
      });
    }
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final minutes = int.tryParse(_timeLimitController.text) ?? 60;
    setState(() {
      _start = start;
      _end = start.add(Duration(minutes: minutes));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || (_pdfPath == null && _pdfBytes == null) || _pdfName == null || _start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields, choose a schedule, and pick a PDF.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.uploadTest(
        title: _titleController.text.trim(),
        branchId: _selectedBranch!.id,
        semester: _selectedSemester,
        scheduledStart: _start!,
        scheduledEnd: _end!,
        timeLimitMinutes: int.parse(_timeLimitController.text),
        pdfPath: _pdfPath,
        pdfBytes: _pdfBytes,
        pdfName: _pdfName!,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Reusable action tile ──────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDark ? AppTheme.primaryLight : AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.45)),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null) Icon(Icons.chevron_right, size: 20, color: textColor.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}
