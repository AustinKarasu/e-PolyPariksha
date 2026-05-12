import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/student_test.dart';
import '../services/exam_security_service.dart';
import '../services/test_service.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.test, this.reviewOnly = false});

  final StudentTest test;
  final bool reviewOnly;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  final _testService = TestService();
  final _securityService = ExamSecurityService();
  String? _pdfPath;
  bool _loading = true;
  bool _hasFocusWarning = false;
  bool _locked = false;
  int _currentPage = 0;
  int _totalPages = 0;
  late DateTime _startedAt;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _completedByTimer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startedAt = DateTime.now();
    if (widget.reviewOnly) {
      _loadCompletedPaper();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _securityService.setEventHandler(_logEvent);
      _startTimer();
      _enterExam();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!widget.reviewOnly) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _securityService.exitExamMode();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds);
        if (!_locked && !_completedByTimer && _elapsedSeconds >= widget.test.timeLimitMinutes * 60) {
          _completedByTimer = true;
          unawaited(_complete(autoSubmitted: true));
        }
      }
    });
  }

  String get _formattedTime {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get _remainingMinutes => widget.test.timeLimitMinutes - (_elapsedSeconds ~/ 60);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.reviewOnly) return;
    if (state == AppLifecycleState.inactive) {
      setState(() => _hasFocusWarning = true);
      unawaited(_logEvent('app_inactive'));
    }
    if (state == AppLifecycleState.paused) {
      setState(() => _hasFocusWarning = true);
      unawaited(_logEvent('app_backgrounded'));
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_logEvent('app_resumed'));
    }
    if (state == AppLifecycleState.detached) {
      unawaited(_logEvent('app_detached'));
    }
    if (state == AppLifecycleState.hidden) {
      setState(() => _hasFocusWarning = true);
      unawaited(_logEvent('app_hidden'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.reviewOnly,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_logEvent('back_blocked'));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Back navigation is disabled during the exam.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        // ── Exam AppBar ──
        appBar: AppBar(
          automaticallyImplyLeading: widget.reviewOnly,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: _locked
                  ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFB91C1C)])
                  : AppTheme.headerGradient,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.test.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!_loading && !_locked)
                Text(
                  _totalPages > 0 ? 'Page ${_currentPage + 1} of $_totalPages' : '',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                ),
            ],
          ),
          actions: [
            // ── Timer chip ──
            if (!widget.reviewOnly && !_loading && !_locked)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _remainingMinutes <= 5
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: _remainingMinutes <= 5 ? Colors.yellow : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formattedTime,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _remainingMinutes <= 5 ? Colors.yellow : Colors.white,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            // ── Submit button ──
            if (!widget.reviewOnly)
              TextButton.icon(
                onPressed: _locked ? null : _confirmComplete,
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                label: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
          ],
        ),

        body: Column(
          children: [
            // ── Warning banner ──
            if (!widget.reviewOnly && _hasFocusWarning)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: _locked ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.accent.withValues(alpha: 0.1),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          _locked ? Icons.lock_rounded : Icons.warning_amber_rounded,
                          size: 20,
                          color: _locked ? AppTheme.error : AppTheme.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _locked
                                ? 'This paper is locked. Contact your admin to reopen.'
                                : 'App switching detected. Your attempt may be reviewed.',
                            style: TextStyle(
                              fontSize: 13,
                              color: _locked ? AppTheme.error : AppTheme.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (!_locked)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _hasFocusWarning = false),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── PDF / Loading / Locked ──
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppTheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Loading question paper…',
                            style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    )
                  : _locked
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lock_rounded, size: 40, color: AppTheme.error),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Paper Locked',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Admin permission is required to reopen this test. Contact your invigilator.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _pdfPath == null
                          ? const Center(child: Text('Unable to open PDF.'))
                          : PDFView(
                              filePath: _pdfPath!,
                              enableSwipe: true,
                              swipeHorizontal: false,
                              autoSpacing: true,
                              pageFling: true,
                              onRender: (pages) => setState(() => _totalPages = pages ?? 0),
                              onPageChanged: (page, _) => setState(() => _currentPage = page ?? 0),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterExam() async {
    try {
      await _securityService.enterExamMode();
      await _testService.startAttempt(widget.test.id);
      if (await _securityService.isInMultiWindowMode()) {
        await _logEvent('split_screen_detected');
      }
      final path = await _testService.downloadPdf(widget.test.id);
      await _testService.recordEvent(widget.test.id, 'pdf_opened');
      if (mounted) {
        setState(() {
          _pdfPath = path;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locked = true;
          _hasFocusWarning = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCompletedPaper() async {
    try {
      final path = await _testService.downloadPdf(widget.test.id);
      if (mounted) {
        setState(() {
          _pdfPath = path;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmComplete() async {
    if (_locked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Submit test?'),
        content: const Text(
          'Once submitted, you will not be able to reopen this paper. Make sure you have completed all questions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _complete();
    }
  }

  Future<void> _complete({bool autoSubmitted = false}) async {
    if (_locked) return;
    try {
      if (autoSubmitted) {
        await _testService.recordEvent(widget.test.id, 'time_limit_reached');
      }
      await _testService.completeAttempt(widget.test.id);
      await _deleteLocalPdf();
      await _securityService.exitExamMode();
      if (mounted) {
        if (autoSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time limit reached. Test submitted.')));
        }
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locked = true;
          _hasFocusWarning = true;
        });
      }
    }
  }

  Future<void> _logEvent(String eventType) async {
    try {
      final locked = await _testService.recordEvent(widget.test.id, eventType);
      if (locked && mounted) {
        await _deleteLocalPdf();
        setState(() {
          _locked = true;
          _hasFocusWarning = true;
          _pdfPath = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteLocalPdf() async {
    final path = _pdfPath;
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
