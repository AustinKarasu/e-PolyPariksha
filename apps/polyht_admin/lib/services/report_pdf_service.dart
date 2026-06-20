import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/attempt_report.dart';

class ReportPdfService {
  Future<File> exportAttemptReports(List<AttemptReport> reports) async {
    final pdf = pw.Document();
    final generatedAt = DateTime.now();
    final byTest = _groupByTest(reports);
    final logo = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 28),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        header: (context) => _header(generatedAt, logo),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('e-PolyPariksha HP Attempt Reports', style: _mutedStyle(8)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: _mutedStyle(8)),
          ],
        ),
        build: (context) => [
          _summaryStrip(reports, byTest.length),
          pw.SizedBox(height: 14),
          ...byTest.entries.expand((entry) => [
                _testHeading(entry.key, entry.value),
                pw.SizedBox(height: 8),
                _studentTable(entry.value),
                pw.SizedBox(height: 10),
                ...entry.value.map(_studentDetail),
                pw.SizedBox(height: 16),
              ]),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/polyht_attempt_report_${generatedAt.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<void> open(File file) => OpenFilex.open(file.path);

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/polyht_logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _header(DateTime generatedAt, pw.MemoryImage? logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom:
                pw.BorderSide(color: PdfColor.fromInt(0xFFDBE3F0), width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _logoMark(logo),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('e-PolyPariksha HP',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF153E75))),
                pw.SizedBox(height: 2),
                pw.Text('Student Test Attempt Report',
                    style: const pw.TextStyle(
                        fontSize: 12, color: PdfColor.fromInt(0xFF41546B))),
              ],
            ),
          ),
          pw.Text('Generated ${_dateTime(generatedAt)}', style: _mutedStyle(9)),
        ],
      ),
    );
  }

  pw.Widget _logoMark(pw.MemoryImage? logo) {
    if (logo != null) {
      return pw.Container(
        width: 48,
        height: 48,
        padding: const pw.EdgeInsets.all(3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
              color: const PdfColor.fromInt(0xFFDBE3F0), width: 0.8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 6,
          verticalRadius: 6,
          child: pw.Image(logo, fit: pw.BoxFit.cover),
        ),
      );
    }
    return pw.Container(
      width: 46,
      height: 46,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF153E75),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text('PH',
          style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _summaryStrip(List<AttemptReport> reports, int testCount) {
    final blocked =
        reports.where((report) => report.blockedActions.isNotEmpty).length;
    final completed = reports
        .where((report) =>
            report.completedAt != null || report.status == 'completed')
        .length;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F8FC),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _metric('Tests', '$testCount'),
          _metric('Attempts', '${reports.length}'),
          _metric('Submitted', '$completed'),
          _metric('Blocked', '$blocked'),
        ],
      ),
    );
  }

  pw.Widget _metric(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: _mutedStyle(8)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF153E75))),
      ],
    );
  }

  pw.Widget _testHeading(String title, List<AttemptReport> reports) {
    final first = reports.first;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFDBE3F0)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Branch: ${first.branchName}   Semester: ${first.semester}   Attempts: ${reports.length}',
            style: _mutedStyle(9),
          ),
          pw.Text(
            'Test window: ${_dateTime(_earliestStarted(reports))} to ${_dateTime(_latestSubmittedOrSeen(reports))}',
            style: _mutedStyle(9),
          ),
        ],
      ),
    );
  }

  pw.Widget _studentTable(List<AttemptReport> reports) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(
          color: const PdfColor.fromInt(0xFFE3E8EF), width: 0.5),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFF153E75)),
      headerStyle: pw.TextStyle(
          color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.all(5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1.3),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.5),
      },
      headers: [
        'Student',
        'Board Roll',
        'Time Taken',
        'Submitted',
        'Blocked Actions'
      ],
      data: reports
          .map((report) => [
                report.fullName,
                report.boardRollNo ?? '-',
                _duration(report.timeTakenSeconds),
                _dateTime(report.completedAt),
                _blockedActions(report),
              ])
          .toList(),
    );
  }

  pw.Widget _studentDetail(AttemptReport report) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFBFD),
        border: pw.Border.all(
            color: const PdfColor.fromInt(0xFFE3E8EF), width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(report.fullName,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 12,
            runSpacing: 3,
            children: [
              _inline('Board roll no', report.boardRollNo),
              _inline('Roll no', report.rollNo),
              _inline('Mobile', report.phone),
              _inline('Email', report.email),
              _inline('Course', report.courseName),
              _inline('College', report.collegeName),
              _inline('College ID', report.collegeId),
              _inline('Started', _dateTime(report.startedAt)),
              _inline('Submitted', _dateTime(report.completedAt)),
              _inline('Last seen', _dateTime(report.lastSeenAt)),
              _inline('Status', report.status),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text('AI report: ${report.aiSummary}',
              style: const pw.TextStyle(fontSize: 8.5)),
        ],
      ),
    );
  }

  pw.Widget _inline(String label, String? value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(
              text: (value == null || value.isEmpty) ? '-' : value,
              style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  Map<String, List<AttemptReport>> _groupByTest(List<AttemptReport> reports) {
    final map = <String, List<AttemptReport>>{};
    for (final report in reports) {
      map.putIfAbsent(report.testTitle, () => []).add(report);
    }
    for (final group in map.values) {
      group.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    }
    return map;
  }

  DateTime? _earliestStarted(List<AttemptReport> reports) {
    final dates = reports
        .map((report) => report.startedAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return dates.isEmpty ? null : dates.first;
  }

  DateTime? _latestSubmittedOrSeen(List<AttemptReport> reports) {
    final dates = reports
        .map((report) => report.completedAt ?? report.lastSeenAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return dates.isEmpty ? null : dates.last;
  }

  String _duration(int? seconds) {
    if (seconds == null) return '-';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m ${secs}s';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  String _dateTime(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
  }

  String _blockedActions(AttemptReport report) {
    if (report.blockedActions.isEmpty) return 'None';
    return report.blockedActions
        .map((event) => event.eventType.replaceAll('_', ' '))
        .toSet()
        .join(', ');
  }

  pw.TextStyle _mutedStyle(double size) =>
      pw.TextStyle(fontSize: size, color: const PdfColor.fromInt(0xFF64748B));
}
