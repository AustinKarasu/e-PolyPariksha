import 'dart:io';

import 'package:excel/excel.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/admin_account.dart';
import '../models/app_user.dart';
import '../models/branch.dart';
import 'admin_service.dart';
import 'student_service.dart';

class BulkImportResult {
  const BulkImportResult({required this.created, required this.updated, required this.failed, required this.messages});

  final int created;
  final int updated;
  final int failed;
  final List<String> messages;

  String get summary => 'Created $created, updated $updated, failed $failed';
}

class ExcelBulkService {
  ExcelBulkService({
    StudentService? studentService,
    AdminService? adminService,
  })  : _studentService = studentService ?? StudentService(),
        _adminService = adminService ?? AdminService();

  final StudentService _studentService;
  final AdminService _adminService;

  Future<BulkImportResult> importStudents(List<int> bytes, List<Branch> branches) async {
    final rows = _readRows(bytes);
    final existing = await _studentService.fetchAllStudents();
    final byCollegeId = {
      for (final student in existing)
        if ((student.collegeId ?? '').trim().isNotEmpty) student.collegeId!.trim().toLowerCase(): student,
    };
    final branchLookup = _branchLookup(branches);
    var created = 0;
    var updated = 0;
    var failed = 0;
    final messages = <String>[];

    for (final row in rows) {
      final number = row.rowNumber;
      final fullName = row.value(['full_name', 'full name', 'name', 'student name']);
      final collegeId = row.value(['college_id', 'college id', 'login id', 'student id']);
      final password = row.value(['password', 'temporary password', 'temp password']);
      final branchKey = row.value(['branch_code', 'branch code', 'branch', 'branch_name', 'branch name', 'branch_id', 'branch id']);
      final branch = branchLookup[_norm(branchKey)];
      final existingStudent = byCollegeId[collegeId.toLowerCase()];

      if (fullName.isEmpty || collegeId.isEmpty || branch == null) {
        failed++;
        messages.add('Row $number: full name, college ID, and valid branch are required.');
        continue;
      }
      if (existingStudent == null && password.isEmpty) {
        failed++;
        messages.add('Row $number: password is required for new students.');
        continue;
      }

      try {
        if (existingStudent == null) {
          final student = await _studentService.createStudent(
            fullName: fullName,
            collegeId: collegeId,
            password: password,
            branchId: branch.id,
            email: row.value(['email']),
            semester: _int(row.value(['semester', 'sem'])),
            rollNo: row.value(['roll_no', 'roll no']),
            boardRollNo: row.value(['board_roll_no', 'board roll no']),
            courseName: row.value(['course_name', 'course', 'course name']),
            guardianName: row.value(['guardian_name', 'guardian', 'guardian name']),
            phone: row.value(['phone', 'mobile']),
            address: row.value(['address']),
            admissionYear: _int(row.value(['admission_year', 'admission year'])),
          );
          byCollegeId[collegeId.toLowerCase()] = student;
          created++;
        } else {
          await _studentService.updateStudent(
            id: existingStudent.id,
            fullName: fullName,
            collegeId: collegeId,
            password: password,
            branchId: branch.id,
            email: row.value(['email']),
            semester: _int(row.value(['semester', 'sem'])),
            rollNo: row.value(['roll_no', 'roll no']),
            boardRollNo: row.value(['board_roll_no', 'board roll no']),
            courseName: row.value(['course_name', 'course', 'course name']),
            guardianName: row.value(['guardian_name', 'guardian', 'guardian name']),
            phone: row.value(['phone', 'mobile']),
            address: row.value(['address']),
            admissionYear: _int(row.value(['admission_year', 'admission year'])),
            isActive: _bool(row.value(['is_active', 'active', 'status'])) ?? existingStudent.isActive,
          );
          updated++;
        }
      } catch (err) {
        failed++;
        messages.add('Row $number: ${_cleanError(err)}');
      }
    }

    return BulkImportResult(created: created, updated: updated, failed: failed, messages: messages);
  }

  Future<BulkImportResult> importAdmins(List<int> bytes) async {
    final rows = _readRows(bytes);
    final admins = await _adminService.fetchAdmins();
    final byEmail = {for (final admin in admins) admin.email.trim().toLowerCase(): admin};
    var created = 0;
    var updated = 0;
    var failed = 0;
    final messages = <String>[];

    for (final row in rows) {
      final number = row.rowNumber;
      final fullName = row.value(['full_name', 'full name', 'name', 'admin name']);
      final email = row.value(['email', 'email id']);
      final password = row.value(['password', 'temporary password', 'temp password']);
      final existing = byEmail[email.toLowerCase()];

      if (fullName.isEmpty || email.isEmpty) {
        failed++;
        messages.add('Row $number: full name and email are required.');
        continue;
      }
      if (existing == null && password.isEmpty) {
        failed++;
        messages.add('Row $number: password is required for new admins.');
        continue;
      }

      try {
        if (existing == null) {
          await _adminService.createAdmin(fullName: fullName, email: email, password: password);
          created++;
        } else {
          await _adminService.updateAdmin(
            id: existing.id,
            fullName: fullName,
            email: email,
            password: password,
            isActive: _bool(row.value(['is_active', 'active', 'status'])) ?? existing.isActive,
          );
          updated++;
        }
      } catch (err) {
        failed++;
        messages.add('Row $number: ${_cleanError(err)}');
      }
    }

    return BulkImportResult(created: created, updated: updated, failed: failed, messages: messages);
  }

  Future<File> exportStudents(List<AppUser> students) async {
    final excel = Excel.createExcel();
    final sheet = _sheet(excel, 'Students');
    sheet.appendRow(_cells([
      'full_name',
      'college_id',
      'password',
      'branch_code',
      'semester',
      'email',
      'roll_no',
      'board_roll_no',
      'course_name',
      'guardian_name',
      'phone',
      'address',
      'admission_year',
      'is_active',
    ]));
    for (final student in students) {
      sheet.appendRow(_cells([
        student.fullName,
        student.collegeId ?? '',
        '',
        student.branchCode ?? '',
        student.semester?.toString() ?? '',
        student.email ?? '',
        student.rollNo ?? '',
        student.boardRollNo ?? '',
        student.courseName ?? '',
        student.guardianName ?? '',
        student.phone ?? '',
        student.address ?? '',
        student.admissionYear?.toString() ?? '',
        student.isActive == false ? 'false' : 'true',
      ]));
    }
    return _save(excel, 'polyht_students');
  }

  Future<File> exportAdmins(List<AdminAccount> admins) async {
    final excel = Excel.createExcel();
    final sheet = _sheet(excel, 'Admins');
    sheet.appendRow(_cells(['full_name', 'email', 'password', 'is_active', 'two_factor_enabled', 'is_primary_admin']));
    for (final admin in admins) {
      sheet.appendRow(_cells([
        admin.fullName,
        admin.email,
        '',
        admin.isActive ? 'true' : 'false',
        admin.twoFactorEnabled ? 'true' : 'false',
        admin.isPrimaryAdmin ? 'true' : 'false',
      ]));
    }
    return _save(excel, 'polyht_admins');
  }

  Future<void> open(File file) => OpenFilex.open(file.path);

  Sheet _sheet(Excel excel, String name) {
    final sheet = excel[name];
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != name) {
      excel.delete(defaultSheet);
    }
    excel.setDefaultSheet(name);
    return sheet;
  }

  List<CellValue?> _cells(List<String> values) => values.map<CellValue?>((value) => TextCellValue(value)).toList();

  Future<File> _save(Excel excel, String prefix) async {
    final bytes = excel.save();
    if (bytes == null) throw Exception('Unable to create Excel file');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  List<_ExcelRow> _readRows(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final tableName = excel.tables.keys.firstWhere(
      (name) => excel.tables[name]?.rows.isNotEmpty == true,
      orElse: () => throw Exception('Excel file has no rows'),
    );
    final table = excel.tables[tableName]!;
    final rows = table.rows;
    if (rows.isEmpty) return [];

    final headers = <String, int>{};
    for (var i = 0; i < rows.first.length; i++) {
      final key = _norm(_cellText(rows.first[i]));
      if (key.isNotEmpty) headers[key] = i;
    }
    if (headers.isEmpty) throw Exception('First row must contain column headers');

    final parsed = <_ExcelRow>[];
    for (var i = 1; i < rows.length; i++) {
      final values = <String, String>{};
      var hasData = false;
      headers.forEach((header, index) {
        final value = index < rows[i].length ? _cellText(rows[i][index]).trim() : '';
        if (value.isNotEmpty) hasData = true;
        values[header] = value;
      });
      if (hasData) parsed.add(_ExcelRow(rowNumber: i + 1, values: values));
    }
    return parsed;
  }

  Map<String, Branch> _branchLookup(List<Branch> branches) {
    final map = <String, Branch>{};
    for (final branch in branches) {
      map[_norm(branch.id.toString())] = branch;
      map[_norm(branch.code)] = branch;
      map[_norm(branch.name)] = branch;
      map[_norm('${branch.name} (${branch.code})')] = branch;
    }
    return map;
  }

  String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    if (value is TextCellValue) return value.value.text ?? value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value ? 'true' : 'false';
    if (value is DateCellValue) return _date(value.asDateTimeLocal());
    if (value is DateTimeCellValue) return value.asDateTimeLocal().toIso8601String();
    return value.toString();
  }

  String _date(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  int? _int(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  bool? _bool(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    if (['true', 'yes', 'y', '1', 'active'].contains(trimmed)) return true;
    if (['false', 'no', 'n', '0', 'inactive', 'disabled'].contains(trimmed)) return false;
    return null;
  }

  String _norm(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ' ');

  String _cleanError(Object err) => err.toString().replaceFirst('Exception: ', '');
}

class _ExcelRow {
  const _ExcelRow({required this.rowNumber, required this.values});

  final int rowNumber;
  final Map<String, String> values;

  String value(List<String> keys) {
    for (final key in keys) {
      final value = values[_normalize(key)];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String _normalize(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ' ');
}
