import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../models/app_user.dart';
import '../models/branch.dart';
import '../services/excel_bulk_service.dart';
import '../services/student_service.dart';
import '../services/test_service.dart';
import '../utils/photo_image.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _service = StudentService();
  final _bulkService = ExcelBulkService();
  final _testService = TestService();
  final _searchController = TextEditingController();
  late Future<List<AppUser>> _students;
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    _students = _service.fetchStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() => _students =
        _service.fetchStudents(search: _searchController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Directory'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          IconButton(
            tooltip: 'Import Excel',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: _bulkBusy ? null : _importStudents,
          ),
          IconButton(
            tooltip: 'Export Excel',
            icon: const Icon(Icons.download_rounded),
            onPressed: _bulkBusy ? null : _exportStudents,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStudent,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Student'),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, ID, or roll no…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _search();
                    }),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),

          // ── Student list ──
          Expanded(
            child: FutureBuilder<List<AppUser>>(
              future: _students,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error loading students',
                          style: TextStyle(
                              color: AppTheme.ink.withValues(alpha: 0.5))));
                }
                final students = snapshot.data ?? [];
                if (students.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline_rounded,
                          size: 64,
                          color: AppTheme.primaryLight.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No students found',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ]),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _StudentTile(
                    student: students[index],
                    onTap: () => _showDetail(context, students[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, AppUser student) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => _StudentDetailScreen(student: student)));
    if (changed == true && mounted) {
      setState(() => _students =
          _service.fetchStudents(search: _searchController.text.trim()));
    }
  }

  Future<void> _openAddStudent() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _AddStudentScreen()),
    );
    if (created == true && mounted) {
      setState(() => _students =
          _service.fetchStudents(search: _searchController.text.trim()));
    }
  }

  Future<void> _importStudents() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;

    setState(() => _bulkBusy = true);
    try {
      final branches = await _testService.fetchBranches();
      final importResult = await _bulkService.importStudents(bytes, branches);
      if (!mounted) return;
      _showImportResult(importResult);
      setState(() => _students =
          _service.fetchStudents(search: _searchController.text.trim()));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _exportStudents() async {
    setState(() => _bulkBusy = true);
    try {
      final students = await _service.fetchAllStudents();
      final file = await _bulkService.exportStudents(students);
      await _bulkService.open(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${students.length} students')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  void _showImportResult(BulkImportResult result) {
    final details = result.messages.take(8).join('\n');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Student import complete'),
        content: SingleChildScrollView(
          child: Text(details.isEmpty
              ? result.summary
              : '${result.summary}\n\n$details'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }
}

class _AddStudentScreen extends StatefulWidget {
  const _AddStudentScreen();

  @override
  State<_AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<_AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentService = StudentService();
  final _testService = TestService();
  final _fullNameController = TextEditingController();
  final _collegeIdController = TextEditingController();
  final _collegeNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _boardRollNoController = TextEditingController();
  final _courseController = TextEditingController();
  final _guardianController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _admissionYearController = TextEditingController();
  final _dropoutYearController = TextEditingController();
  late Future<List<Branch>> _branches;
  Branch? _selectedBranch;
  int? _selectedSemester;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _branches = _testService.fetchBranches();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _collegeIdController.dispose();
    _collegeNameController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _rollNoController.dispose();
    _boardRollNoController.dispose();
    _courseController.dispose();
    _guardianController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _admissionYearController.dispose();
    _dropoutYearController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  int? _requiredInt(TextEditingController controller) {
    final text = controller.text.trim();
    return int.tryParse(text);
  }

  String? _email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    return text.contains('@') ? null : 'Enter a valid email';
  }

  String? _optionalLoginPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return null;
    if (password.length < 4) return 'Use at least 4 characters';
    return null;
  }

  String? _year(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    final year = int.tryParse(text);
    return year != null && year >= 2000 && year <= 2100
        ? null
        : 'Enter a valid year';
  }

  String? _date(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)
        ? null
        : 'Use yyyy-mm-dd';
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDob() async {
    final initial =
        DateTime.tryParse(_dobController.text.trim()) ?? DateTime(2005);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      _dobController.text = _formatDate(selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a branch')));
      return;
    }
    if (_selectedSemester == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a semester')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _studentService.createStudent(
        fullName: _fullNameController.text.trim(),
        boardRollNo: _boardRollNoController.text.trim(),
        dob: _dobController.text.trim(),
        branchId: _selectedBranch!.id,
        collegeId: _collegeIdController.text.trim(),
        password: _passwordController.text.trim(),
        email: _emailController.text.trim(),
        semester: _selectedSemester!,
        rollNo: _rollNoController.text.trim(),
        courseName: _courseController.text.trim(),
        collegeName: _collegeNameController.text.trim(),
        guardianName: _guardianController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        admissionYear: _requiredInt(_admissionYearController)!,
        dropoutYear: _requiredInt(_dropoutYearController)!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account created')));
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: FutureBuilder<List<Branch>>(
        future: _branches,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final branches = snapshot.data ?? [];
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _collegeIdController,
                  decoration: const InputDecoration(labelText: 'College ID'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _collegeNameController,
                  decoration: const InputDecoration(labelText: 'College name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Branch>(
                  initialValue: _selectedBranch,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: branches.map((branch) {
                    return DropdownMenuItem(
                        value: branch,
                        child: Text('${branch.name} (${branch.code})'));
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (branch) => setState(() => _selectedBranch = branch),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _boardRollNoController,
                    decoration: const InputDecoration(
                        labelText: 'Board roll no / Login ID'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Login password (optional)',
                      helperText: 'Leave blank to use DOB as DDMMYYYY, for example 25042008.',
                    ),
                    validator: _optionalLoginPassword),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _saving ? null : _pickDob,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  validator: _date,
                ),
                const SizedBox(height: 18),
                Text('Profile details',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: _email),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _selectedSemester,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  items: List.generate(6, (index) => index + 1)
                      .map((semester) => DropdownMenuItem(
                          value: semester, child: Text('Semester $semester')))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (semester) =>
                          setState(() => _selectedSemester = semester),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _rollNoController,
                    decoration: const InputDecoration(labelText: 'Roll no'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _courseController,
                    decoration: const InputDecoration(labelText: 'Course'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _guardianController,
                    decoration:
                        const InputDecoration(labelText: 'Guardian name'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _admissionYearController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Admission year'),
                    validator: _year),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _dropoutYearController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Drop out year'),
                    validator: _year),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: _required),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(_saving ? 'Creating...' : 'Create Student'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.onTap});
  final AppUser student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border:
              Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.1)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient:
                    student.photoUrl == null ? AppTheme.headerGradient : null,
                borderRadius: BorderRadius.circular(12),
                image: student.photoUrl == null
                    ? null
                    : DecorationImage(
                        image: profileImageProvider(
                            student.photoUrl, ApiConfig.baseUrl)!,
                        fit: BoxFit.cover),
              ),
              child: student.photoUrl == null
                  ? Center(
                      child: Text(
                          student.fullName.isNotEmpty
                              ? student.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      '${student.collegeId ?? '—'}  •  ${student.branchName ?? '—'}  •  Sem ${student.semester ?? '—'}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.5)),
                    ),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.ink.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _StudentDetailScreen extends StatefulWidget {
  const _StudentDetailScreen({required this.student});
  final AppUser student;

  @override
  State<_StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<_StudentDetailScreen> {
  final _service = StudentService();
  late AppUser student;

  @override
  void initState() {
    super.initState();
    student = widget.student;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(student.fullName),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          IconButton(
            tooltip: 'Change photo',
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: _changePhoto,
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Header card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: AppTheme.headerGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
              child: Column(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage:
                      profileImageProvider(student.photoUrl, ApiConfig.baseUrl),
                  child: student.photoUrl == null
                      ? Text(
                          student.fullName.isNotEmpty
                              ? student.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))
                      : null,
                ),
                const SizedBox(height: 10),
                Text(student.fullName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                if (student.collegeId != null)
                  Text(student.collegeId!,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8))),
              ]),
            ),
            const SizedBox(height: 20),

            _Section(title: 'College ID Card', rows: [
              _Row(
                  'College', student.collegeName ?? 'Govt. Polytechnic Kangra'),
              _Row('College ID', student.collegeId ?? '—'),
              _Row('Roll No', student.rollNo ?? '—'),
              _Row('Board Roll No', student.boardRollNo ?? '—'),
            ]),
            const SizedBox(height: 16),

            _Section(title: 'Academic Information', rows: [
              _Row('Course', student.courseName ?? '—'),
              _Row('Branch', student.branchName ?? '—'),
              _Row('Semester', student.semester?.toString() ?? '—'),
              _Row('Admission Year', student.admissionYear?.toString() ?? '—'),
            ]),
            const SizedBox(height: 16),

            _Section(title: 'Personal Details', rows: [
              _Row('Full Name', student.fullName),
              _Row('Date of Birth', student.dob ?? '—'),
              _Row('Guardian', student.guardianName ?? '—'),
              _Row('Phone', student.phone ?? '—'),
              _Row('Email', student.email ?? '—'),
              _Row('Address', student.address ?? '—'),
            ]),
            const SizedBox(height: 16),

            _Section(title: 'Account Status', rows: [
              _Row('Status', student.isActive == true ? 'Active' : 'Inactive'),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<AppUser>(
      MaterialPageRoute(builder: (_) => _EditStudentScreen(student: student)),
    );
    if (updated != null && mounted) {
      setState(() => student = updated);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
            'Delete ${student.fullName} and related login/session records?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteStudent(student.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Student deleted')));
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _changePhoto() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null || (file.path == null && file.bytes == null)) return;
    try {
      final updated = await _service.uploadStudentPhoto(
        id: student.id,
        imagePath: file.path,
        imageBytes: file.bytes,
        imageName: file.name,
      );
      if (!mounted) return;
      setState(() => student = updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Student photo updated')));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }
}

class _EditStudentScreen extends StatefulWidget {
  const _EditStudentScreen({required this.student});
  final AppUser student;

  @override
  State<_EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<_EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentService = StudentService();
  final _testService = TestService();
  late final TextEditingController _fullNameController;
  late final TextEditingController _collegeIdController;
  late final TextEditingController _passwordController;
  late final TextEditingController _dobController;
  late final TextEditingController _emailController;
  late final TextEditingController _semesterController;
  late final TextEditingController _rollNoController;
  late final TextEditingController _boardRollNoController;
  late final TextEditingController _courseController;
  late final TextEditingController _guardianController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _admissionYearController;
  late Future<List<Branch>> _branches;
  Branch? _selectedBranch;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _fullNameController = TextEditingController(text: s.fullName);
    _collegeIdController = TextEditingController(text: s.collegeId ?? '');
    _passwordController = TextEditingController();
    _dobController = TextEditingController(text: s.dob ?? '');
    _emailController = TextEditingController(text: s.email ?? '');
    _semesterController =
        TextEditingController(text: s.semester?.toString() ?? '');
    _rollNoController = TextEditingController(text: s.rollNo ?? '');
    _boardRollNoController = TextEditingController(text: s.boardRollNo ?? '');
    _courseController = TextEditingController(text: s.courseName ?? '');
    _guardianController = TextEditingController(text: s.guardianName ?? '');
    _phoneController = TextEditingController(text: s.phone ?? '');
    _addressController = TextEditingController(text: s.address ?? '');
    _admissionYearController =
        TextEditingController(text: s.admissionYear?.toString() ?? '');
    _isActive = s.isActive != false;
    _branches = _testService.fetchBranches().then((branches) {
      for (final branch in branches) {
        if (branch.id == s.branchId) {
          _selectedBranch = branch;
          break;
        }
      }
      _selectedBranch ??= branches.isEmpty ? null : branches.first;
      return branches;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _collegeIdController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _semesterController.dispose();
    _rollNoController.dispose();
    _boardRollNoController.dispose();
    _courseController.dispose();
    _guardianController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _admissionYearController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  int? _optionalInt(TextEditingController controller) =>
      controller.text.trim().isEmpty
          ? null
          : int.tryParse(controller.text.trim());
  String? _optionalEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || email.contains('@')) return null;
    return 'Enter a valid email';
  }

  String? _optionalSemester(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final semester = int.tryParse(text);
    return semester != null && semester >= 1 && semester <= 6
        ? null
        : 'Enter 1 to 6';
  }

  String? _optionalAdmissionYear(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    return year != null && year >= 2000 && year <= 2100
        ? null
        : 'Enter a valid year';
  }

  String? _optionalDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)
        ? null
        : 'Use yyyy-mm-dd';
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDob() async {
    final initial =
        DateTime.tryParse(_dobController.text.trim()) ?? DateTime(2005);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      _dobController.text = _formatDate(selected);
    }
  }

  String? _optionalLoginPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return null;
    if (password.length < 4) return 'Use at least 4 characters';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedBranch == null) return;
    setState(() => _saving = true);
    try {
      final updated = await _studentService.updateStudent(
        id: widget.student.id,
        fullName: _fullNameController.text.trim(),
        collegeId: _collegeIdController.text.trim(),
        password: _passwordController.text,
        branchId: _selectedBranch!.id,
        email: _emailController.text.trim(),
        dob: _dobController.text.trim(),
        semester: _optionalInt(_semesterController),
        rollNo: _rollNoController.text.trim(),
        boardRollNo: _boardRollNoController.text.trim(),
        courseName: _courseController.text.trim(),
        guardianName: _guardianController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        admissionYear: _optionalInt(_admissionYearController),
        isActive: _isActive,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Student'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: FutureBuilder<List<Branch>>(
        future: _branches,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final branches = snapshot.data ?? [];
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _collegeIdController,
                    decoration: const InputDecoration(
                        labelText: 'College ID (optional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<Branch>(
                  initialValue: _selectedBranch,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: branches
                      .map((branch) => DropdownMenuItem(
                          value: branch,
                          child: Text('${branch.name} (${branch.code})')))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (branch) => setState(() => _selectedBranch = branch),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password (optional)',
                      helperText: 'Leave blank to keep current password.',
                    ),
                    validator: _optionalLoginPassword),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isActive = value),
                  title: const Text('Active account'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: _optionalEmail),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _saving ? null : _pickDob,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  validator: _optionalDate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _semesterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Semester'),
                    validator: _optionalSemester),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _rollNoController,
                    decoration: const InputDecoration(labelText: 'Roll no')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _boardRollNoController,
                    decoration: const InputDecoration(
                        labelText: 'Board roll no / Login ID'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _courseController,
                    decoration: const InputDecoration(labelText: 'Course')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _guardianController,
                    decoration:
                        const InputDecoration(labelText: 'Guardian name')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _admissionYearController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Admission year'),
                    validator: _optionalAdmissionYear),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.6))),
      ),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border:
              Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.1)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(children: rows),
      ),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.5)))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
