import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' as ex;

import 'package:ptu/models/app_data.dart';
import '../main.dart';
class AssignmentInteractionScreen extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final Color classColor;
  final Map<String, dynamic> classData;

  const AssignmentInteractionScreen({
    super.key,
    required this.assignment,
    required this.classColor,
    required this.classData,
  });

  @override
  State<AssignmentInteractionScreen> createState() =>
      _AssignmentInteractionScreenState();
}
class _AssignmentInteractionScreenState
    extends State<AssignmentInteractionScreen>
    with WidgetsBindingObserver {
  int currentMcqIndex = 0;
  final Map<int, int> mcqAnswers = {};
  Timer? _mcqTimer;
  int _mcqTimeLeft = 30;
  int _tabSwitchCount = 0;
  int _backPressCount = 0;
  bool _isNavigatingOut = false;
  final Set<int> _visitedMcqIndices = {};

  bool _isWarningDialogShown = false;
  bool _hasTabSwitchPending = false;
  bool _isMcqStartPressed = false;
  bool _isTimeOverSplashVisible = false;

  List<dynamic> _shuffledMcqData = [];

  Timer? _clockTimer;
  List<String> _dos = [];
  List<String> _donts = [];
  bool _isLoadingInstructions = true;

  void _loadGlobalInstruction() async {
    final Map<String, List<String>> result = await AppData()
        .fetchMcqInstruction();
    if (mounted) {
      setState(() {
        _dos = result['dos'] ?? [];
        _donts = result['donts'] ?? [];
        _isLoadingInstructions = false;
      });
    }
  }

  get stdId => null;

  @override
  void initState() {
    super.initState();
    _loadGlobalInstruction();
    WidgetsBinding.instance.addObserver(this);
    bool isStudent = AppData().currentUserRole == UserRole.student;
    bool isTurnedIn = widget.assignment['isDone'] ?? false;

    // Tick every second so the "not started yet" screen auto-unlocks when start time arrives
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        // Auto-redirect if deadline passes while on instruction screen
        if (AppData().currentUserRole == UserRole.student &&
            !_isNavigatingOut &&
            !(widget.assignment['isDone'] ?? false)) {
          DateTime? dueTime = widget.assignment['dueDateTime'];
          if (dueTime != null && DateTime.now().isAfter(dueTime)) {
            _handleTimeEnd();
          }
        }
      }
    });
    DateTime? startTime = widget.assignment['startDateTime'];
    DateTime? dueTime = widget.assignment['dueDateTime'];

    if (isStudent &&
        !isTurnedIn &&
        dueTime != null &&
        DateTime.now().isAfter(dueTime)) {
      isTurnedIn = true;
      // submit automatically as missed or with current progress
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTimeEnd();
      });
    }

    if (isStudent &&
        !isTurnedIn &&
        widget.assignment['mcqData'] != null &&
        _isMcqStartPressed) {
      if (startTime == null || !DateTime.now().isBefore(startTime)) {
        _startMcqTimer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mcqTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bool isStudent = AppData().currentUserRole == UserRole.student;
    bool isTurnedIn = widget.assignment['isDone'] ?? false;
    bool isMcq = widget.assignment['mcqData'] != null;

    bool isFlaggedSetting = widget.assignment['isFlagged'] ?? false;

    if (isStudent &&
        !isTurnedIn &&
        isMcq &&
        _isMcqStartPressed &&
        isFlaggedSetting) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused) {
        _hasTabSwitchPending = true;
      } else if (state == AppLifecycleState.resumed && _hasTabSwitchPending) {
        _hasTabSwitchPending = false;
        _tabSwitchCount++;
        _handleTabSwitchEnforcement();
      }
    }
  }

  void _handleTabSwitchEnforcement() {
    if (_tabSwitchCount == 1 && !_isWarningDialogShown) {
      _isWarningDialogShown = true;
      _showSecurityWarning(
        'SECURITY ALERT: Tab switching or leaving the test window is strictly prohibited. '
        'You have been detected leaving the test once. This is your FINAL WARNING. '
        'If you switch again (2nd time), your test will be terminated immediately and flagged as cheating.',
      );
    } else if (_tabSwitchCount >= 2) {
      _submitMcq(isFlagged: true);
    }
  }

  void _handleBackPress() {
    bool isStudent = AppData().currentUserRole == UserRole.student;
    bool isTurnedIn = widget.assignment['isDone'] ?? false;
    bool isMcq = widget.assignment['mcqData'] != null;

    bool isFlaggedSetting = widget.assignment['isFlagged'] ?? false;

    if (isStudent &&
        !isTurnedIn &&
        isMcq &&
        _isMcqStartPressed &&
        isFlaggedSetting) {
      _backPressCount++;
      if (_backPressCount == 1 && !_isWarningDialogShown) {
        _isWarningDialogShown = true;
        _showSecurityWarning(
          'Going back during the test is strictly prohibited. '
          'You have attempted to go back once. If you do it again, your test will be '
          'automatically ended and submitted as a flagged attempt.',
        );
      } else if (_backPressCount >= 2) {
        _submitMcq(isFlagged: true);
      }
    } else {
      // For non-MCQ, already finished, or before test start, or if flagging is disabled, just pop normally
      Navigator.pop(context);
    }
  }

  void _showSecurityWarning(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Security Warning'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _isWarningDialogShown = false;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
            ),
            child: const Text(
              'I Understand',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getOverallTimeLeft() {
    DateTime? dueTime = widget.assignment['dueDateTime'];
    if (dueTime == null) return "No Limit";

    Duration diff = dueTime.difference(DateTime.now());
    if (diff.isNegative) return "00:00:00";

    String h = diff.inHours.toString().padLeft(2, '0');
    String m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    String s = (diff.inSeconds % 60).toString().padLeft(2, '0');

    return "$h:$m:$s";
  }

  Widget _buildInstructionItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withAlpha(200), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startMcqTimer() {
    _mcqTimer?.cancel();
    final timePerQ = widget.assignment['timePerQuestion'] ?? 30;
    if (timePerQ <= 0) {
      _mcqTimeLeft = -1;
      return;
    }
    _mcqTimeLeft = timePerQ;
    _mcqTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_mcqTimeLeft > 0) {
            _mcqTimeLeft--;
          } else {
            _moveToNextQuestionOrSubmit();
          }
        });
      }
    });
  }

  void _moveToNextQuestionOrSubmit() {
    List<dynamic> mcqData = _shuffledMcqData.isNotEmpty
        ? _shuffledMcqData
        : (widget.assignment['mcqData'] as List<dynamic>);

    setState(() {
      _visitedMcqIndices.add(currentMcqIndex);
      if (currentMcqIndex < mcqData.length - 1) {
        currentMcqIndex++;
        _startMcqTimer();
      } else {
        int firstUnanswered = -1;
        for (int i = 0; i < mcqData.length; i++) {
          if (!mcqAnswers.containsKey(i)) {
            firstUnanswered = i;
            break;
          }
        }

        if (firstUnanswered != -1 && _mcqTimeLeft != 0) {
          _showUnansweredWarningDialog(firstUnanswered);
        } else {
          _mcqTimer?.cancel();
          _submitMcq();
        }
      }
    });
  }

  void _showUnansweredWarningDialog(int firstUnanswered) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Incomplete Test'),
          ],
        ),
        content: const Text(
          'You have some unanswered questions and there is still time left. Do you want to go back and complete them, or submit your test now?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _jumpToQuestion(firstUnanswered);
            },
            child: const Text('Complete Test'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _mcqTimer?.cancel();
              _submitMcq();
            },
            style: ElevatedButton.styleFrom(backgroundColor: widget.classColor),
            child: const Text(
              'Submit Anyway',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _jumpToQuestion(int index) {
    List<dynamic> mcqData = _shuffledMcqData.isNotEmpty
        ? _shuffledMcqData
        : (widget.assignment['mcqData'] as List<dynamic>);

    if (index >= 0 && index < mcqData.length) {
      setState(() {
        _visitedMcqIndices.add(currentMcqIndex);
        currentMcqIndex = index;
        _startMcqTimer();
      });
    }
  }

  void _shuffleQuestionsAndOptions() {
    final originalData = widget.assignment['mcqData'] as List<dynamic>;
    // Create a deep-ish copy to avoid modifying original ref
    List<dynamic> workingData = originalData
        .map((q) => Map<String, dynamic>.from(q))
        .toList();

    final random = Random();

    for (var q in workingData) {
      if (q['options'] is List) {
        List options = List.from(q['options']);
        // Identify correct answer before shuffling
        dynamic ansIdx =
            q['answerIndex'] ??
            q['answer'] ??
            q['correctAnswer'] ??
            q['correctIndex'];
        String? correctAnswerText;

        if (ansIdx is int && ansIdx < options.length) {
          correctAnswerText = options[ansIdx].toString();
        } else if (ansIdx != null) {
          // If it's already a string, check if it matches any option
          String s = ansIdx.toString().toLowerCase().trim();
          for (var opt in options) {
            if (opt.toString().toLowerCase().trim() == s) {
              correctAnswerText = opt.toString();
              break;
            }
          }
        }

        // Shuffle options
        options.shuffle(random);
        q['options'] = options;

        // Update correct answer index
        if (correctAnswerText != null) {
          for (int i = 0; i < options.length; i++) {
            if (options[i].toString() == correctAnswerText) {
              q['answerIndex'] = i;
              break;
            }
          }
        }
      }
    }

    // Shuffle questions
    workingData.shuffle(random);

    // Take subset if requested
    int? questionsToShow = widget.assignment['questionsToShow'];
    if (questionsToShow != null &&
        questionsToShow > 0 &&
        questionsToShow < workingData.length) {
      _shuffledMcqData = workingData.take(questionsToShow).toList();
    } else {
      _shuffledMcqData = workingData;
    }
  }

  void _submitMcq({bool isFlagged = false}) {
    _mcqTimer?.cancel();

    int score = 0;
    List<dynamic> mcqData = _shuffledMcqData.isNotEmpty
        ? _shuffledMcqData
        : (widget.assignment['mcqData'] as List<dynamic>);

    // If flagged for cheating (e.g., 3 mobile detections), score is automatically 0
    if (!isFlagged) {
      for (int j = 0; j < mcqData.length; j++) {
        var q = mcqData[j];
        var ans =
            q['answerIndex'] ??
            q['answer'] ??
            q['correctAnswer'] ??
            q['correctIndex'];

        // If it's an index, we compare it with the selected index
        // If it's text, we compare it with the selected text
        String? expected = ans?.toString().trim().toLowerCase();
        String? selectedId = mcqAnswers[j]?.toString().trim().toLowerCase();
        String? selectedText = mcqAnswers[j] != null
            ? q['options'][mcqAnswers[j]!].toString().trim().toLowerCase()
            : null;

        if (expected != null &&
            (selectedId == expected || selectedText == expected)) {
          score++;
        }
      }
    }

    AppData().submitMcqQuiz(
      widget.assignment['id'],
      score,
      answers: mcqAnswers,
      presentedQuestions: mcqData,
      isFlagged: isFlagged,
    );

    // Instead of popping, we just let the UI rebuild to show results.
    // If it was a manual finish, we can show a small message.
    if (!isFlagged && mounted && !_isTimeOverSplashVisible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test Submitted Successfully!')),
      );
    }
  }

  void _handleTimeEnd() async {
    if (_isNavigatingOut) return;
    _isNavigatingOut = true;

    if (mounted) {
      setState(() {
        _isTimeOverSplashVisible = true;
      });
    }

    _submitMcq(); // Submit with current progress

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isTimeOverSplashVisible = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
    );
    if (result != null) {
      AppData().submitFiles(widget.assignment['id'], result.files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    bool isStudent = AppData().currentUserRole == UserRole.student;
    bool isTurnedIn = widget.assignment['isDone'] ?? false;
    bool isMcq = widget.assignment['mcqData'] != null;

    return PopScope(
      canPop: !(isStudent && !isTurnedIn && isMcq && _isMcqStartPressed),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: (isStudent && !isTurnedIn && isMcq && _isMcqStartPressed)
            ? null // Full screen for quiz after start
            : AppBar(title: Text(isMcq ? 'MCQ Status' : 'Assignment Details')),
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: AppData(),
              builder: (context, _) {
                List<PlatformFile> attachedFiles =
                    AppData().assignmentSubmissions[widget.assignment['id']] ??
                    [];
                bool isTurnedIn = widget.assignment['isDone'] ?? false;

                DateTime? dueTime = widget.assignment['dueDateTime'];
                bool isPastDue =
                    dueTime != null && DateTime.now().isAfter(dueTime);

                if (AppData().currentUserRole == UserRole.student &&
                    !isTurnedIn &&
                    isPastDue) {
                  isTurnedIn = true;
                }

                Widget heroBanner = LayoutBuilder(
                  builder: (context, constraints) {
                    bool isMobileBanner = constraints.maxWidth < 600;

                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobileBanner ? 20 : 32,
                        vertical: isMobileBanner ? 20 : 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.classColor.withAlpha(20),
                            widget.classColor.withAlpha(5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: widget.classColor.withAlpha(50),
                        ),
                      ),
                      child: isMobileBanner
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.classColor.withAlpha(20),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.assignment['mcqData'] != null
                                        ? Icons.quiz_outlined
                                        : Icons.assignment_outlined,
                                    color: widget.classColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.assignment['title'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildDateBadge(),
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.classColor.withAlpha(20),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.assignment['mcqData'] != null
                                        ? Icons.quiz_outlined
                                        : Icons.assignment_outlined,
                                    color: widget.classColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.assignment['title'],
                                        style: GoogleFonts.outfit(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildDateBadge(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                );

                if (isTeacher) {
                  return FutureBuilder(
                    future: AppData().fetchAssignmentStatusesForTeacher(
                      widget.assignment['id'],
                      isMcq: widget.assignment['mcqData'] != null,
                    ),
                    builder: (context, snapshot) {
                      double width = MediaQuery.of(context).size.width;
                      double padding = width < 700 ? 16 : 40;

                      return Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heroBanner,
                            const SizedBox(height: 32),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: _buildTeacherReviewPanel(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                if (widget.assignment['mcqData'] != null) {
                  return _buildStudentMcqPanel(
                    _shuffledMcqData.isNotEmpty
                        ? _shuffledMcqData
                        : (widget.assignment['mcqData'] as List<dynamic>),
                    isTurnedIn,
                  );
                }

                return SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16.0 : 40.0),
                    child: Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isMobile ? 0 : 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              heroBanner,
                              if (widget.assignment['mcqData'] == null) ...[
                                const SizedBox(height: 32),
                                if (widget.assignment['instructorFileName'] !=
                                    null) ...[
                                  const Text(
                                    'Teacher\'s Posted File',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () async {
                                      final assignmentId =
                                          widget.assignment['id'];
                                      final fName = widget
                                          .assignment['instructorFileName'];
                                      final storagePath =
                                          '$assignmentId/$fName';

                                      final String publicUrl = supabase.storage
                                          .from('assignment-files')
                                          .getPublicUrl(storagePath);

                                      final Uri uri = Uri.parse(publicUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not open file URL',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(5),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: widget.classColor
                                                  .withAlpha(20),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.description,
                                              color: widget.classColor,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  widget
                                                      .assignment['instructorFileName'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const Text(
                                                  'Assignment Reference Material (Tap to View)',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                                const Text(
                                  'Instructions',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    'Please review the attached material and submit your workings.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade800,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isMobile)
                          const SizedBox(height: 32)
                        else
                          const SizedBox(width: 40),
                        Expanded(
                          flex: isMobile ? 0 : 2,
                          child: (isPastDue && attachedFiles.isEmpty)
                              ? _buildSubmissionClosedPanel()
                              : _buildStudentUploadPanel(
                                  attachedFiles,
                                  isTurnedIn,
                                  isPastDue,
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_isTimeOverSplashVisible) _buildTimeOverSplash(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOverSplash() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_off_rounded,
                size: 150,
                color: Colors.orange,
              ),
              const SizedBox(height: 48),
              Text(
                'Time Over!',
                style: GoogleFonts.outfit(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Submitting your responses...',
                style: TextStyle(fontSize: 24, color: Colors.grey),
              ),
              const SizedBox(height: 64),
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentUploadPanel(
    List<PlatformFile> attachedFiles,
    bool isTurnedIn,
    bool isPastDue,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Work',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isTurnedIn
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isTurnedIn
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  isTurnedIn
                      ? (isPastDue && widget.assignment['isDone'] != true
                            ? 'Missing'
                            : 'Turned in')
                      : 'Assigned',
                  style: TextStyle(
                    color: isTurnedIn
                        ? (isPastDue && widget.assignment['isDone'] != true
                              ? Colors.red.shade700
                              : Colors.green.shade700)
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          ...List.generate(attachedFiles.length, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart, color: Colors.green),
                ),
                title: Text(
                  attachedFiles[i].name,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: (isTurnedIn || isPastDue)
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () =>
                            AppData().removeFile(widget.assignment['id'], i),
                      ),
              ),
            );
          }),

          if (!isTurnedIn && attachedFiles.isEmpty && !isPastDue) ...[
            InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(16),
              child: DottedBorder(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.classColor.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add,
                          color: widget.classColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Add or Create Work',
                        style: TextStyle(
                          color: widget.classColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Builder(
            builder: (context) {
              int subCount =
                  AppData().assignmentSubmissionCounts[widget
                      .assignment['id']] ??
                  0;
              int unsubmitCount =
                  AppData().assignmentUnsubmitCounts[widget.assignment['id']] ??
                  0;
              bool limitReached = subCount >= 2;
              bool undoLimitReached = unsubmitCount >= 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isTurnedIn)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Submissions: $subCount / 2',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: limitReached
                              ? Colors.red
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  if (isTurnedIn && undoLimitReached)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No more changes allowed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed:
                        ((limitReached && !isTurnedIn) ||
                            (undoLimitReached && isTurnedIn) ||
                            isPastDue)
                        ? null
                        : () => AppData().toggleTurnIn(widget.assignment['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTurnedIn
                          ? Colors.white
                          : widget.classColor,
                      foregroundColor: isTurnedIn
                          ? Colors.black87
                          : Colors.white,
                      elevation: isTurnedIn ? 0 : 4,
                      shadowColor: widget.classColor.withAlpha(100),
                      disabledBackgroundColor: Colors.grey.shade300,
                      side: isTurnedIn
                          ? BorderSide(color: Colors.grey.shade300, width: 2)
                          : BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isTurnedIn
                          ? (isPastDue
                                ? 'Submission Closed'
                                : (undoLimitReached
                                      ? 'Final Submission'
                                      : 'Unsubmit Work'))
                          : (limitReached
                                ? 'Limit Reached'
                                : (attachedFiles.isEmpty
                                      ? 'Mark as done'
                                      : 'Turn In Final')),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(150),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note_rounded, size: 16, color: widget.classColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              (widget.assignment['startDateTime'] != null &&
                      widget.assignment['dueDateTime'] != null)
                  ? 'Window: ${widget.assignment['startDateTime'].toString().substring(0, 16)} to ${widget.assignment['dueDateTime'].toString().substring(0, 16)}'
                  : 'Due by ${widget.assignment['dueDate']}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionClosedPanel() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text(
            'Submission Closed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The due date for this assignment has passed. No further submissions are allowed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentMcqPanel(List<dynamic> mcqData, bool isTurnedIn) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    // Reload startTime fresh from assignment map every build
    final rawStart = widget.assignment['startDateTime'];
    DateTime? startTime;
    if (rawStart is DateTime) {
      startTime = rawStart;
    } else if (rawStart is String) {
      startTime = DateTime.tryParse(rawStart);
    }

    if (!isTurnedIn &&
        startTime != null &&
        DateTime.now().isBefore(startTime)) {
      return Center(
        child: SingleChildScrollView(
          child: Container(
            width: isMobile ? double.infinity : 600,
            margin: EdgeInsets.all(isMobile ? 16 : 40),
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_clock,
                  size: isMobile ? 60 : 80,
                  color: Colors.blue,
                ),
                SizedBox(height: isMobile ? 24 : 32),
                Text(
                  'Test Has Not Started Yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This test starts at ${formatDateTime12h(startTime)}.\nPlease return when the timer begins.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isTurnedIn) {
      DateTime? dueTime = widget.assignment['dueDateTime'];
      bool isTimedOut = dueTime != null && DateTime.now().isAfter(dueTime);
      bool isFlagged = AppData().mcqFlagged[widget.assignment['id']] ?? false;

      String title = 'Test Over';
      String subtitle = 'Your responses have been recorded.';
      IconData icon = Icons.check_circle_rounded;
      Color mainColor = Colors.green;

      if (isFlagged) {
        title = 'Test Terminated';
        subtitle =
            'Security violation detected. Your session was ended and flagged.';
        icon = Icons.report_problem_rounded;
        mainColor = Colors.red;
      } else if (isTimedOut) {
        title = 'Time Ended';
        subtitle =
            'The test window has closed. Your progress so far was submitted.';
        icon = Icons.timer_off_rounded;
        mainColor = Colors.orange;
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [mainColor.withAlpha(10), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 24 : 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: mainColor.withAlpha(30),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: isMobile ? 60 : 100,
                    color: mainColor,
                  ),
                ),
                SizedBox(height: isMobile ? 32 : 48),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 32 : 42,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 500,
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 48 : 64),
                ElevatedButton.icon(
                  onPressed: () {
                    AppData().setPage(NavPage.dashboard);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.dashboard_rounded),
                  label: const Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 24 : 40,
                      vertical: isMobile ? 16 : 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: mainColor.withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isMcqStartPressed) {
      return Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 800,
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.classColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.quiz_rounded,
                          color: widget.classColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.assignment['title'],
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              '${mcqData.length} Questions  •  30s per question',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Examination Instructions',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoadingInstructions)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // Do's
                    ..._dos.map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Do: $point',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Dont's
                    ..._donts.map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.cancel_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Don'
                                't: $point',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!_isLoadingInstructions && _dos.isEmpty && _donts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        'Please follow standard examination rules.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade800,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  const Text(
                    'Standard Rules',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionItem(
                    Icons.highlight_off_rounded,
                    'Do not switch tabs or minimize the window.',
                    Colors.red,
                  ),
                  _buildInstructionItem(
                    Icons.timer_outlined,
                    'Each question has a 30-second time limit.',
                    Colors.orange,
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Note: Once you click "Start Test", the timer will begin instantly. The test cannot be paused or restarted.',
                            style: TextStyle(
                              color: Color(0xFF8B4513),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _shuffleQuestionsAndOptions();
                          _isMcqStartPressed = true;
                          _startMcqTimer();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.classColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: widget.classColor.withAlpha(100),
                      ),
                      child: const Text(
                        'Start Test Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (mcqData.isEmpty) {
      return const Center(child: Text('No questions available for this test.'));
    }

    final q = mcqData[currentMcqIndex];
    final progress = (currentMcqIndex + 1) / mcqData.length;

    return Container(
      color: const Color(0xFFF8F9FA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Question Area
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Navigation Header
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 40,
                    vertical: isMobile ? 16 : 24,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE9ECEF)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.assignment['title'],
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 18 : 20,
                              color: const Color(0xFF4A4A68),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Final Examination',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildTimerBadge(
                        Icons.timer_outlined,
                        '00:${_mcqTimeLeft.toString().padLeft(2, '0')}',
                        'Timer',
                        Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      if (!isMobile)
                        _buildTimerBadge(
                          Icons.schedule,
                          _getOverallTimeLeft(),
                          'Ends In',
                          widget.classColor,
                        ),
                    ],
                  ),
                ),

                // Question Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 40),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question ${currentMcqIndex + 1} of ${mcqData.length}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: widget.classColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              q['question'],
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 22 : 28,
                                height: 1.4,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 40),
                            ...List.generate((q['options'] as List).length, (
                              idx,
                            ) {
                              bool isSelected =
                                  mcqAnswers[currentMcqIndex] == idx;
                              return _buildOptionInteraction(
                                idx,
                                q['options'][idx].toString(),
                                isSelected,
                                isMobile,
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer Controls
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 40,
                    vertical: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE9ECEF))),
                  ),
                  child: Row(
                    children: [
                      if (currentMcqIndex > 0)
                        OutlinedButton(
                          onPressed: () => _jumpToQuestion(currentMcqIndex - 1),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Previous'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            mcqAnswers.remove(currentMcqIndex);
                            _visitedMcqIndices.add(currentMcqIndex);
                          });
                          _moveToNextQuestionOrSubmit();
                        },
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => _moveToNextQuestionOrSubmit(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.classColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          currentMcqIndex == mcqData.length - 1
                              ? 'Finish & Submit'
                              : 'Next Question',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Question Navigator (Hidden on Mobile)
          if (!isMobile)
            Container(
              width: 320,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Color(0xFFE9ECEF))),
              ),
              child: _buildQuestionNavigatorPanel(mcqData),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionNavigatorPanel(List<dynamic> mcqData) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.apps_rounded, color: Color(0xFF4A4A68)),
              const SizedBox(width: 12),
              Text(
                'Navigator',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: mcqData.length,
            itemBuilder: (context, index) {
              final isCurrent = currentMcqIndex == index;
              final isAnswered = mcqAnswers.containsKey(index);
              final isSkipped =
                  _visitedMcqIndices.contains(index) && !isAnswered;

              Color color = Colors.grey.shade100;
              Color textCol = Colors.grey.shade600;

              if (isCurrent) {
                color = const Color(0xFF007BFF);
                textCol = Colors.white;
              } else if (isAnswered) {
                color = const Color(0xFF28A745);
                textCol = Colors.white;
              } else if (isSkipped) {
                color = const Color(0xFFDC3545);
                textCol = Colors.white;
              }

              return InkWell(
                onTap: () => _jumpToQuestion(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: color.withAlpha(50),
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textCol,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _navigatorLegend(const Color(0xFF007BFF), 'Active Question'),
              const SizedBox(height: 10),
              _navigatorLegend(const Color(0xFF28A745), 'Answered'),
              const SizedBox(height: 10),
              _navigatorLegend(const Color(0xFFDC3545), 'Visited & Skipped'),
              const SizedBox(height: 10),
              _navigatorLegend(
                Colors.grey.shade100,
                'Not Visited',
                hasBorder: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navigatorLegend(Color col, String label, {bool hasBorder = false}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: col,
            borderRadius: BorderRadius.circular(4),
            border: hasBorder ? Border.all(color: Colors.grey.shade300) : null,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionInteraction(
    int idx,
    String text,
    bool isSelected,
    bool isMobile,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _visitedMcqIndices.add(currentMcqIndex);
              mcqAnswers[currentMcqIndex] = idx;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              color: isSelected
                  ? widget.classColor.withAlpha(15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? widget.classColor : Colors.grey.shade200,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: widget.classColor.withAlpha(30),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.classColor
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: widget.classColor.withAlpha(40),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + idx),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? widget.classColor
                          : const Color(0xFF4A4A68),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: widget.classColor, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBadge(
    IconData icon,
    String val,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                val,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherReviewPanel() {
    bool isMcq = widget.assignment['mcqData'] != null;

    // Calculate stats from currentAssignmentStatuses
    int turnedInCount = 0;
    int flaggedCount = 0;

    for (var status in AppData().currentAssignmentStatuses.values) {
      if (status['is_done'] == true) turnedInCount++;
      if (status['is_flagged'] == true) flaggedCount++;
    }

    final deptStudents = AppData().registeredStudents
        .where((s) => s['department'] == widget.classData['title'])
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 700;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMcq ? 'Live Results Dashboard' : 'Submissions Review',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isMcq)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAllResultsSummaryDialog(context),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download All Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMcq ? 'Live Results Dashboard' : 'Submissions Review',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3436),
                    ),
                  ),
                  if (isMcq)
                    ElevatedButton.icon(
                      onPressed: () => _showAllResultsSummaryDialog(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download All Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            if (isMobile)
              Column(
                children: [
                  _buildModernStatCard(
                    'Turned In',
                    turnedInCount.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildModernStatCard(
                    'Assigned',
                    deptStudents.length.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                  if (isMcq) ...[
                    const SizedBox(height: 12),
                    _buildModernStatCard(
                      'Flagged',
                      flaggedCount.toString(),
                      Icons.report_problem,
                      Colors.red,
                    ),
                  ],
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildModernStatCard(
                      'Turned In',
                      turnedInCount.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildModernStatCard(
                      'Assigned',
                      deptStudents.length.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  if (isMcq) ...[
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildModernStatCard(
                        'Flagged',
                        flaggedCount.toString(),
                        Icons.report_problem,
                        Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 32),
            Text(
              'Student Details',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (deptStudents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No students found in this department',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...deptStudents.map((student) {
                String name = student['name'] ?? 'Unknown Student';
                // Try all possible student ID fields and normalize to string
                String? eNo = student['enrollno']?.toString();
                String? eNoAlt = student['Enrollment No']?.toString();
                String stdId = (eNo != null && eNo.isNotEmpty)
                    ? eNo
                    : (eNoAlt ?? '');

                final status = AppData().currentAssignmentStatuses[stdId];
                bool hasSubmitted = status?['is_done'] ?? false;
                int? studentScore = status?['mcq_score'];
                bool isStudentFlagged = status?['is_flagged'] ?? false;

                return _buildStudentRosterItem(
                  name,
                  stdId,
                  hasSubmitted,
                  isMcq,
                  studentScore,
                  isFlagged: isStudentFlagged,
                );
              }),
            const SizedBox(height: 100), // Visual padding at bottom
          ],
        );
      },
    );
  }

  Widget _buildStudentRosterItem(
    String name,
    String stdId,
    bool hasSubmitted,
    bool isMcq,
    int? score, {
    bool isFlagged = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: hasSubmitted
              ? Colors.blue.shade50
              : Colors.red.shade50,
          child: Icon(
            Icons.person,
            color: hasSubmitted ? Colors.blue : Colors.red,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasSubmitted ? Icons.check_circle : Icons.error_outline,
                    size: 14,
                    color: hasSubmitted ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasSubmitted ? 'Turned in' : 'Not Attended',
                    style: TextStyle(
                      color: hasSubmitted
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (isFlagged)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, size: 12, color: Colors.red.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'FLAGGED: Security Violation',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isFlagged &&
                  DateTime.now().isBefore(
                    widget.assignment['dueDateTime'] ??
                        DateTime.now().add(const Duration(days: 1)),
                  ))
                TextButton.icon(
                  onPressed: () async {
                    await AppData().allowStudentReattempt(
                      widget.assignment['id'],
                      stdId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Student attempt restored. Student can now retry the quiz.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: Colors.blue,
                  ),
                  label: const Text(
                    'Allow Re-attempt',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: hasSubmitted && isMcq && score != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      final status = AppData().currentAssignmentStatuses[stdId];
                      if (status != null && status['answers'] != null) {
                        _showStudentAnswersDialog(
                          context,
                          name,
                          status['answers'],
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No answers found for this student.'),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.classColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.classColor.withAlpha(50),
                      ),
                    ),
                    child: Text(
                      '$score Marks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.classColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              )
            : (hasSubmitted && !isMcq)
            ? IconButton(
                icon: const Icon(Icons.folder_open, color: Colors.blue),
                onPressed: () async {
                  final status = AppData().currentAssignmentStatuses[stdId];
                  String fileName = status?['file_name'] ?? 'submission.pdf';
                  final assignmentId = widget.assignment['id'];

                  final storagePath = '$assignmentId/$stdId/$fileName';
                  final String publicUrl = supabase.storage
                      .from('student-submissions')
                      .getPublicUrl(storagePath);

                  final Uri uri = Uri.parse(publicUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open file URL')),
                    );
                  }
                },
              )
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Icon(
                  hasSubmitted ? Icons.attachment : Icons.close,
                  color: Colors.grey,
                ),
              ),
      ),
    );
  }

  Widget _buildModernStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(30)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(10),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStat(String num, String label, Color color) {
    return Column(
      children: [
        Text(
          num,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showStudentAnswersDialog(
    BuildContext context,
    String studentName,
    dynamic answersData,
  ) {
    List<dynamic> questionsToShow = [];
    final Map<int, int> studentAnsMap = {};

    if (answersData is Map) {
      if (answersData.containsKey('questions') &&
          answersData['questions'] is List) {
        // Use student-specific question set
        questionsToShow = answersData['questions'] as List<dynamic>;
        if (answersData['responses'] is Map) {
          final res = answersData['responses'] as Map;
          res.forEach((k, v) {
            studentAnsMap[int.tryParse(k.toString()) ?? 0] =
                int.tryParse(v.toString()) ?? 0;
          });
        }
      } else if (answersData.isNotEmpty) {
        // Legacy/Default fallback: ONLY show questions if they are in the answer map
        // If the teacher wants student-only questions, we shouldn't show the whole pool.
        final allQuestions = widget.assignment['mcqData'] as List<dynamic>;
        List<dynamic> filtered = [];
        answersData.forEach((k, v) {
          int idx = int.tryParse(k.toString()) ?? -1;
          if (idx >= 0 && idx < allQuestions.length) {
            filtered.add(allQuestions[idx]);
            studentAnsMap[filtered.length - 1] =
                int.tryParse(v.toString()) ?? 0;
          }
        });
        questionsToShow = filtered;
      }
    }

    // Final fallback: If still empty (e.g. no responses and no questions saved),
    // show ALL questions from the assignment but as "Not Attempted"
    if (questionsToShow.isEmpty) {
      questionsToShow = widget.assignment['mcqData'] as List<dynamic>;
      // In this case, studentAnsMap remains empty, which correctly identifies questions as unanswered
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Review: $studentName'),
        content: SizedBox(
          width: 600,
          height: 700,
          child: questionsToShow.isEmpty
              ? const Center(child: Text('No questions found for this test.'))
              : ListView.builder(
                  itemCount: questionsToShow.length,
                  itemBuilder: (context, i) {
                    final q = questionsToShow[i];
                    final correctIdx = q['answerIndex'] ?? 0;
                    final studentIdx = studentAnsMap[i];
                    final isCorrect = studentIdx == correctIdx;
                    final isUnanswered = studentIdx == null;

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q${i + 1}: ${q['question'] ?? "N/A"}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Correct: ${q['options']?[correctIdx] ?? "N/A"}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: studentIdx == null
                                    ? Colors.grey.shade100
                                    : (isCorrect
                                          ? Colors.green.shade50
                                          : Colors.red.shade50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    studentIdx == null
                                        ? Icons.help_outline
                                        : (isCorrect
                                              ? Icons.check_circle
                                              : Icons.cancel),
                                    color: studentIdx == null
                                        ? Colors.orange
                                        : (isCorrect
                                              ? Colors.green
                                              : Colors.red),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      studentIdx == null
                                          ? 'Not Attempted'
                                          : 'Student Selected: ${q['options']?[studentIdx] ?? "N/A"}',
                                      style: TextStyle(
                                        color: studentIdx == null
                                            ? Colors.orange.shade800
                                            : (isCorrect
                                                  ? Colors.green
                                                  : Colors.red),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAllResultsSummaryDialog(BuildContext context) {
    final allStudents = AppData().registeredStudents
        .where((s) => s['department'] == widget.classData['title'])
        .toList();
    final statuses = AppData().currentAssignmentStatuses;
    final originalMcqData =
        (widget.assignment['mcqData'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Students MCQ Summary'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 8,
                columnSpacing: 12,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Student',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Ans',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Score',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Flagged',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Details',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: allStudents.map((student) {
                  String name = student['name'] ?? 'Unknown';
                  String? eNo = student['enrollno']?.toString();
                  String? eNoAlt = student['Enrollment No']?.toString();
                  String stdId = (eNo != null && eNo.isNotEmpty)
                      ? eNo
                      : (eNoAlt ?? '');

                  final status = statuses[stdId];
                  bool hasSubmitted = status?['is_done'] ?? false;
                  int? score = status?['mcq_score'];
                  bool isFlagged = status?['is_flagged'] ?? false;

                  final dynamic rawAnswers = status?['answers'];
                  int answeredCount = 0;
                  int presentedCount =
                      (widget.assignment['questionsToShow'] as int?) ??
                      originalMcqData.length;
                  if (presentedCount > originalMcqData.length) {
                    presentedCount = originalMcqData.length;
                  }

                  if (rawAnswers is Map) {
                    if (rawAnswers.containsKey('responses')) {
                      // Modern format: has 'questions' and 'responses' keys
                      answeredCount = (rawAnswers['responses'] as Map).length;
                      presentedCount =
                          (rawAnswers['questions'] as List?)?.length ??
                          presentedCount;
                    } else {
                      // Legacy/Alternative format: Direct index-to-answer map
                      answeredCount = rawAnswers.length;
                    }
                  }

                  int skippedCount = hasSubmitted
                      ? (presentedCount - answeredCount)
                      : 0;
                  if (skippedCount < 0) skippedCount = 0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(name, style: const TextStyle(fontSize: 12)),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasSubmitted
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            hasSubmitted ? 'Submitted' : 'Pending',
                            style: TextStyle(
                              color: hasSubmitted
                                  ? Colors.green
                                  : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          hasSubmitted ? '$answeredCount' : '-',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          hasSubmitted ? '$skippedCount' : '-',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          score != null ? '$score / $presentedCount' : '-',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          isFlagged ? 'YES' : 'NO',
                          style: TextStyle(
                            color: isFlagged ? Colors.red : Colors.black,
                            fontSize: 12,
                            fontWeight: isFlagged
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: Icon(
                            Icons.visibility_outlined,
                            size: 20,
                            color: hasSubmitted
                                ? const Color(0xFF6C5CE7)
                                : Colors.grey,
                          ),
                          onPressed: hasSubmitted
                              ? () => _showStudentAnswersDialog(
                                  context,
                                  name,
                                  rawAnswers,
                                )
                              : null,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              try {
                var excel = ex.Excel.createExcel();
                ex.Sheet sheet = excel['Sheet1'];
                sheet.appendRow([
                  ex.TextCellValue('Student Name'),
                  ex.TextCellValue('Enrollment No'),
                  ex.TextCellValue('Status'),
                  ex.TextCellValue('Answered'),
                  ex.TextCellValue('Skipped'),
                  ex.TextCellValue('Score'),
                  ex.TextCellValue('Flagged'),
                ]);

                for (var student in allStudents) {
                  String name = student['name'] ?? 'Unknown';
                  String? eNo = student['enrollno']?.toString();
                  String? eNoAlt = student['Enrollment No']?.toString();
                  String stdId = (eNo != null && eNo.isNotEmpty)
                      ? eNo
                      : (eNoAlt ?? '');
                  final status = statuses[stdId];
                  bool hasSubmitted = status?['is_done'] ?? false;
                  int? score = status?['mcq_score'];
                  bool isFlagged = status?['is_flagged'] ?? false;

                  final dynamic rawAnswers = status?['answers'];
                  int answeredCount = 0;
                  int presentedCount =
                      (widget.assignment['questionsToShow'] as int?) ??
                      originalMcqData.length;
                  if (presentedCount > originalMcqData.length) {
                    presentedCount = originalMcqData.length;
                  }

                  if (rawAnswers is Map) {
                    if (rawAnswers.containsKey('responses')) {
                      answeredCount = (rawAnswers['responses'] as Map).length;
                      presentedCount =
                          (rawAnswers['questions'] as List?)?.length ??
                          presentedCount;
                    } else {
                      answeredCount = rawAnswers.length;
                    }
                  }

                  int skippedCount = hasSubmitted
                      ? (presentedCount - answeredCount)
                      : 0;
                  if (skippedCount < 0) skippedCount = 0;

                  sheet.appendRow([
                    ex.TextCellValue(name),
                    ex.TextCellValue(stdId),
                    ex.TextCellValue(hasSubmitted ? "Submitted" : "Pending"),
                    ex.IntCellValue(answeredCount),
                    ex.IntCellValue(skippedCount),
                    ex.TextCellValue(
                      score != null ? "$score / $presentedCount" : "-",
                    ),
                    ex.TextCellValue(isFlagged ? "YES" : "NO"),
                  ]);
                }

                var fileBytes = excel.encode();
                if (fileBytes != null) {
                  String? outputFile = await FilePicker.platform.saveFile(
                    dialogTitle: 'Select Save Location',
                    fileName: 'MCQ_Results_${widget.assignment['title']}.xlsx',
                    type: FileType.custom,
                    allowedExtensions: ['xlsx'],
                    bytes: Uint8List.fromList(fileBytes),
                  );
                  if (outputFile != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Report saved to $outputFile'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Excel Save Error: $e');
              }
            },
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Download Excel Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
