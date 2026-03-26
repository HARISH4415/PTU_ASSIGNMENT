import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';

void main() {
  runApp(const EduPortalApp());
}

// ---------------------------------------------------------
// Global Mock Database
// ---------------------------------------------------------
enum UserRole { student, teacher }

enum NavPage { dashboard, courses, liveClass, assignments, mcq }

class AppData extends ChangeNotifier {
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;
  AppData._internal();

  UserRole currentUserRole = UserRole.student;
  String? activeMeetingCode;

  // Shared state
  List<Map<String, dynamic>> classes = [
    {
      'id': 'c1',
      'title': 'Physics: Motion & Velocity',
      'subtitle': 'Prof. Albert',
      'color': Colors.teal.shade500,
      'progress': 0.88,
      'time': '02:15:45',
    },
    {
      'id': 'c2',
      'title': 'Literature: Sonnets',
      'subtitle': 'Prof. Shakespeare',
      'color': Colors.indigo.shade400,
      'progress': 0.85,
      'time': '03:10:12',
    },
    {
      'id': 'c3',
      'title': 'Computer Architecture',
      'subtitle': 'Prof. Turing',
      'color': Colors.deepOrange.shade400,
      'progress': 0.60,
      'time': '04:20:00',
    },
  ];

  Map<String, List<Map<String, dynamic>>> classAssignments = {
    'c1': [
      {
        'id': 'a1',
        'title': 'Kinematics Worksheet',
        'dueDate': 'Oct 20',
        'isDone': true,
      },
      {
        'id': 'a2',
        'title': 'Dynamics Lab Report',
        'dueDate': 'Oct 28',
        'isDone': false,
      },
    ],
    'c2': [
      {
        'id': 'a3',
        'title': 'Analysis of Sonnet 18',
        'dueDate': 'Oct 22',
        'isDone': false,
      },
    ],
    'c3': [],
  };

  Map<String, List<PlatformFile>> assignmentSubmissions = {};
  Map<String, List<String>> assignmentComments = {};
  Map<String, int> mcqScores = {};
  Map<String, Map<int, int>> mcqStudentAnswers = {};
  Map<String, bool> mcqFlagged = {}; // Stores assignmentId -> whether flagged for cheating

  void submitMcqQuiz(
    String assignmentId,
    int score, {
    Map<int, int>? answers,
    bool isMissed = false,
    bool isFlagged = false,
  }) {
    mcqScores[assignmentId] = score;
    if (isFlagged) {
      mcqFlagged[assignmentId] = true;
    }
    if (answers != null) {
      mcqStudentAnswers[assignmentId] = answers;
    }
    for (var list in classAssignments.values) {
      for (var a in list) {
        if (a['id'] == assignmentId) {
          a['isDone'] = true;
          a['isMissed'] = isMissed;
          notifyListeners();
          return;
        }
      }
    }
  }

  void unTerminateMcq(String assignmentId) {
    mcqFlagged[assignmentId] = false;
    mcqScores.remove(assignmentId);
    mcqStudentAnswers.remove(assignmentId);
    for (var list in classAssignments.values) {
      for (var a in list) {
        if (a['id'] == assignmentId) {
          a['isDone'] = false;
          a['isMissed'] = false;
          notifyListeners();
          return;
        }
      }
    }
  }

  void loginAs(UserRole role) {
    currentUserRole = role;
    notifyListeners();
  }

  void setMeetingCode(String code) {
    activeMeetingCode = code;
    notifyListeners();
  }

  void addAssignment(
    String classId,
    String title,
    String dueDate, {
    String year = 'All',
    String semester = 'All',
    PlatformFile? file,
    List<dynamic>? mcqData,
    int timePerQuestion = 30,
    DateTime? startDateTime,
    DateTime? dueDateTime,
  }) {
    classAssignments[classId]?.insert(0, {
      'id': 'a_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'dueDate': dueDate,
      'dueDateTime': dueDateTime,
      'startDateTime': startDateTime,
      'year': year,
      'semester': semester,
      'instructorFileName': file?.name,
      'mcqData': mcqData,
      'timePerQuestion': timePerQuestion,
      'isDone': false,
    });
    notifyListeners();
  }

  void toggleTurnIn(String assignmentId) {
    // Quick mock for status
    for (var list in classAssignments.values) {
      for (var a in list) {
        if (a['id'] == assignmentId) {
          a['isDone'] = !a['isDone'];
          notifyListeners();
          return;
        }
      }
    }
  }

  void submitFiles(String assignmentId, List<PlatformFile> files) {
    assignmentSubmissions.putIfAbsent(assignmentId, () => []).addAll(files);
    notifyListeners();
  }

  void removeFile(String assignmentId, int index) {
    assignmentSubmissions[assignmentId]?.removeAt(index);
    notifyListeners();
  }

  void addComment(String assignmentId, String comment) {
    assignmentComments.putIfAbsent(assignmentId, () => []).add(comment);
    notifyListeners();
  }
}

// ---------------------------------------------------------
// Main App Shell
// ---------------------------------------------------------
class EduPortalApp extends StatelessWidget {
  const EduPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData(),
      builder: (context, _) {
        return MaterialApp(
          title: 'EduPortal',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C5CE7),
              primary: const Color(0xFF6C5CE7),
              surface: const Color(0xFFF8F9FE),
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.plusJakartaSansTextTheme(
              Theme.of(context).textTheme,
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F6FB),
          ),
          home: const RoleSelectionScreen(),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// Role Selection Screen
// ---------------------------------------------------------
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 80,
                color: Color(0xFF6C5CE7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome to EduPortal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select your portal to continue',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRoleCard(
                  context,
                  'Student',
                  Icons.school,
                  UserRole.student,
                ),
                const SizedBox(width: 32),
                _buildRoleCard(
                  context,
                  'Teacher',
                  Icons.assignment_ind,
                  UserRole.teacher,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    String title,
    IconData icon,
    UserRole role,
  ) {
    return InkWell(
      onTap: () {
        AppData().loginAs(role);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayoutScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF6C5CE7).withAlpha(15),
              child: Icon(icon, size: 40, color: const Color(0xFF6C5CE7)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Main Layout (Sidebar + Content)
// ---------------------------------------------------------
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  NavPage _currentPage = NavPage.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Persistent Sidebar
          Container(
            width: 260,
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'EduPortal',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildUserInfo(),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const Text(
                        'MENU',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNavItem(
                        Icons.grid_view_rounded,
                        'Dashboard',
                        NavPage.dashboard,
                      ),
                      _buildNavItem(
                        Icons.library_books_rounded,
                        'Courses',
                        NavPage.courses,
                      ),
                      _buildNavItem(
                        Icons.video_camera_front_rounded,
                        'Live Class WebRTC',
                        NavPage.liveClass,
                      ),
                      _buildNavItem(
                        Icons.assignment_rounded,
                        'Assignments',
                        NavPage.assignments,
                      ),
                      _buildNavItem(Icons.quiz_rounded, 'MCQs', NavPage.mcq),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.logout,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.redAccent.withAlpha(50)),
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vertical Divider
          Container(width: 1, color: Colors.grey.shade200),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Header
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const TextField(
                            decoration: InputDecoration(
                              hintText: 'Search for courses, assignments...',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withAlpha(15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Color(0xFF6C5CE7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Oct 2026',
                              style: TextStyle(
                                color: const Color(0xFF6C5CE7).withAlpha(200),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                // Dynamic View
                Expanded(child: ClipRRect(child: _buildBodyContent())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    UserRole role = AppData().currentUserRole;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: role == UserRole.teacher
                ? Colors.amber.shade100
                : Colors.blue.shade100,
            child: Icon(
              role == UserRole.teacher ? Icons.person_4 : Icons.face,
              color: role == UserRole.teacher
                  ? Colors.amber.shade800
                  : Colors.blue.shade800,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role == UserRole.teacher ? 'Prof. Alan Turing' : 'Steve Rogers',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                role == UserRole.teacher ? 'Teacher Portal' : 'Student Portal',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, NavPage page) {
    bool isSelected = _currentPage == page;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => setState(() => _currentPage = page),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected
            ? const Color(0xFF6C5CE7).withAlpha(20)
            : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.shade500,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentPage) {
      case NavPage.dashboard:
        return const DashboardView();
      case NavPage.courses:
        return const CoursesView();
      case NavPage.liveClass:
        return const LiveClassView();
      case NavPage.assignments:
        return const AssignmentsView();
      case NavPage.mcq:
        return const McqCentralView();
    }
  }
}

class McqCentralView extends StatefulWidget {
  const McqCentralView({super.key});

  @override
  State<McqCentralView> createState() => _McqCentralViewState();
}

class _McqCentralViewState extends State<McqCentralView> {
  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    // Flatten assignments that have mcqData
    List<Map<String, dynamic>> allMcqTests = [];
    for (var cls in AppData().classes) {
      var assigns = AppData().classAssignments[cls['id']] ?? [];
      for (var a in assigns) {
        if (a['mcqData'] != null) {
          allMcqTests.add({'classData': cls, 'assignment': a});
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isTeacher ? 'MCQ Tests To Review' : 'Your MCQ Tests To-Do',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isTeacher)
                  ElevatedButton.icon(
                    onPressed: () => _openCreateMcqTestDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Upload New MCQ JSON Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: allMcqTests.isEmpty
                  ? const Center(
                      child: Text(
                        'No MCQ Tests available.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: allMcqTests.length,
                      itemBuilder: (ctx, i) {
                        var item = allMcqTests[i];
                        var cls = item['classData'];
                        var a = item['assignment'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AssignmentInteractionScreen(
                                    assignment: a,
                                    classColor: cls['color'],
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: cls['color'].withAlpha(20),
                                    child: Icon(
                                      Icons.quiz,
                                      color: cls['color'],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a['title'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${cls['title']}  •  Due: ${a['dueDate']}  •  ${a['mcqData'].length} Questions',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isTeacher)
                                    const Text(
                                      '0/25 Submitted',
                                      style: TextStyle(
                                        color: Color(0xFF6C5CE7),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    a['isDone']
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          )
                                        : const Icon(
                                            Icons.pending_actions,
                                            color: Colors.orange,
                                          ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateMcqTestDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController timeCtrl = TextEditingController(text: '30');
    DateTime startDateTime = DateTime.now();
    DateTime endDateTime = DateTime.now().add(const Duration(minutes: 30));
    String? selectedClassId = AppData().classes.first['id'];
    List<dynamic>? mcqData;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            int qCount = mcqData?.length ?? 0;
            int timePerQ = int.tryParse(timeCtrl.text) ?? 30;
            int totalSeconds = qCount * timePerQ;
            String totalTimeStr =
                '${totalSeconds ~/ 60}m ${totalSeconds % 60}s';

            return AlertDialog(
              title: const Text('Upload MCQ JSON Test'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedClassId,
                        items: AppData().classes
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['id'],
                                child: Text(c['title']),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedClassId = val),
                        decoration: const InputDecoration(
                          labelText: 'Select Course',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'MCQ Test Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: Text(
                          'Start: ${startDateTime.toString().substring(0, 16)}',
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          DateTime? date = await showDatePicker(
                            context: ctx,
                            initialDate: startDateTime,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            TimeOfDay? time = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(
                                startDateTime,
                              ),
                            );
                            if (time != null) {
                              setDialogState(() {
                                startDateTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: Text(
                          'End: ${endDateTime.toString().substring(0, 16)}',
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          DateTime? date = await showDatePicker(
                            context: ctx,
                            initialDate: endDateTime,
                            firstDate: startDateTime,
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            TimeOfDay? time = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(endDateTime),
                            );
                            if (time != null) {
                              setDialogState(() {
                                endDateTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: timeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Time per question (seconds)',
                          border: const OutlineInputBorder(),
                          helperText: 'Total Test Time: $totalTimeStr',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          var res = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json'],
                            withData: true,
                          );
                          if (res != null && res.files.first.bytes != null) {
                            try {
                              final data = jsonDecode(
                                utf8.decode(res.files.first.bytes!),
                              );
                              if (data is List) {
                                setDialogState(() => mcqData = data);
                              }
                            } catch (e) {
                              debugPrint('Error parsing MCQ JSON: $e');
                            }
                          }
                        },
                        icon: const Icon(Icons.file_upload),
                        label: Text(
                          mcqData != null
                              ? 'MCQ Test Attached (${mcqData!.length} Qs)'
                              : 'Upload JSON File',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Note: JSON file should be an array of questions with 4 options each and an answerIndex.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty &&
                        selectedClassId != null &&
                        mcqData != null) {
                      int qCount = mcqData?.length ?? 0;
                      int timePerQ = int.tryParse(timeCtrl.text) ?? 30;
                      int totalSeconds = qCount * timePerQ;
                      if (endDateTime.difference(startDateTime).inSeconds <
                          totalSeconds) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Warning: The time window between Start and End (${endDateTime.difference(startDateTime).inSeconds}s) is smaller than the required total test time (${totalSeconds}s). Please adjust.',
                            ),
                          ),
                        );
                        return;
                      }
                      AppData().addAssignment(
                        selectedClassId!,
                        titleCtrl.text,
                        endDateTime.toString().substring(0, 16),
                        mcqData: mcqData,
                        timePerQuestion: timePerQ,
                        startDateTime: startDateTime,
                        dueDateTime: endDateTime,
                      );
                      Navigator.pop(ctx);
                      setState(() {}); // refresh global list
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Test'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------
// Dashboard View (Image-inspired stunning layout)
// ---------------------------------------------------------
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Row
          Row(
            children: [
              _buildStatCard(
                isTeacher ? 'Active Courses' : 'Enrolled Courses',
                isTeacher ? '8' : '22',
                Icons.library_books,
                Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                isTeacher ? 'Assignments Created' : 'Pending Assignments',
                '32',
                Icons.assignment,
                Colors.orange,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                isTeacher ? 'Submissions to Review' : 'Completed Quizzes',
                '11',
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                'Upcoming Class',
                'Tomorrow',
                Icons.calendar_month,
                const Color(0xFF6C5CE7),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left large column (Chart + List)
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    // Analytics Chart Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Activity Analytics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Weekly',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 220,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildCustomBar('Mon', 0.4, false),
                                _buildCustomBar('Tue', 0.8, false),
                                _buildCustomBar('Wed', 0.5, false),
                                _buildCustomBar('Thu', 0.9, true),
                                _buildCustomBar('Fri', 0.6, false),
                                _buildCustomBar('Sat', 0.3, false),
                                _buildCustomBar('Sun', 0.7, false),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Recent Classes Table
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Courses',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ...AppData().classes.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: c['color'].withAlpha(20),
                                    child: Icon(
                                      Icons.menu_book,
                                      color: c['color'],
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      c['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      c['subtitle'],
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: c['progress'],
                                      backgroundColor: Colors.grey.shade100,
                                      color: c['color'],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '${(c['progress'] * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.more_horiz,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right side panels
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Online Classes Panel
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Live Classes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '• Active Now',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildLiveClassItem(
                            'PH',
                            'Physics',
                            'Motion',
                            Colors.teal,
                          ),
                          const Divider(height: 32),
                          _buildLiveClassItem(
                            'LT',
                            'Literature',
                            'Sonnets',
                            Colors.indigo,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: const Text(
                                'View Schedule',
                                style: TextStyle(color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Assignment Breakdown Chart mock
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assignment Breakdown',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            height: 16,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Container(
                                    color: Colors.green.shade400,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    color: const Color(0xFF6C5CE7),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Container(color: Colors.grey.shade300),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLegendDot(
                                Colors.green.shade400,
                                'Submitted',
                              ),
                              _buildLegendDot(
                                const Color(0xFF6C5CE7),
                                'Grading',
                              ),
                              _buildLegendDot(Colors.grey.shade300, 'Pending'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveClassItem(
    String avatar,
    String title,
    String sub,
    Color color,
  ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withAlpha(20),
          radius: 20,
          child: Text(
            avatar,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                sub,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
              SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBar(String label, double fillPercent, bool isHighlighted) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isHighlighted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '8 Hours',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 150 * fillPercent,
          width: 36,
          decoration: BoxDecoration(
            color: isHighlighted
                ? const Color(0xFF6C5CE7)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '+12%',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Courses View
// ---------------------------------------------------------
class CoursesView extends StatelessWidget {
  const CoursesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All Courses',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              itemCount: AppData().classes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 32,
                mainAxisSpacing: 32,
                childAspectRatio: 1.3,
              ),
              itemBuilder: (context, index) {
                final cls = AppData().classes[index];
                return GestureDetector(
                  onTap: () {
                    // We can navigate internally or push a route.
                    // Pushing a route over the Expanded area requires a nested navigator.
                    // For simplicity, we push a full screen route.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassDetailScreen(classData: cls),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            color: cls['color'],
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cls['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  cls['subtitle'],
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(200),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Course Progress',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${(cls['progress'] * 100).toInt()}%',
                                      style: TextStyle(
                                        color: cls['color'],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: cls['progress'],
                                  color: cls['color'],
                                  backgroundColor: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Live Class WebRTC Mock View
// ---------------------------------------------------------
class LiveClassView extends StatefulWidget {
  const LiveClassView({super.key});

  @override
  State<LiveClassView> createState() => _LiveClassViewState();
}

class _LiveClassViewState extends State<LiveClassView> {
  bool isMicMuted = false;
  bool isVideoOff = false;
  CameraController? _cameraController;
  bool isCameraInitialized = false;

  bool isInCall = false;
  bool isChatOpen = true;
  bool isCodeVerified = false;
  final TextEditingController joinCodeCtrl = TextEditingController();
  String? joinErrorMsg;

  String stringIdGenerator() {
    var r = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    return '${String.fromCharCodes(Iterable.generate(3, (_) => chars.codeUnitAt(r.nextInt(chars.length))))}-${String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(r.nextInt(chars.length))))}-${String.fromCharCodes(Iterable.generate(3, (_) => chars.codeUnitAt(r.nextInt(chars.length))))}';
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final cam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        _cameraController = CameraController(cam, ResolutionPreset.medium);
        await _cameraController!.initialize();
        if (mounted) setState(() => isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Widget _buildPreCall() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 600,
                    height: 350,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isCameraInitialized && !isVideoOff
                        ? AspectRatio(
                            aspectRatio: _cameraController!.value.aspectRatio,
                            child: CameraPreview(_cameraController!),
                          )
                        : const Center(
                            child: Text(
                              "Camera is starting...",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlBtn(
                        isMicMuted ? Icons.mic_off : Icons.mic,
                        isMicMuted ? Colors.red : Colors.grey.shade200,
                        () => setState(() => isMicMuted = !isMicMuted),
                        iconColor: isMicMuted ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 16),
                      _buildControlBtn(
                        isVideoOff ? Icons.videocam_off : Icons.videocam,
                        isVideoOff ? Colors.red : Colors.grey.shade200,
                        () => setState(() => isVideoOff = !isVideoOff),
                        iconColor: isVideoOff ? Colors.white : Colors.black87,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ready to join?',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No one else is here yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() => isInCall = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Join now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Present',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Other joining options',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.screen_share,
                      color: Color(0xFF6C5CE7),
                    ),
                    label: const Text(
                      'Use companion mode',
                      style: TextStyle(color: Color(0xFF6C5CE7)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentThumbnail(int i) {
    if (i == 0 && isCameraInitialized && !isVideoOff) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
          const Positioned(
            bottom: 12,
            left: 12,
            child: Text(
              ' You ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isMicMuted)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.mic_off, color: Colors.white, size: 16),
              ),
            ),
        ],
      );
    }

    String label = i == 0 ? "You" : (i == 1 ? "Prof. Alan" : "Student $i");
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor:
                Colors.primaries[i % Colors.primaries.length].shade400,
            child: Text(
              label.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.mic_off, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleMeetHome() {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(60),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Premium video meetings.\nNow free for everyone.',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'We re-engineered the service we built for secure business meetings, Google Meet, to make it free and available for all.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (isTeacher) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        String newCode = stringIdGenerator();
                        AppData().setMeetingCode(newCode);
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Here's your meeting link"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Copy this link and send it to people you want to meet with. Be sure to save it so you can use it later, too.",
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      newCode,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.copy,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: newCode),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Meeting code copied!',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  setState(() => isCodeVerified = true);
                                },
                                child: const Text(
                                  'Join Now',
                                  style: TextStyle(
                                    color: Color(0xFF6C5CE7),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.video_call),
                      label: const Text('New meeting'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (AppData().activeMeetingCode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Active Session Code: ${AppData().activeMeetingCode}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          width: 280,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.keyboard, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: joinCodeCtrl,
                                  onChanged: (val) =>
                                      setState(() => joinErrorMsg = null),
                                  decoration: const InputDecoration(
                                    hintText: 'Enter a code or link',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () {
                            if (joinCodeCtrl.text.trim() ==
                                AppData().activeMeetingCode) {
                              setState(() => isCodeVerified = true);
                            } else {
                              setState(
                                () => joinErrorMsg =
                                    'Invalid code. Wait for teacher to create a meeting.',
                              );
                            }
                          },
                          child: Text(
                            'Join',
                            style: TextStyle(
                              color: joinCodeCtrl.text.isEmpty
                                  ? Colors.grey
                                  : const Color(0xFF6C5CE7),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (joinErrorMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          joinErrorMsg!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 32),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Text(
                      'Learn more',
                      style: TextStyle(color: Color(0xFF6C5CE7)),
                    ),
                    label: const Text(
                      'about Google Meet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: CircleAvatar(
                  radius: 120,
                  backgroundColor: const Color(0xFF6C5CE7).withAlpha(20),
                  child: const Icon(
                    Icons.groups,
                    size: 100,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isCodeVerified) return _buildGoogleMeetHome();
    if (!isInCall) return _buildPreCall();

    return Container(
      color: const Color(0xFF202124), // Google Meet dark grey background
      child: Row(
        children: [
          // Video Area
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      itemCount: 6,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isChatOpen ? 2 : 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 16 / 9,
                      ),
                      itemBuilder: (ctx, i) {
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3C4043),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildStudentThumbnail(i),
                        );
                      },
                    ),
                  ),
                ),
                // Bottom Meet Controls Bar
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "10:24 AM • Class Sync",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          _buildControlBtn(
                            isMicMuted ? Icons.mic_off : Icons.mic_none,
                            isMicMuted ? Colors.red : const Color(0xFF3C4043),
                            () => setState(() => isMicMuted = !isMicMuted),
                            iconColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildControlBtn(
                            isVideoOff
                                ? Icons.videocam_off
                                : Icons.videocam_outlined,
                            isVideoOff ? Colors.red : const Color(0xFF3C4043),
                            () => setState(() => isVideoOff = !isVideoOff),
                            iconColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildControlBtn(
                            Icons.closed_caption_off_outlined,
                            const Color(0xFF3C4043),
                            () {},
                            iconColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildControlBtn(
                            Icons.back_hand_outlined,
                            const Color(0xFF3C4043),
                            () {},
                            iconColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildControlBtn(
                            Icons.present_to_all_outlined,
                            const Color(0xFF3C4043),
                            () {},
                            iconColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildControlBtn(
                            Icons.more_vert,
                            const Color(0xFF3C4043),
                            () {},
                            iconColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildControlBtn(
                            Icons.call_end,
                            Colors.red,
                            () {
                              setState(() => isInCall = false);
                            },
                            iconColor: Colors.white,
                            isLarge: true,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                            ),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.people_outline,
                              color: Colors.white,
                            ),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chat_bubble_outline,
                              color: isChatOpen
                                  ? const Color(0xFF8AB4F8)
                                  : Colors.white,
                            ),
                            onPressed: () =>
                                setState(() => isChatOpen = !isChatOpen),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right Chat Panel (Toggleable)
          if (isChatOpen)
            Container(
              width: 320,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                ),
              ),
              margin: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'In-call messages',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => setState(() => isChatOpen = false),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Messages can only be seen by people in the call and are deleted when the call ends.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildChatMsg(
                          'Student 2',
                          'Can you re-explain the velocity formula?',
                          '10:02 AM',
                        ),
                        _buildChatMsg(
                          'Prof. Alan',
                          'Yes, let me pull up the slide again.',
                          '10:03 AM',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Send a message to everyone',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: const Icon(
                          Icons.send,
                          color: Color(0xFF6C5CE7),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlBtn(
    IconData icon,
    Color bgColor,
    VoidCallback onTap, {
    bool isLarge = false,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isLarge ? 56 : 48,
        width: isLarge ? 80 : 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(icon, color: iconColor, size: isLarge ? 28 : 22),
      ),
    );
  }

  Widget _buildChatMsg(String name, String msg, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            msg,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Assignments Central View
// ---------------------------------------------------------
class AssignmentsView extends StatefulWidget {
  const AssignmentsView({super.key});

  @override
  State<AssignmentsView> createState() => _AssignmentsViewState();
}

class _AssignmentsViewState extends State<AssignmentsView> {
  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    // Flatten assignments
    List<Map<String, dynamic>> allAssignments = [];
    for (var cls in AppData().classes) {
      var assigns = AppData().classAssignments[cls['id']] ?? [];
      for (var a in assigns) {
        if (a['mcqData'] == null) {
          allAssignments.add({'classData': cls, 'assignment': a});
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isTeacher
                      ? 'Assignments To Review'
                      : 'Your Assignments To-Do',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isTeacher)
                  ElevatedButton.icon(
                    onPressed: () => _openCreateAssignmentDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Global Assignment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.builder(
                itemCount: allAssignments.length,
                itemBuilder: (ctx, i) {
                  var item = allAssignments[i];
                  var cls = item['classData'];
                  var a = item['assignment'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AssignmentInteractionScreen(
                              assignment: a,
                              classColor: cls['color'],
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: cls['color'].withAlpha(20),
                              child: Icon(
                                Icons.assignment,
                                color: cls['color'],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['title'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${cls['title']}  •  Due: ${a['dueDate']}  •  ${a['year']} ${a['semester']}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (a['instructorFileName'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.attach_file,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            a['instructorFileName'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isTeacher)
                              const Text(
                                '0/25 Submitted',
                                style: TextStyle(
                                  color: Color(0xFF6C5CE7),
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              a['isDone']
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : const Icon(
                                      Icons.pending_actions,
                                      color: Colors.orange,
                                    ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateAssignmentDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController dateCtrl = TextEditingController(text: 'Nov 01');
    String? selectedClassId = AppData().classes.first['id'];
    String selectedYear = '1st Year';
    String selectedSem = 'Sem 1';
    PlatformFile? pickedFile;
    List<dynamic>? mcqData;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Assignment'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedYear,
                              items:
                                  [
                                        '1st Year',
                                        '2nd Year',
                                        '3rd Year',
                                        '4th Year',
                                      ]
                                      .map(
                                        (y) => DropdownMenuItem(
                                          value: y,
                                          child: Text(y),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) =>
                                  setDialogState(() => selectedYear = val!),
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSem,
                              items:
                                  [
                                        'Sem 1',
                                        'Sem 2',
                                        'Sem 3',
                                        'Sem 4',
                                        'Sem 5',
                                        'Sem 6',
                                        'Sem 7',
                                        'Sem 8',
                                      ]
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) =>
                                  setDialogState(() => selectedSem = val!),
                              decoration: const InputDecoration(
                                labelText: 'Semester',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedClassId,
                        items: AppData().classes
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['id'],
                                child: Text(c['title']),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedClassId = val),
                        decoration: const InputDecoration(
                          labelText: 'Select Course',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Assignment Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: dateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          var res = await FilePicker.platform.pickFiles();
                          if (res != null) {
                            setDialogState(() => pickedFile = res.files.first);
                          }
                        },
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          pickedFile != null
                              ? pickedFile!.name
                              : 'Attach Assignment File',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty && selectedClassId != null) {
                      AppData().addAssignment(
                        selectedClassId!,
                        titleCtrl.text,
                        dateCtrl.text,
                        year: selectedYear,
                        semester: selectedSem,
                        file: pickedFile,
                        mcqData: mcqData,
                      );
                      Navigator.pop(ctx);
                      setState(() {}); // refresh global list
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Upload Assignment'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------
// Class Details Screen (Stream, Assignments layout)
// ---------------------------------------------------------
class ClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  const ClassDetailScreen({super.key, required this.classData});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    String classId = widget.classData['id'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classData['title']),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            // Massive Header Banner
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.classData['color'],
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.classData['color'].withAlpha(100),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.classData['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.classData['subtitle'],
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Classwork',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isTeacher)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _openCreateAssignmentDialog(context, classId),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Assignment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: AppData(),
                        builder: (ctx, _) {
                          List assigns =
                              (AppData().classAssignments[classId] ?? [])
                                  .where((a) => a['mcqData'] == null)
                                  .toList();
                          if (assigns.isEmpty)
                            return const Text('No assignments yet.');

                          return Column(
                            children: assigns.map((a) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AssignmentInteractionScreen(
                                              assignment: a,
                                              classColor:
                                                  widget.classData['color'],
                                            ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: widget
                                              .classData['color']
                                              .withAlpha(20),
                                          child: Icon(
                                            Icons.assignment,
                                            color: widget.classData['color'],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                a['title'],
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Due: ${a['dueDate']}  •  ${a['year']} ${a['semester']}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              if (a['instructorFileName'] !=
                                                  null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.attach_file,
                                                        size: 14,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        a['instructorFileName'],
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isTeacher)
                                          Text(
                                            ((a['isDone'] ?? false) &&
                                                    !(a['isMissed'] ?? false))
                                                ? '1/25 Submitted'
                                                : '0/25 Submitted',
                                            style: TextStyle(
                                              color: const Color(0xFF6C5CE7),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        else if ((a['isDone'] ?? false) &&
                                            !(a['isMissed'] ?? false))
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          )
                                        else if ((a['dueDateTime'] != null &&
                                                DateTime.now().isAfter(
                                                  a['dueDateTime'],
                                                )) ||
                                            (a['isMissed'] ?? false))
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.error_outline,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Test Is Over',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          const Icon(
                                            Icons.pending_actions,
                                            color: Colors.orange,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upcoming',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Woohoo, no work due soon!'),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'View all',
                            style: TextStyle(color: Color(0xFF6C5CE7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateAssignmentDialog(BuildContext context, String classId) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController dateCtrl = TextEditingController(text: 'Oct 30');
    String selectedYear = '1st Year';
    String selectedSem = 'Sem 1';
    PlatformFile? pickedFile;
    List<dynamic>? mcqData;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Create Assignment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedYear,
                            items:
                                ['1st Year', '2nd Year', '3rd Year', '4th Year']
                                    .map(
                                      (y) => DropdownMenuItem(
                                        value: y,
                                        child: Text(y),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) =>
                                setDialogState(() => selectedYear = val!),
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSem,
                            items:
                                [
                                      'Sem 1',
                                      'Sem 2',
                                      'Sem 3',
                                      'Sem 4',
                                      'Sem 5',
                                      'Sem 6',
                                      'Sem 7',
                                      'Sem 8',
                                    ]
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) =>
                                setDialogState(() => selectedSem = val!),
                            decoration: const InputDecoration(
                              labelText: 'Semester',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: dateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        var res = await FilePicker.platform.pickFiles();
                        if (res != null) {
                          setDialogState(() => pickedFile = res.files.first);
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        pickedFile != null ? pickedFile!.name : 'Attach File',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty) {
                      AppData().addAssignment(
                        classId,
                        titleCtrl.text,
                        dateCtrl.text,
                        year: selectedYear,
                        semester: selectedSem,
                        file: pickedFile,
                        mcqData: mcqData,
                      );
                      Navigator.pop(ctx);
                      setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------
// Assignment Interaction Screen (Upload/Review)
// ---------------------------------------------------------
class AssignmentInteractionScreen extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final Color classColor;

  const AssignmentInteractionScreen({
    super.key,
    required this.assignment,
    required this.classColor,
  });

  @override
  State<AssignmentInteractionScreen> createState() =>
      _AssignmentInteractionScreenState();
}

class _AssignmentInteractionScreenState
    extends State<AssignmentInteractionScreen> with WidgetsBindingObserver {
  final TextEditingController _commentCtrl = TextEditingController();
  int currentMcqIndex = 0;
  final Map<int, int> mcqAnswers = {};
  Timer? _mcqTimer;
  int _mcqTimeLeft = 30;
  int _tabSwitchCount = 0;
  int _backPressCount = 0;
  bool _isWarningDialogShown = false;
  bool _hasTabSwitchPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    bool isStudent = AppData().currentUserRole == UserRole.student;
    bool isTurnedIn = widget.assignment['isDone'] ?? false;

    DateTime? startTime = widget.assignment['startDateTime'];
    DateTime? dueTime = widget.assignment['dueDateTime'];

    if (isStudent &&
        !isTurnedIn &&
        dueTime != null &&
        DateTime.now().isAfter(dueTime)) {
      isTurnedIn = true;
      // submit automatically as missed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppData().submitMcqQuiz(
          widget.assignment['id'],
          0,
          answers: mcqAnswers,
          isMissed: true,
        );
      });
    }

    if (isStudent && !isTurnedIn && widget.assignment['mcqData'] != null) {
      if (startTime == null || !DateTime.now().isBefore(startTime)) {
        _startMcqTimer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mcqTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bool isStudent = AppData().currentUserRole == UserRole.student;
    bool isTurnedIn = widget.assignment['isDone'] ?? false;
    bool isMcq = widget.assignment['mcqData'] != null;

    if (isStudent && !isTurnedIn && isMcq) {
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

    if (isStudent && !isTurnedIn && isMcq) {
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
      // For non-MCQ or already finished, just pop normally
      Navigator.pop(context);
    }
  }

  void _showSecurityWarning(String message) {
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
            child: const Text('I Understand', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startMcqTimer() {
    _mcqTimer?.cancel();
    _mcqTimeLeft = widget.assignment['timePerQuestion'] ?? 30;
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
    List<dynamic> mcqData = widget.assignment['mcqData'] as List<dynamic>;
    if (currentMcqIndex < mcqData.length - 1) {
      currentMcqIndex++;
      _startMcqTimer();
    } else {
      _mcqTimer?.cancel();
      _submitMcq();
    }
  }

  void _submitMcq({bool isFlagged = false}) {
    _mcqTimer?.cancel();
    List<dynamic> mcqData = widget.assignment['mcqData'] as List<dynamic>;
    int score = 0;
    for (int j = 0; j < mcqData.length; j++) {
      var q = mcqData[j];
      var ans =
          q['answerIndex'] ??
          q['answer'] ??
          q['correctAnswer'] ??
          q['correctIndex'];
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
    AppData().submitMcqQuiz(
      widget.assignment['id'],
      score,
      answers: mcqAnswers,
      isFlagged: isFlagged,
    );
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result != null) {
      AppData().submitFiles(widget.assignment['id'], result.files);
    }
  }

  void _addComment() {
    if (_commentCtrl.text.isNotEmpty) {
      AppData().addComment(widget.assignment['id'], _commentCtrl.text);
      _commentCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    bool isStudent = AppData().currentUserRole == UserRole.student;
    bool isTurnedIn = widget.assignment['isDone'] ?? false;
    bool isMcq = widget.assignment['mcqData'] != null;

    return PopScope(
      canPop: !(isStudent && !isTurnedIn && isMcq),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Assignment Details')),
        body: AnimatedBuilder(
        animation: AppData(),
        builder: (context, _) {
          List<PlatformFile> attachedFiles =
              AppData().assignmentSubmissions[widget.assignment['id']] ?? [];
          List<String> comments =
              AppData().assignmentComments[widget.assignment['id']] ?? [];
          bool isTurnedIn = widget.assignment['isDone'] ?? false;

          DateTime? dueTime = widget.assignment['dueDateTime'];
          if (AppData().currentUserRole == UserRole.student &&
              !isTurnedIn &&
              dueTime != null &&
              DateTime.now().isAfter(dueTime)) {
            isTurnedIn = true;
          }

          Widget heroBanner = Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
              border: Border.all(color: widget.classColor.withAlpha(50)),
            ),
            child: Row(
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
                    widget.assignment['mcqData'] != null ? Icons.quiz_outlined : Icons.assignment_outlined,
                    color: widget.classColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Container(
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
                            Text(
                              'Due by ${widget.assignment['dueDate']}',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (isTeacher) {
            return Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heroBanner,
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _buildTeacherReviewPanel(),
                    ),
                  ),
                ],
              ),
            );
          }

          if (widget.assignment['mcqData'] != null) {
            return _buildStudentMcqPanel(
              widget.assignment['mcqData'] as List<dynamic>,
              isTurnedIn,
            );
          }

          return Padding(
            padding: const EdgeInsets.all(40.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heroBanner,
                      if (widget.assignment['mcqData'] == null) ...[
                        const SizedBox(height: 48),
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
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            'Please review the attached material and submit your workings below in Excel format.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade800,
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.people_outline,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Class Comments',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ...comments.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                      ),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(5),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      c,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: widget.classColor,
                              child: const Icon(
                                Icons.face,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _commentCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Add a class comment...',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: widget.classColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        onPressed: _addComment,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addComment(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 64),
                Expanded(
                  flex: 2,
                  child: _buildStudentUploadPanel(attachedFiles, isTurnedIn),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildStudentUploadPanel(
    List<PlatformFile> attachedFiles,
    bool isTurnedIn,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
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
                  isTurnedIn ? 'Turned in' : 'Assigned',
                  style: TextStyle(
                    color: isTurnedIn
                        ? Colors.green.shade700
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
                trailing: isTurnedIn
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () =>
                            AppData().removeFile(widget.assignment['id'], i),
                      ),
              ),
            );
          }),

          if (!isTurnedIn) ...[
            InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(16),
              child: DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  color: widget.classColor,
                  strokeWidth: 2,
                  dashPattern: const [8, 4],
                  radius: const Radius.circular(16),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
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
          ElevatedButton(
            onPressed: () => AppData().toggleTurnIn(widget.assignment['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: isTurnedIn ? Colors.white : widget.classColor,
              foregroundColor: isTurnedIn ? Colors.black87 : Colors.white,
              elevation: isTurnedIn ? 0 : 4,
              shadowColor: widget.classColor.withAlpha(100),
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
                  ? 'Unsubmit Work'
                  : (attachedFiles.isEmpty ? 'Mark as done' : 'Turn In Final'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentMcqPanel(List<dynamic> mcqData, bool isTurnedIn) {
    DateTime? startTime = widget.assignment['startDateTime'];
    if (!isTurnedIn &&
        startTime != null &&
        DateTime.now().isBefore(startTime)) {
      return Center(
        child: SizedBox(
          width: 600,
          child: Container(
            padding: const EdgeInsets.all(40),
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
                const Icon(Icons.lock_clock, size: 80, color: Colors.blue),
                const SizedBox(height: 32),
                const Text(
                  'Test Has Not Started Yet',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This test starts at ${startTime.toString().substring(0, 16)}.\nPlease return when the timer begins.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
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

      return Center(
        child: SizedBox(
          width: 600,
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isFlagged || isTimedOut)
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isFlagged || isTimedOut)
                    ? Colors.red.shade200
                    : Colors.green.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isFlagged || isTimedOut ? Colors.red : Colors.green)
                      .withAlpha(20),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isFlagged || isTimedOut ? Colors.red : Colors.green)
                            .withAlpha(30),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(
                    isFlagged
                        ? Icons.report_problem
                        : (isTimedOut ? Icons.timer_off : Icons.check_circle),
                    size: 80,
                    color: (isFlagged || isTimedOut) ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isFlagged
                      ? 'Test Terminated!'
                      : (isTimedOut ? 'Test is Over!' : 'Quiz Completed or Finished!'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isFlagged
                      ? 'This test was automatically terminated due to a security violation (tab switching or navigation).\nThis attempt has been flagged and submitted to your instructor.'
                      : (isTimedOut
                          ? 'The deadline for this test has passed.\nYour progress was automatically saved and shared with your instructor.'
                          : 'Your final answers were securely submitted to your instructor.\nYour score will be strictly visible to your teacher only.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
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

    var q = mcqData[currentMcqIndex];
    double progress = (currentMcqIndex + 1) / mcqData.length;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Navigation Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 250,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.assignment['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Color(0xFF4A4A68),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Session 1',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  color: widget.classColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: widget.classColor.withAlpha(
                                  20,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  widget.classColor,
                                ),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.classColor.withAlpha(120),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'review',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Mark as review',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        color: widget.classColor.withAlpha(180),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '00:${_mcqTimeLeft.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A4A68),
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Time Left',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 800,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${currentMcqIndex + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q['question'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          height: 1.5,
                          color: Color(0xFF4A4A68),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate((q['options'] as List).length, (
                        optIndex,
                      ) {
                        bool isSelected =
                            mcqAnswers[currentMcqIndex] == optIndex;
                        String displayOptionText = q['options'][optIndex]
                            .toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              setState(
                                () => mcqAnswers[currentMcqIndex] = optIndex,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected
                                        ? widget.classColor
                                        : Colors.grey.shade200,
                                    width: isSelected ? 4 : 1,
                                  ),
                                  top: BorderSide(
                                    color: Colors.grey.shade100,
                                    width: 1,
                                  ),
                                  right: BorderSide(
                                    color: Colors.grey.shade100,
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                    width: 1,
                                  ),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: widget.classColor.withAlpha(
                                            15,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayOptionText,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF4A4A68)
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? widget.classColor
                                            : Colors.black87,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: widget.classColor,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(32),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (currentMcqIndex == mcqData.length - 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Auto-submitting in $_mcqTimeLeft s...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherReviewPanel() {
    bool isTurnedIn =
        (widget.assignment['isDone'] ?? false) &&
        !(widget.assignment['isMissed'] ?? false);
    bool isMcq = widget.assignment['mcqData'] != null;
    int? score = AppData().mcqScores[widget.assignment['id']];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isMcq ? 'Live Results Dashboard' : 'Submissions Review',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                'Turned in',
                isTurnedIn ? '1' : '0',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildModernStatCard(
                'Assigned',
                '25',
                Icons.people,
                Colors.blue,
              ),
            ),
            if (isMcq) ...[
              const SizedBox(width: 20),
              Expanded(
                child: _buildModernStatCard(
                  'Flagged',
                  AppData().mcqFlagged[widget.assignment['id']] == true ? '1' : '0',
                  Icons.report_problem,
                  Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Student Roster',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildStudentRosterItem('Student 1', isTurnedIn, isMcq, score),
        _buildStudentRosterItem('Student 2', false, isMcq, null),
        _buildStudentRosterItem('Student 3', false, isMcq, null),
        _buildStudentRosterItem('Student 4', false, isMcq, null),
        _buildStudentRosterItem('Student 5', false, isMcq, null),
        const SizedBox(height: 100), // Visual padding at bottom
      ],
    );
  }

  Widget _buildStudentRosterItem(
    String name,
    bool hasSubmitted,
    bool isMcq,
    int? score,
  ) {
    bool isFlagged = name == 'Student 1' && (AppData().mcqFlagged[widget.assignment['id']] ?? false);
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
          child: Row(
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
                ),
              ),
              if (isFlagged) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                if (DateTime.now().isBefore(widget.assignment['dueDateTime'] ?? DateTime.now().add(const Duration(days: 1))))
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: TextButton.icon(
                      onPressed: () {
                        AppData().unTerminateMcq(widget.assignment['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Student attempt restored. Student can now retry the quiz.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.blue),
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
                  ),
              ],
            ],
          ),
        ),
        trailing: hasSubmitted && isMcq && score != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.black54),
                    onPressed: () {
                      final answers =
                          AppData().mcqStudentAnswers[widget.assignment['id']];
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'Student Answers & Download Report',
                          ),
                          content: SizedBox(
                            width: 400,
                            height: 300,
                            child: ListView.builder(
                              itemCount: widget.assignment['mcqData'].length,
                              itemBuilder: (c, i) {
                                var q = widget.assignment['mcqData'][i];
                                var ansIndex = answers?[i];
                                String ansText = ansIndex != null
                                    ? q['options'][ansIndex].toString()
                                    : 'No Answer Selected';
                                return ListTile(
                                  title: Text('Q${i + 1}: ${q['question']}'),
                                  subtitle: Text('Selected: $ansText'),
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.table_chart),
                              label: const Text('Export as Excel'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${name.replaceAll(" ", "_")}_Results.xlsx downloaded successfully!',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
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

  Widget _buildModernStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(30)),
        boxShadow: [
          BoxShadow(color: color.withAlpha(10), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text(label, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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
}
