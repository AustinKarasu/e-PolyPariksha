import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../config/app_theme.dart';
import '../models/student_test.dart';
import '../services/api_client.dart';
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
  String? _errorMessage;
  bool _pdfViewerFailed = false;
  int _currentPage = 0;
  int _totalPages = 0;
  late DateTime _startedAt;
  Timer? _timer;
  Timer? _heartbeatTimer;
  int _elapsedSeconds = 0;
  bool _completedByTimer = false;
  bool _leavingExam = false;
  bool _heartbeatInFlight = false;
  final Map<String, int> _navigationAttempts = {};

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
    _heartbeatTimer?.cancel();
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
        setState(() =>
            _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds);
        if (!_locked &&
            !_completedByTimer &&
            _elapsedSeconds >= widget.test.timeLimitMinutes * 60) {
          _completedByTimer = true;
          unawaited(_complete(autoSubmitted: true));
        }
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_sendHeartbeat());
    });
    unawaited(_sendHeartbeat());
  }

  String get _formattedTime {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get _remainingMinutes =>
      widget.test.timeLimitMinutes - (_elapsedSeconds ~/ 60);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.reviewOnly || _leavingExam) return;
    if (state == AppLifecycleState.inactive) {
      setState(() => _hasFocusWarning = true);
      unawaited(_logEvent('app_inactive'));
    }
    if (state == AppLifecycleState.paused) {
      setState(() => _hasFocusWarning = true);
      unawaited(_logNavigationAttempt('home_navigation_attempt'));
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
          unawaited(_logNavigationAttempt('back_navigation_attempt'));
        }
      },
      child: Scaffold(
        // ── Exam AppBar ──
        appBar: AppBar(
          automaticallyImplyLeading: widget.reviewOnly,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: _locked
                  ? const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)])
                  : AppTheme.headerGradient,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.test.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!_loading && !_locked)
                Text(
                  _totalPages > 0
                      ? 'Page ${_currentPage + 1} of $_totalPages'
                      : '',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                ),
            ],
          ),
          actions: [
            // ── Timer chip ──
            if (!widget.reviewOnly && !_loading && !_locked)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      color: _remainingMinutes <= 5
                          ? Colors.yellow
                          : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formattedTime,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _remainingMinutes <= 5
                            ? Colors.yellow
                            : Colors.white,
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
                icon: const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 20),
                label: const Text('Submit',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
          ],
        ),

        body: Column(
          children: [
            // ── Warning banner ──
            if (!widget.reviewOnly && _hasFocusWarning)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: _locked
                    ? AppTheme.error.withValues(alpha: 0.1)
                    : AppTheme.accent.withValues(alpha: 0.1),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          _locked
                              ? Icons.lock_rounded
                              : Icons.warning_amber_rounded,
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
                            onPressed: () =>
                                setState(() => _hasFocusWarning = false),
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
                          const CircularProgressIndicator(
                              color: AppTheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Loading question paper…',
                            style: TextStyle(
                                color: AppTheme.ink.withValues(alpha: 0.5)),
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
                                    color:
                                        AppTheme.error.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lock_rounded,
                                      size: 40, color: AppTheme.error),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Paper Locked',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Admin permission is required to reopen this test. Contact your invigilator.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color:
                                          AppTheme.ink.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _pdfPath == null || _pdfViewerFailed
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.picture_as_pdf_outlined,
                                        size: 56, color: AppTheme.error),
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorMessage ?? 'Unable to open PDF.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: AppTheme.ink
                                              .withValues(alpha: 0.65)),
                                    ),
                                    if (_pdfPath != null) ...[
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: () => OpenFilex.open(
                                            _pdfPath!,
                                            type: 'application/pdf'),
                                        icon: const Icon(
                                            Icons.open_in_new_rounded),
                                        label: const Text('Open with PDF app'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : PDFView(
                              filePath: _pdfPath!,
                              enableSwipe: true,
                              swipeHorizontal: false,
                              autoSpacing: true,
                              pageFling: true,
                              onRender: (pages) =>
                                  setState(() => _totalPages = pages ?? 0),
                              onPageChanged: (page, _) =>
                                  setState(() => _currentPage = page ?? 0),
                              onError: (error) => setState(() {
                                _pdfViewerFailed = true;
                                _errorMessage =
                                    'Unable to display this PDF. Please ask the admin to re-upload it.';
                              }),
                              onPageError: (_, error) => setState(() {
                                _pdfViewerFailed = true;
                                _errorMessage =
                                    'Unable to display this PDF page. Please ask the admin to re-upload it.';
                              }),
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
      if (await _securityService.isInMultiWindowMode()) {
        await _securityService.exitExamMode();
        if (mounted) {
          setState(() {
            _errorMessage =
                'Close split-screen or picture-in-picture mode before starting the test.';
            _loading = false;
          });
        }
        return;
      }
      await _testService.startAttempt(widget.test.id);
      _startHeartbeat();
      final path = await _testService.downloadPdf(widget.test.id);
      await _testService.recordEvent(widget.test.id, 'pdf_opened');
      if (mounted) {
        setState(() {
          _pdfPath = path;
          _pdfViewerFailed = false;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        final isLocked = _looksLikeLockedAttempt(error.message);
        setState(() {
          _locked = isLocked;
          _hasFocusWarning = isLocked;
          _errorMessage = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to load the question paper. Please check your connection and try again.';
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
          _pdfViewerFailed = false;
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
      _heartbeatTimer?.cancel();
      if (autoSubmitted) {
        try {
          await _testService.recordEvent(widget.test.id, 'time_limit_reached');
        } catch (_) {}
      }
      await _testService.completeAttempt(widget.test.id);
      await _deleteLocalPdf();
      _leavingExam = true;
      await _securityService.exitExamMode();
      if (mounted) {
        if (autoSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Time limit reached. Test submitted.')));
        }
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to submit. Please try again.')));
      }
    }
  }

  Future<void> _logNavigationAttempt(String eventType) {
    final attempts = (_navigationAttempts[eventType] ?? 0) + 1;
    _navigationAttempts[eventType] = attempts;
    return _logEvent(eventType, metadata: {'navigationAttempts': attempts});
  }

  Future<void> _logEvent(String eventType,
      {Map<String, dynamic>? metadata}) async {
    try {
      final locked = await _testService.recordEvent(widget.test.id, eventType,
          metadata: {..._eventMetadata(), ...?metadata});
      if (locked && mounted) {
        await _deleteLocalPdf();
        _heartbeatTimer?.cancel();
        setState(() {
          _locked = true;
          _hasFocusWarning = true;
          _pdfPath = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendHeartbeat() async {
    if (widget.reviewOnly || _locked || _leavingExam || _heartbeatInFlight) {
      return;
    }
    _heartbeatInFlight = true;
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await _securityService.reassertExamMode();
      if (await _securityService.isInMultiWindowMode()) {
        await _logNavigationAttempt('split_screen_attempt');
      } else {
        await _logEvent('exam_heartbeat');
      }
    } finally {
      _heartbeatInFlight = false;
    }
  }

  Map<String, dynamic> _eventMetadata() {
    return {
      'elapsedSeconds': _elapsedSeconds,
      'currentPage': _currentPage + 1,
      'totalPages': _totalPages,
      'loaded': !_loading,
    };
  }

  Future<void> _deleteLocalPdf() async {
    final path = _pdfPath;
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  bool _looksLikeLockedAttempt(String message) {
    final lower = message.toLowerCase();
    return lower.contains('locked') ||
        lower.contains('blocked') ||
        lower.contains('admin permission');
  }
}
