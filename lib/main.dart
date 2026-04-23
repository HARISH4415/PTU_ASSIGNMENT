import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ptu/admin_views.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as ex;
import 'package:csv/csv.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'auth.dart';
import 'paper_views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Replace these with your actual Supabase Project URL and Anon Key
  try {
    await Supabase.initialize(
      url: 'https://wagtgvrfiscusihqgsds.supabase.co',
      anonKey: 'sb_publishable_5w97jQG482KDYVVGlbALAg_HsZxEgHq',
    );
  } catch (e) {
    debugPrint('Supabase init failed. Please update the URL and Anon Key.');
  }

  runApp(const EduPortalApp());
}

final supabase = Supabase.instance.client;

String _formatDateTime12h(DateTime? dt) {
  if (dt == null) return '--';
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  return '${dt.year}-$month-$day  $hour:$minute $period';
}

// ---------------------------------------------------------
// Global Mock Database
// ---------------------------------------------------------
enum UserRole { student, teacher, admin }

enum NavPage {
  dashboard,
  courses,
  liveClass,
  assignments,
  mcq,
  profile,
  adminDashboard,
  manageCourses,
  manageTeachers,
  manageStudents,
  studentDetails,
}

class AppData extends ChangeNotifier {
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;
  AppData._internal() {
    loadSession();
  }

  List<String> teacherCustomCourses = [];
  Map<String, Map<String, dynamic>> currentAssignmentStatuses =
      {}; // student_id -> status_row

  Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    await prefs.setString('currentUserRole', currentUserRole.name);
    await prefs.setString('loggedEmail', loggedEmail ?? '');
    await prefs.setString('loggedPhone', loggedPhone ?? '');
    await prefs.setString('loggedEnrollNo', loggedEnrollNo ?? '');
    await prefs.setString('loggedTeacherId', loggedTeacherId ?? '');
    await prefs.setString('loggedName', loggedName ?? '');
    await prefs.setString('loggedDepartment', loggedDepartment ?? '');
    await prefs.setString('loggedDesignation', loggedDesignation ?? '');
    await prefs.setString('loggedYear', loggedYear ?? '');
    await prefs.setString('loggedSemester', loggedSemester ?? '');
    await prefs.setString('loggedSection', loggedSection ?? '');
    await prefs.setBool('isRegistrationPending', isRegistrationPending);
    await prefs.setStringList('teacherCustomCourses', teacherCustomCourses);
    await prefs.setString('currentPage', currentPage.name);
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    bool? savedLoggedIn = prefs.getBool('isLoggedIn');
    if (savedLoggedIn == true) {
      isLoggedIn = true;
      String? roleName = prefs.getString('currentUserRole');
      if (roleName != null) {
        currentUserRole = UserRole.values.firstWhere(
          (e) => e.name == roleName,
          orElse: () => UserRole.student,
        );
      }
      loggedEmail = prefs.getString('loggedEmail');
      loggedPhone = prefs.getString('loggedPhone');
      loggedEnrollNo = prefs.getString('loggedEnrollNo');
      loggedTeacherId = prefs.getString('loggedTeacherId');
      loggedName = prefs.getString('loggedName');
      loggedDepartment = prefs.getString('loggedDepartment');
      loggedDesignation = prefs.getString('loggedDesignation');
      loggedYear = prefs.getString('loggedYear');
      loggedSemester = prefs.getString('loggedSemester');
      loggedSection = prefs.getString('loggedSection');
      isRegistrationPending = prefs.getBool('isRegistrationPending') ?? false;
      teacherCustomCourses = prefs.getStringList('teacherCustomCourses') ?? [];

      String? savedPage = prefs.getString('currentPage');
      if (savedPage != null) {
        currentPage = NavPage.values.firstWhere(
          (e) => e.name == savedPage,
          orElse: () => currentUserRole == UserRole.admin
              ? NavPage.adminDashboard
              : NavPage.dashboard,
        );
      } else {
        // Fallback for first time or missing data
        currentPage = currentUserRole == UserRole.admin
            ? NavPage.adminDashboard
            : NavPage.dashboard;
      }

      notifyListeners();
      loadAssignmentsFromSupabase();
      fetchPredefinedCourses();
      if (currentUserRole == UserRole.teacher) {
        _fetchTeacherMappingFromSupabase();
      }
    }
  }

  Future<void> _fetchTeacherMappingFromSupabase() async {
    if (loggedTeacherId == null) return;
    try {
      final res = await supabase
          .from('teacher_enrollments')
          .select('assigned_courses')
          .eq('teacher_id', loggedTeacherId!)
          .maybeSingle();
      if (res != null && res['assigned_courses'] != null) {
        teacherCustomCourses = List<String>.from(res['assigned_courses']);
        saveSession();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching teacher mapping: $e');
    }
  }

  UserRole currentUserRole = UserRole.student;
  NavPage currentPage = NavPage.dashboard;
  String? activeMeetingCode;
  bool isAssignmentsLoading = false;

  bool isLoggedIn = false;
  String? loggedEmail;
  String? loggedPhone;
  String? loggedDob;
  String? loggedEnrollNo;
  String? loggedTeacherId;
  String? loggedName;
  String? loggedDepartment;
  String? loggedDesignation;
  String? loggedYear;
  String? loggedSemester;
  String? loggedSection;
  String? loginErrorMessage;
  bool isRegistrationPending = false;
  Map<String, dynamic>? currentUserData;
  List<Map<String, dynamic>> registeredStudents = [];
  List<Map<String, dynamic>> internalStudents = [];
  List<String> activeDepartments = [];
  Map<String, Map<String, String>> departmentTeacherMap = {};
  List<Map<String, dynamic>> enrolledStudents = [];

  Future<void> fetchStudentsByDepartment(String dept) async {
    try {
      final data = await supabase
          .from('student_registered_details')
          .select()
          .eq('department', dept);
      enrolledStudents = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching students by dept: $e');
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  List<Map<String, dynamic>> predefinedCourses = [];

  Future<void> fetchPredefinedCourses() async {
    try {
      final data = await supabase
          .from('courses_master')
          .select('id, name')
          .order('name');
      if (data != null) {
        predefinedCourses = List<Map<String, dynamic>>.from(data as List);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching courses_master: $e');
    }
  }

  Future<void> addCourseMaster(String name) async {
    await supabase.from('courses_master').insert({'name': name});
    await fetchActiveDepartments(); // Refresh predefinedCourses
    await fetchPredefinedCourses(); // Refresh predefinedCourses list too
  }

  // Helper to find numeric course ID by name
  int? getCourseIdByName(String name) {
    if (name.isEmpty) return null;
    final search = name.trim().toLowerCase();
    for (var c in predefinedCourses) {
      if (c['name'].toString().trim().toLowerCase() == search) {
        return c['id'] as int?;
      }
    }
    return null;
  }

  Future<void> deleteCourseMaster(int id) async {
    try {
      await supabase.from('courses_master').delete().eq('id', id);
      await fetchPredefinedCourses();
    } catch (e) {
      debugPrint('Error deleting course: $e');
    }
  }

  void addTeacherCourse(String courseName) {
    if (!teacherCustomCourses.contains(courseName)) {
      teacherCustomCourses.add(courseName);
      saveSession();
      syncTeacherCoursesToSupabase();
      notifyListeners();
    }
  }

  void removeTeacherCourse(String courseName) {
    if (teacherCustomCourses.contains(courseName)) {
      teacherCustomCourses.remove(courseName);
      saveSession();
      syncTeacherCoursesToSupabase();
      notifyListeners();
    }
  }

  Future<void> syncTeacherCoursesToSupabase() async {
    if (currentUserRole != UserRole.teacher || loggedTeacherId == null) return;
    try {
      await supabase.from('teacher_subject_mapping').upsert({
        'teacher_id': loggedTeacherId,
        'name': loggedName,
        'department': loggedDepartment,
        'designation': loggedDesignation,
        'subjects': teacherCustomCourses,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error syncing teacher subjects: $e');
    }
  }

  void setPage(NavPage page) {
    currentPage = page;
    saveSession();
    notifyListeners();
  }

  // Shared state (now dynamic based on department)
  List<Map<String, dynamic>> classes = [];

  List<Map<String, dynamic>> get filteredClasses {
    if (!isLoggedIn) return [];

    if (currentUserRole == UserRole.teacher) {
      return teacherCustomCourses
          .toSet()
          .map((d) => _buildClassNode(d))
          .toList();
    } else {
      // Students ONLY see their own department's course
      if (loggedDepartment != null && loggedDepartment!.isNotEmpty) {
        return [_buildClassNode(loggedDepartment!)];
      }
      return [];
    }
  }

  Map<String, dynamic> _buildClassNode(String dept) {
    // Map departments to their brand colors for a premium look
    Color courseColor = const Color(0xFF6C5CE7); // Default brand color
    if (dept.toLowerCase().contains('computer') ||
        dept.toLowerCase().contains('it')) {
      courseColor = Colors.deepOrange.shade400;
    } else if (dept.toLowerCase().contains('bank') ||
        dept.toLowerCase().contains('finance')) {
      courseColor = Colors.teal.shade500;
    } else if (dept.toLowerCase().contains('literature')) {
      courseColor = Colors.indigo.shade400;
    } else if (dept.toLowerCase().contains('electronic')) {
      courseColor = Colors.blue.shade600;
    } else if (dept.toLowerCase().contains('mechanical')) {
      courseColor = Colors.red.shade600;
    } else if (dept.toLowerCase().contains('civil')) {
      courseColor = Colors.brown.shade500;
    } else if (dept.toLowerCase().contains('marketing')) {
      courseColor = Colors.pink.shade400;
    } else if (dept.toLowerCase().contains('business') ||
        dept.toLowerCase().contains('management')) {
      courseColor = const Color(0xFF6C5CE7); // Brand Primary
    } else if (dept.toLowerCase().contains('hospital')) {
      courseColor = Colors.cyan.shade600;
    } else if (dept.toLowerCase().contains('tourism')) {
      courseColor = Colors.amber.shade700;
    } else if (dept.toLowerCase().contains('supply chain') ||
        dept.toLowerCase().contains('operations')) {
      courseColor = Colors.deepPurple.shade400;
    }

    String tName = 'N/A';
    String tDesig = 'Faculty';

    if (currentUserRole == UserRole.teacher) {
      tName = loggedName ?? 'N/A';
      tDesig = loggedDesignation ?? 'Professor';
    } else {
      // Lookup from map for students
      final info = departmentTeacherMap[dept];
      if (info != null) {
        tName = info['name'] ?? 'N/A';
        tDesig = info['designation'] ?? 'Faculty';
      }
    }

    return {
      'id': _normalizeClassId(dept),
      'title': dept,
      'subtitle': currentUserRole == UserRole.teacher
          ? 'Prof. $tName'
          : 'Faculty: $tName',
      'teacherName': tName,
      'teacherDesignation': tDesig,
      'color': courseColor,
      'progress': 0.50,
      'time': '00:00:00',
    };
  }

  String _normalizeClassId(String id) {
    if (id.startsWith('dept_')) return id;
    return 'dept_${id.trim().replaceAll(' ', '_').toLowerCase()}';
  }

  List<Map<String, dynamic>> filteredAssignments(String classId) {
    // Ensure we handle both raw and prefixed IDs for robustness
    final normalizedId = _normalizeClassId(classId);

    final list = classAssignments[normalizedId] ?? classAssignments[classId] ?? [];

    // Filter by Year/Sem for BOTH students and teachers
    return list.where((a) {
      final targetYear = a['year']?.toString().trim().toLowerCase() ?? 'all';
      final targetSem = a['semester']?.toString().trim().toLowerCase() ?? 'all';

      final userYear = loggedYear?.trim().toLowerCase() ?? '';
      final userSem = loggedSemester?.trim().toLowerCase() ?? '';

      // "All" is a wildcard that matches everyone
      bool yearMatch = targetYear == 'all' || targetYear == userYear;
      bool semMatch = targetSem == 'all' || targetSem == userSem;

      return yearMatch && semMatch;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> classAssignments = {};

  Map<String, List<PlatformFile>> assignmentSubmissions = {};
  Map<String, List<String>> assignmentComments = {};
  Map<String, int> mcqScores = {};
  Map<String, Map<int, int>> mcqStudentAnswers = {};
  Map<String, List<dynamic>> mcqStudentPresentedQuestions = {};
  Map<String, int> assignmentSubmissionCounts = {};
  Map<String, int> assignmentUnsubmitCounts = {};
  Map<String, bool> mcqFlagged = {};
  void submitMcqQuiz(
    String assignmentId,
    int score, {
    Map<int, int>? answers,
    bool isMissed = false,
    bool isFlagged = false,
    List<dynamic>? presentedQuestions,
  }) {
    mcqScores[assignmentId] = score;
    if (isFlagged) {
      mcqFlagged[assignmentId] = true;
    }
    if (answers != null) {
      mcqStudentAnswers[assignmentId] = answers;
    }
    if (presentedQuestions != null) {
      mcqStudentPresentedQuestions[assignmentId] = presentedQuestions;
    }
    for (var list in classAssignments.values) {
      for (var a in list) {
        if (a['id'] == assignmentId) {
          a['isDone'] = true;
          a['isMissed'] = isMissed;
          notifyListeners();
          // Persist to Supabase
          _upsertAssignmentStatus(
            assignmentId: assignmentId,
            isDone: true,
            isFlagged: isFlagged,
            score: score,
            answers: answers,
            presentedQuestions: presentedQuestions,
            isMcq: true,
          );
          return;
        }
      }
    }
  }

  Future<void> _upsertAssignmentStatus({
    required String assignmentId,
    bool isDone = false,
    bool isFlagged = false,
    int? score,
    Map<int, int>? answers,
    List<dynamic>? presentedQuestions,
    bool isMcq = false,
  }) async {
    try {
      final studentId =
          loggedEnrollNo ?? loggedPhone ?? loggedEmail ?? 'unknown';
      if (isMcq) {
        // Store both responses and the actual questions shown (to handle shuffling/subsets)
        final studentAnswersData = {
          'responses': answers?.map((k, v) => MapEntry(k.toString(), v)),
          'questions': presentedQuestions,
        };

        await supabase.from('student_mcq_results').upsert({
          'mcq_id': assignmentId,
          'student_id': studentId,
          'score': score ?? 0,
          'is_completed': isDone,
          'is_flagged': isFlagged,
          'student_answers': studentAnswersData,
        }, onConflict: 'student_id, mcq_id');
      } else {
        String? fName;
        final files = assignmentSubmissions[assignmentId];
        if (files != null && files.isNotEmpty) {
          final file = files.first;
          fName = file.name;

          // UPLOAD TO STORAGE
          try {
            final fileBytes = file.bytes;
            if (fileBytes != null) {
              final storagePath = '$assignmentId/$studentId/${file.name}';
              await supabase.storage
                  .from('student-submissions')
                  .uploadBinary(
                    storagePath,
                    fileBytes,
                    fileOptions: const FileOptions(upsert: true),
                  );
              debugPrint('Student file uploaded: $storagePath');
            }
          } catch (e) {
            debugPrint('Student storage upload error: $e');
          }
        }
        await supabase.from('student_assignment_responses').upsert({
          'assignment_id': assignmentId,
          'student_id': studentId,
          'is_turned_in': isDone,
          'submission_file_name': fName,
        }, onConflict: 'student_id, assignment_id');
      }
    } catch (e) {
      debugPrint('Supabase upsert status error: $e');
    }
  }

  Future<void> fetchRegisteredStudents() async {
    try {
      final data = await supabase.from('student_registered_details').select();
      registeredStudents = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching students: $e');
    }
  }

  Future<void> fetchInternalStudents() async {
    try {
      final data = await supabase
          .from('student_int')
          .select()
          .order('Enrollment No', ascending: true);
      internalStudents = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching internal students: $e');
    }
  }

  Future<void> fetchActiveDepartments() async {
    try {
      final data = await supabase
          .from('teacher_register_details')
          .select('department, name, designation');
      final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(data as List);
      final List<String> depts = rows
          .map((e) => e['department']?.toString() ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
      
      departmentTeacherMap.clear();
      for (var row in rows) {
        String d = row['department']?.toString() ?? '';
        if (d.isNotEmpty) {
          departmentTeacherMap[d] = {
            'name': row['name']?.toString() ?? 'N/A',
            'designation': row['designation']?.toString() ?? 'Faculty',
          };
        }
      }

      activeDepartments = depts;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching active departments: $e');
    }
  }

  Future<void> fetchAssignmentStatusesForTeacher(
    String assignmentId, {
    bool isMcq = false,
  }) async {
    try {
      // Ensure students list is loaded first if empty
      if (registeredStudents.isEmpty) {
        final studentData = await supabase
            .from('student_registered_details')
            .select();
        registeredStudents = List<Map<String, dynamic>>.from(studentData);
      }

      final tableName = isMcq
          ? 'student_mcq_results'
          : 'student_assignment_responses';
      final idField = isMcq ? 'mcq_id' : 'assignment_id';

      final data = await supabase
          .from(tableName)
          .select()
          .eq(idField, assignmentId);

      final Map<String, Map<String, dynamic>> statuses = {};
      for (var row in data) {
        // Universal mapping to keep UI happy
        statuses[row['student_id'].toString()] = {
          'is_done': isMcq ? row['is_completed'] : row['is_turned_in'],
          'mcq_score': isMcq ? row['score'] : null,
          'is_flagged': isMcq ? (row['is_flagged'] ?? false) : false,
          'file_name': isMcq ? null : row['submission_file_name'],
          'answers': isMcq ? row['student_answers'] : null,
        };
      }
      currentAssignmentStatuses = statuses;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching assignment statuses: $e');
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

  Future<void> allowStudentReattempt(
    String assignmentId,
    String studentId,
  ) async {
    try {
      await supabase.from('student_mcq_results').delete().match({
        'mcq_id': assignmentId,
        'student_id': studentId,
      });

      // Refresh data for teacher
      fetchAssignmentStatusesForTeacher(assignmentId, isMcq: true);
    } catch (e) {
      debugPrint('Error enabling re-attempt: $e');
    }
  }

  void loginAs(UserRole role) {
    currentUserRole = role;
    notifyListeners();
  }

  Future<bool> loginTeacher(String teacherId, String passwordInput) async {
    // Step 1: Check if registered in teacher_register_details
    try {
      var registeredCheck;
      try {
        registeredCheck = await supabase
            .from('teacher_register_details')
            .select()
            .eq('teacher_id', teacherId)
            .maybeSingle();
      } catch (e) {
        debugPrint('Step 1 loginTeacher details check failed: $e');
        // If teacher_id column is missing, maybe it's Teacher ID?
        // But since the user is getting errors for 'Teacher ID', we should stick to teacher_id or other common variants
        try {
          registeredCheck = await supabase
              .from('teacher_register_details')
              .select()
              .eq('teacherid', teacherId)
              .maybeSingle();
        } catch (_) {}
      }

      if (registeredCheck != null) {
        if (registeredCheck['password'] == passwordInput) {
          isLoggedIn = true;
          isRegistrationPending = false;
          currentUserRole = UserRole.teacher;
          loggedTeacherId = teacherId;
          loggedName = registeredCheck['name']?.toString();

          loggedPhone = registeredCheck['phone']?.toString();
          loggedDepartment = registeredCheck['department']?.toString();
          loggedDesignation = registeredCheck['designation']?.toString();
          loggedYear = registeredCheck['year']?.toString();
          loggedSemester = registeredCheck['semester']?.toString();
          saveSession();
          notifyListeners();
          loadAssignmentsFromSupabase();
          debugPrint('Teacher Login Success: $teacherId');
          return true;
        } else {
          debugPrint('Teacher Login: Password mismatch for $teacherId');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Step 1 loginTeacher outer error: $e');
    }

    // Step 2: Check if existing in teacher_enrollments (initial registration)
    try {
      var preCheck = await supabase
          .from('teacher_enrollments')
          .select()
          .eq('teacher_id', teacherId)
          .maybeSingle();

      if (preCheck == null) {
        preCheck = await supabase
            .from('teacher_enrollments')
            .select()
            .eq('Teacher ID', int.tryParse(teacherId) ?? -1)
            .maybeSingle();
      }

      if (preCheck != null && passwordInput == 'ptu@123') {
        isRegistrationPending = true;
        currentUserRole = UserRole.teacher;
        loggedTeacherId = teacherId;
        loggedName = (preCheck['teacher_name'] ?? preCheck['name'])?.toString();
        saveSession();
        notifyListeners();
        debugPrint(
          'Teacher Initial Login Success (teacher_enrollments): $teacherId',
        );
        return true;
      }
    } catch (e) {
      debugPrint('Step 2 loginTeacher (teacher_enrollments) failed: $e');
      // Fallback to legacy teacher_int
      try {
        final preCheck = await supabase
            .from('teacher_int')
            .select()
            .eq('teacher_id', teacherId)
            .maybeSingle();
        if (preCheck != null && passwordInput == 'ptu@123') {
          isRegistrationPending = true;
          currentUserRole = UserRole.teacher;
          loggedTeacherId = teacherId;
          loggedName = preCheck['name']?.toString();
          saveSession();
          notifyListeners();
          debugPrint(
            'Teacher Initial Login Success (teacher_int fallback): $teacherId',
          );
          return true;
        }
      } catch (err) {
        debugPrint('Step 2 loginTeacher (teacher_int) failed: $err');
      }
    }

    return false;
  }

  Future<bool> loginStudent(String enrollNo, String passwordInput) async {
    // Step 1: Check registered status
    try {
      var registeredCheck;
      try {
        registeredCheck = await supabase
            .from('student_registered_details')
            .select()
            .eq('enrollno', enrollNo)
            .maybeSingle();

        if (registeredCheck == null) {
          registeredCheck = await supabase
              .from('student_registered_details')
              .select()
              .eq('Enrollment No', int.tryParse(enrollNo) ?? -1)
              .maybeSingle();
        }
      } catch (e) {
        debugPrint('Step 1 student registered check failed: $e');
        try {
          registeredCheck = await supabase
              .from('student_registered_details')
              .select()
              .eq('Enrollment No', int.tryParse(enrollNo) ?? -1)
              .maybeSingle();
        } catch (_) {}
      }

      if (registeredCheck != null) {
        if (registeredCheck['is_blocked'] == true) {
          debugPrint('Login blocked for student: $enrollNo');
          loginErrorMessage =
              'Your ID is blocked. Contact admin to unblock it.';
          return false;
        }
        loginErrorMessage = null; // Clear if not blocked and found
        if (registeredCheck['password'] == passwordInput) {
          isLoggedIn = true;
          isRegistrationPending = false;
          currentUserRole = UserRole.student;
          loggedEnrollNo = enrollNo;
          loggedName = registeredCheck['name']?.toString();
          loggedPhone = registeredCheck['phone']?.toString();
          loggedDepartment = registeredCheck['department']?.toString();
          loggedYear = registeredCheck['year']?.toString();
          loggedSemester = registeredCheck['semester']?.toString();
          saveSession();
          notifyListeners();
          loadAssignmentsFromSupabase();
          return true;
        } else {
          debugPrint('Registered student password mismatch');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Step 1 student outer error: $e');
    }

    // Step 2: If not registered, it's their FIRST TIME. Check student_int.
    try {
      var preCheck = await supabase
          .from('student_int')
          .select()
          .eq('Enrollment No', int.tryParse(enrollNo) ?? -1)
          .maybeSingle();

      if (preCheck == null) {
        preCheck = await supabase
            .from('student_int')
            .select()
            .eq('enrollno', enrollNo)
            .maybeSingle();
      }

      if (preCheck != null && passwordInput == 'ptu@123') {
        isRegistrationPending = true;
        currentUserRole = UserRole.student;
        loggedEnrollNo = enrollNo;
        loggedName = preCheck['name']?.toString();
        loggedPhone = preCheck['phone']?.toString();
        loggedDob = preCheck['dob']?.toString();
        loggedDepartment = preCheck['department']?.toString();
        loggedYear = preCheck['year']?.toString();
        loggedSemester = preCheck['semester']?.toString();
        saveSession();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Step 2 student check failed: $e');
      try {
        final preCheck = await supabase
            .from('student_int')
            .select()
            .eq('enrollno', enrollNo)
            .maybeSingle();
        if (preCheck != null && passwordInput == 'ptu@123') {
          isRegistrationPending = true;
          currentUserRole = UserRole.student;
          loggedEnrollNo = enrollNo;
          loggedName = preCheck['name']?.toString();
          loggedPhone = preCheck['phone']?.toString();
          loggedDob = preCheck['dob']?.toString();
          loggedDepartment = preCheck['department']?.toString();
          loggedYear = preCheck['year']?.toString();
          loggedSemester = preCheck['semester']?.toString();
          saveSession();
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  Future<bool> loginAdmin(String adminId, String passwordInput) async {
    try {
      final res = await supabase
          .from('admin_enrollments')
          .select()
          .eq('admin_id', adminId)
          .maybeSingle();

      if (res != null) {
        if (res['password'] == passwordInput) {
          isLoggedIn = true;
          isRegistrationPending = false;
          currentUserRole = UserRole.admin;
          currentPage = NavPage.adminDashboard;
          loggedTeacherId = adminId;
          loggedName = res['admin_name']?.toString() ?? 'Admin';
          saveSession();
          notifyListeners();
          debugPrint('Admin Login Success: $adminId');
          return true;
        } else {
          debugPrint('Admin Login: Password mismatch for $adminId');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error in loginAdmin: $e');
    }
    return false;
  }

  Future<String?> registerTeacherDetails({
    required String teacherId,
    required String name,
    required String phone,
    required String department,
    required String designation,
    required String year,
    required String semester,
    required String password,
  }) async {
    try {
      await supabase.from('teacher_register_details').insert({
        'teacher_id': teacherId,
        'name': name,
        'phone': phone,
        'department': department,
        'designation': designation,
        'year': year,
        'semester': semester,
        'password': password,
        'is_registered': true,
      });

      isRegistrationPending = false;
      isLoggedIn = true;
      loggedTeacherId = teacherId;
      loggedName = name;
      loggedPhone = phone;
      loggedDepartment = department;
      loggedDesignation = designation;
      loggedYear = year;
      loggedSemester = semester;
      saveSession();
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      debugPrint('Teacher registration error (Supabase): ${e.message}');
      return 'Database error: ${e.message}';
    } catch (e) {
      debugPrint('Teacher registration error: $e');
      return 'Unexpected error: ${e.toString()}';
    }
  }

  Future<String?> updateProfile({
    String? name,
    String? phone,
    String? year,
    String? semester,
    String? section,
    String? designation,
  }) async {
    try {
      final role = currentUserRole;
      final table = role == UserRole.teacher
          ? 'teacher_register_details'
          : 'student_registered_details';

      String idField;
      dynamic idValue;

      if (role == UserRole.teacher) {
        idField = 'teacher_id';
        idValue = loggedTeacherId;
      } else {
        idField = 'Enrollment No';
        idValue = int.tryParse(loggedEnrollNo ?? '') ?? -1;
      }

      if (idField == 'Enrollment No' && idValue == -1) {
        idField = 'enrollno';
        idValue = loggedEnrollNo;
      }

      if (idValue == null) return 'Not logged in';

      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (year != null) updates['year'] = year;
      if (semester != null) updates['semester'] = semester;
      if (section != null) updates['section'] = section;
      if (designation != null) updates['designation'] = designation;

      if (phone != null) {
        if (role == UserRole.teacher) {
          updates['phone'] = num.tryParse(phone) ?? 0;
        } else {
          updates['phone'] = phone;
        }
      }

      if (updates.isEmpty) return null;

      final response = await supabase
          .from(table)
          .update(updates)
          .eq(idField, idValue)
          .select();

      if ((response as List).isEmpty) {
        return 'No record found matching $idField=$idValue. Update failed.';
      }

      // Update local state
      if (name != null) loggedName = name;
      if (phone != null) loggedPhone = phone;
      if (year != null) loggedYear = year;
      if (semester != null) loggedSemester = semester;
      if (section != null) loggedSection = section;
      if (designation != null) loggedDesignation = designation;

      saveSession();
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      debugPrint('Update profile DB error: ${e.message}');
      return 'Database error: ${e.message}';
    } catch (e) {
      debugPrint('Update profile error: $e');
      return 'Unexpected error: ${e.toString()}';
    }
  }

  Future<String?> registerStudentDetails({
    required String enrollNo,
    required String name,
    required String phone,
    required String dob,
    required String department,
    required String year,
    required String semester,
    required String password,
  }) async {
    try {
      String sqlDob = dob;
      try {
        if (dob.contains('/')) {
          final parts = dob.split('/');
          if (parts.length == 3) {
            sqlDob =
                '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        } else if (dob.contains('-') && dob.split('-')[0].length <= 2) {
          final parts = dob.split('-');
          if (parts.length == 3) {
            sqlDob =
                '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        }
      } catch (_) {}

      await supabase.from('student_registered_details').insert({
        'Enrollment No': int.tryParse(enrollNo) ?? -1,
        'enrollno': enrollNo,
        'name': name,
        'phone': phone,
        'dob': sqlDob,
        'department': department,
        'year': year,
        'semester': semester,
        'password': password,
        'is_registered': true,
      });

      isLoggedIn = true;
      isRegistrationPending = false;
      currentUserRole = UserRole.student;
      loggedEnrollNo = enrollNo;
      loggedName = name;
      loggedPhone = phone;
      loggedDepartment = department;
      loggedYear = year;
      loggedSemester = semester;

      saveSession();
      notifyListeners();
      loadAssignmentsFromSupabase();
      return null;
    } on PostgrestException catch (e) {
      debugPrint('Supabase student registration error: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('Supabase student registration error: $e');
      return e.toString();
    }
  }

  void logout() {
    isLoggedIn = false;
    isRegistrationPending = false;
    loggedEmail = null;
    loggedPhone = null;
    loggedEnrollNo = null;
    loggedTeacherId = null;
    loggedName = null;
    loggedDepartment = null;
    loggedDesignation = null;
    loggedYear = null;
    loggedSemester = null;
    loggedSection = null;
    clearSession();
    notifyListeners();
  }

  Future<void> enrollTeacher(String teacherId, String teacherName) async {
    try {
      await supabase.from('teacher_enrollments').insert({
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'assigned_courses': [],
      });
    } catch (e) {
      debugPrint('Error enrolling teacher: $e');
      rethrow;
    }
  }

  Future<bool> updateTeacherPrograms(
    String teacherId,
    List<String> courses,
  ) async {
    try {
      await supabase
          .from('teacher_enrollments')
          .update({'assigned_courses': courses})
          .eq('teacher_id', teacherId);
      return true;
    } catch (e) {
      debugPrint('Error updating teacher programs: $e');
      return false;
    }
  }

  bool isCourseAssignedToOther(
    String courseName,
    String currentTeacherId,
    List<Map<String, dynamic>> allEnrollments,
  ) {
    for (var env in allEnrollments) {
      if (env['teacher_id'] == currentTeacherId) continue;
      List<dynamic> courses = env['assigned_courses'] ?? [];
      if (courses.contains(courseName)) return true;
    }
    return false;
  }

  Future<void> addInternalStudent({
    required String enrollNo,
    required String name,
    required String phone,
    required String dob,
    required String department,
    required String year,
    required String semester,
  }) async {
    try {
      await supabase.from('student_int').insert({
        'Enrollment No': int.tryParse(enrollNo) ?? -1,
        'name': name,
        'phone': phone,
        'dob': dob,
        'department': department,
        'year': year,
        'semester': semester,
      });
    } catch (e) {
      debugPrint('Error adding internal student: $e');
      rethrow;
    }
  }

  Future<String?> fetchUserName(String userId) async {
    try {
      final idInt = int.tryParse(userId) ?? -1;

      // Run all queries in parallel for maximum speed
      final results = await Future.wait([
        supabase
            .from('student_int')
            .select('name')
            .eq('Enrollment No', idInt)
            .maybeSingle(),
        supabase
            .from('student_registered_details')
            .select('name')
            .eq('enrollno', userId)
            .maybeSingle(),
        supabase
            .from('teacher_enrollments')
            .select('teacher_name')
            .eq('teacher_id', userId)
            .maybeSingle(),
        supabase
            .from('teacher_register_details')
            .select('name')
            .eq('teacher_id', userId)
            .maybeSingle(),
      ]);

      // Return the first non-null result find
      if (results[0] != null) return results[0]!['name']?.toString();
      if (results[1] != null) return results[1]!['name']?.toString();
      if (results[2] != null) return results[2]!['teacher_name']?.toString();
      if (results[3] != null) return results[3]!['name']?.toString();

      return null;
    } catch (e) {
      debugPrint('Error fetching user name: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyUserIdentity(
    String id,
    String name,
    String dob,
  ) async {
    try {
      // Check students
      final studentRes = await supabase
          .from('student_registered_details')
          .select()
          .eq('enrollno', id)
          .eq('name', name)
          .eq('dob', dob)
          .maybeSingle();
      if (studentRes != null)
        return {'table': 'student_registered_details', 'id_col': 'enrollno'};

      // Check teachers
      final teacherRes = await supabase
          .from('teacher_register_details')
          .select()
          .eq('teacher_id', id)
          .eq('name', name)
          .eq('dob', dob)
          .maybeSingle();
      if (teacherRes != null)
        return {'table': 'teacher_register_details', 'id_col': 'teacher_id'};

      return null;
    } catch (e) {
      debugPrint('Error verifying identity: $e');
      return null;
    }
  }

  Future<bool> updateUserPassword(
    String id,
    String table,
    String idCol,
    String newPass,
  ) async {
    try {
      await supabase.from(table).update({'password': newPass}).eq(idCol, id);
      return true;
    } catch (e) {
      debugPrint('Error updating password: $e');
      return false;
    }
  }

  Future<Map<String, List<String>>> fetchMcqInstruction() async {
    try {
      final res = await supabase
          .from('mcq_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (res != null) {
        List<String> dos =
            (res['dos'] as List?)?.map((e) => e.toString()).toList() ?? [];
        List<String> donts =
            (res['donts'] as List?)?.map((e) => e.toString()).toList() ?? [];
        return {'dos': dos, 'donts': donts};
      }
    } catch (e) {
      debugPrint('Error fetching mcq instruction: $e');
    }
    return {'dos': [], 'donts': []};
  }

  Future<bool> updateMcqInstruction({
    required List<String> dos,
    required List<String> donts,
  }) async {
    try {
      await supabase.from('mcq_settings').upsert({
        'id': 1,
        'dos': dos,
        'donts': donts,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } on PostgrestException catch (e) {
      debugPrint(
        'Supabase MCQ instruction update error: ${e.message} - ${e.details}',
      );
      return false;
    } catch (e) {
      debugPrint('Error updating mcq instruction: $e');
      return false;
    }
  }

  Future<void> refreshCurrentUserData() async {
    if (currentUserRole == null) return;
    try {
      String table;
      String idCol;
      dynamic idVal;

      if (currentUserRole == UserRole.student) {
        table = 'student_registered_details';
        idCol = 'enrollno';
        idVal = loggedEnrollNo;
        if (idVal == null) {
          // Fallback check
          return;
        }
      } else if (currentUserRole == UserRole.teacher) {
        table = 'teacher_register_details';
        idCol = 'teacher_id';
        idVal = loggedTeacherId;
        if (idVal == null) return;
      } else {
        // Admin
        return;
      }

      final res = await supabase
          .from(table)
          .select()
          .eq(idCol, idVal)
          .maybeSingle();
      if (res != null) {
        currentUserData = Map<String, dynamic>.from(res);

        // Sync individuals for UI compatibility
        loggedName = res['name']?.toString();
        loggedPhone = res['phone']?.toString();
        loggedDepartment = res['department']?.toString();
        loggedYear = res['year']?.toString();
        loggedSemester = res['semester']?.toString();

        if (currentUserRole == UserRole.teacher) {
          loggedDesignation = res['designation']?.toString();
        }

        saveSession();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
    }
  }

  // Course Papers Management
  Future<List<Map<String, dynamic>>> fetchPapersForCourse(int courseId) async {
    try {
      final data = await supabase
          .from('course_papers')
          .select()
          .eq('course_id', courseId)
          .order('paper_name', ascending: true);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('Error fetching papers: $e');
      return [];
    }
  }

  Future<bool> addPaperToCourse({
    required int courseId,
    required String paperName,
    required String paperId,
  }) async {
    try {
      await supabase.from('course_papers').insert({
        'course_id': courseId,
        'paper_name': paperName,
        'paper_id': paperId,
      });
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Supabase add paper error: ${e.message} - ${e.details}');
      return false;
    } catch (e) {
      debugPrint('Error adding paper: $e');
      return false;
    }
  }

  Future<bool> deletePaper(int id) async {
    try {
      await supabase.from('course_papers').delete().eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Supabase delete paper error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error deleting paper: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllTeacherEnrollments() async {
    try {
      final res = await supabase.from('teacher_enrollments').select();
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching teachers: $e');
      return [];
    }
  }

  Future<void> deleteTeacherEnrollment(String teacherId) async {
    try {
      await supabase
          .from('teacher_enrollments')
          .delete()
          .eq('teacher_id', teacherId);
    } catch (e) {
      debugPrint('Error deleting teacher: $e');
      rethrow;
    }
  }

  Future<void> toggleStudentBlock(String enrollNo, bool blockStatus) async {
    try {
      await supabase
          .from('student_registered_details')
          .update({'is_blocked': blockStatus})
          .eq('enrollno', enrollNo);
      fetchRegisteredStudents(); // Refresh list
    } catch (e) {
      debugPrint('Error toggling student block: $e');
      rethrow;
    }
  }

  void setMeetingCode(String code) {
    activeMeetingCode = code;
    notifyListeners();
  }

  Future<void> addAssignment(
    String classId,
    String title,
    String dueDate, {
    String? paperId, // Added paperId
    String year = 'All',
    String semester = 'All',
    PlatformFile? file,
    List<dynamic>? mcqData,
    int timePerQuestion = 30,
    int? questionsToShow,
    DateTime? startDateTime,
    DateTime? dueDateTime,
    bool isFlagged = false,
  }) async {
    final salt = Random().nextInt(10000);
    final newId = 'a_${DateTime.now().microsecondsSinceEpoch}_$salt';
    final assignment = {
      'id': newId,
      'title': title,
      'dueDate': dueDate,
      'dueDateTime': dueDateTime,
      'startDateTime': startDateTime,
      'year': year,
      'semester': semester,
      'instructorFileName': file?.name,
      'mcqData': mcqData,
      'timePerQuestion': timePerQuestion,
      'questionsToShow': questionsToShow,
      'isDone': false,
      'paperId': paperId,
      'isFlagged': isFlagged,
    };
    classAssignments.putIfAbsent(classId, () => []).insert(0, assignment);
    notifyListeners();

    // Persist to Supabase
    try {
      if (mcqData != null) {
        final Map<String, dynamic> mcqPayload = {
          'id': newId,
          'class_id': classId,
          'title': title,
          'due_datetime': dueDateTime?.toUtc().toIso8601String(),
          'start_datetime': startDateTime?.toUtc().toIso8601String(),
          'mcq_data': mcqData,
          'year': year,
          'semester': semester,
          'time_per_question': timePerQuestion,
          'random_question_count': questionsToShow,
          'is_flagged': isFlagged,
          'paper_id': paperId,
        };

        try {
          await supabase.from('teacher_mcq_content').insert(mcqPayload);
        } catch (e) {
          debugPrint('Supabase insert failed with extra columns, retrying basic: $e');
          // Retry with basic columns only
          await supabase.from('teacher_mcq_content').insert({
            'id': newId,
            'class_id': classId,
            'title': title,
            'due_datetime': dueDateTime?.toUtc().toIso8601String(),
            'start_datetime': startDateTime?.toUtc().toIso8601String(),
            'mcq_data': mcqData,
            'year': year,
            'semester': semester,
            'time_per_question': timePerQuestion,
            'random_question_count': questionsToShow,
          });
        }
      } else {
        // UPLOAD TEACHER FILE IF EXISTS
        if (file != null) {
          try {
            final fileBytes = file.bytes;
            if (fileBytes != null) {
              final storagePath = '$newId/${file.name}';
              await supabase.storage
                  .from('assignment-files')
                  .uploadBinary(
                    storagePath,
                    fileBytes,
                    fileOptions: const FileOptions(upsert: true),
                  );
              debugPrint('Teacher assignment file uploaded: $storagePath');
            }
          } catch (e) {
            debugPrint('Teacher storage upload error: $e');
          }
        }

        await supabase.from('teacher_assignment_content').insert({
          'id': newId,
          'class_id': classId,
          'title': title,
          'due_date': dueDate,
          'due_datetime': dueDateTime?.toUtc().toIso8601String(),
          'instructor_file_name': file?.name,
          'year': year,
          'semester': semester,
          'paper_id': paperId, // Reference paper
        });
      }
    } catch (e) {
      debugPrint('Supabase addAssignment error: $e');
    }
  }

  // Load assignments from Supabase and merge into local maps
  Future<void> loadAssignmentsFromSupabase() async {
    try {
      isAssignmentsLoading = true;
      notifyListeners();

      // Clear old local state to reflect possible updates/deletions from DB
      classAssignments.clear();

      fetchRegisteredStudents(); // Load students
      fetchActiveDepartments(); // Load active departments (courses)
      if (currentUserRole == UserRole.teacher) {
        _fetchTeacherMappingFromSupabase();
      }

      // Run independent fetches in parallel for speed
      final results = await Future.wait([
        supabase.from('teacher_mcq_content').select(),
        supabase.from('teacher_assignment_content').select(),
        supabase.from('student_registered_details').select(),
        supabase.from('teacher_register_details').select('department'),
      ]);

      final mcqRows = results[0] as List;
      final assRows = results[1] as List;

      // Update student lists and depts in background or sync them
      registeredStudents = List<Map<String, dynamic>>.from(results[2] as List);
      final List<String> depts = (results[3] as List)
          .map((e) => e['department']?.toString() ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
      activeDepartments = depts;

      for (final row in mcqRows) {
        _processAssignmentRow(row as Map<String, dynamic>, isMcq: true);
      }
      for (final row in assRows) {
        _processAssignmentRow(row as Map<String, dynamic>, isMcq: false);
      }

      // 3. Load Student Statuses (Current student ONLY)
      final studentId = loggedEnrollNo ?? loggedPhone ?? loggedEmail;
      if (studentId != null) {
        final statusResults = await Future.wait([
          supabase
              .from('student_mcq_results')
              .select()
              .eq('student_id', studentId),
          supabase
              .from('student_assignment_responses')
              .select()
              .eq('student_id', studentId),
        ]);

        final mcqResults = statusResults[0] as List;
        for (final r in mcqResults) {
          _updateLocalStatus(
            r['mcq_id'],
            r as Map<String, dynamic>,
            isMcq: true,
          );
        }

        final assResults = statusResults[1] as List;
        for (final r in assResults) {
          _updateLocalStatus(
            r['assignment_id'],
            r as Map<String, dynamic>,
            isMcq: false,
          );
        }
      }
      isAssignmentsLoading = false;
      notifyListeners();
    } catch (e) {
      isAssignmentsLoading = false;
      notifyListeners();
      debugPrint('Supabase loadAssignments error: $e');
    }
  }

  void _processAssignmentRow(Map<String, dynamic> row, {required bool isMcq}) {
    String? rawId = row['class_id'] as String?;
    if (rawId == null) return;
    final classId = _normalizeClassId(rawId);

    classAssignments.putIfAbsent(classId, () => []);

    // Avoid duplicates
    if (!classAssignments[classId]!.any((a) => a['id'] == row['id'])) {
      classAssignments[classId]!.insert(0, {
        'id': row['id'],
        'title': row['title'],
        'dueDate': row['due_date'] ?? '',
        'dueDateTime': row['due_datetime'] != null
            ? DateTime.tryParse(row['due_datetime'])?.toLocal()
            : null,
        'startDateTime': row['start_datetime'] != null
            ? DateTime.tryParse(row['start_datetime'])?.toLocal()
            : null,
        'year': row['year'] ?? 'All',
        'semester': row['semester'] ?? 'All',
        'instructorFileName': row['instructor_file_name'],
        'mcqData': row['mcq_data'],
        'timePerQuestion': row['time_per_question'] ?? 30,
        'questionsToShow': row['random_question_count'],
        'isFlagged': row['is_flagged'] ?? false,
        'paperId': (row['paper_id'] != null && row['paper_id'].toString().trim().isNotEmpty) ? row['paper_id'] : null,
        'isFlagged': row['is_flagged'] ?? false,
        'isDone': false,
      });
    }
  }

  void _updateLocalStatus(
    String aId,
    Map<String, dynamic> status, {
    required bool isMcq,
  }) {
    bool done = isMcq
        ? (status['is_completed'] == true)
        : (status['is_turned_in'] == true);
    if (!done) return;

    for (var list in classAssignments.values) {
      for (var a in list) {
        if (a['id'] == aId) {
          a['isDone'] = true;
          if (isMcq) {
            mcqScores[aId] = status['score'];
            mcqFlagged[aId] = status['is_flagged'] ?? false;
            final dynamic rawAns = status['student_answers'];
            if (rawAns != null) {
              if (rawAns is Map && rawAns.containsKey('responses')) {
                // New nested format
                final Map res = rawAns['responses'] as Map;
                mcqStudentAnswers[aId] = res.map(
                  (k, v) => MapEntry(int.parse(k.toString()), v as int),
                );
                if (rawAns['questions'] != null) {
                  mcqStudentPresentedQuestions[aId] =
                      rawAns['questions'] as List<dynamic>;
                }
              } else if (rawAns is Map) {
                // Legacy flat format (fallback)
                mcqStudentAnswers[aId] = rawAns.map(
                  (k, v) => MapEntry(int.parse(k.toString()), v as int),
                );
              }
            }
          }
        }
      }
    }
  }

  void toggleTurnIn(String assignmentId) {
    for (var list in classAssignments.values) {
      for (var a in list) {
        if (a['id'] == assignmentId) {
          bool currentlyDone = a['isDone'] ?? false;
          if (!currentlyDone) {
            // Trying to Submit
            int submitCount = assignmentSubmissionCounts[assignmentId] ?? 0;
            if (submitCount >= 2) return; // Block further submissions
            assignmentSubmissionCounts[assignmentId] = submitCount + 1;
          } else {
            // Trying to Unsubmit (Undone)
            int unsubmitCount = assignmentUnsubmitCounts[assignmentId] ?? 0;
            if (unsubmitCount >= 1)
              return; // Block if already used the one undo chance
            assignmentUnsubmitCounts[assignmentId] = unsubmitCount + 1;
            assignmentSubmissions.remove(
              assignmentId,
            ); // Clear old files on undone
          }
          a['isDone'] = !a['isDone'];
          notifyListeners();

          // Persist to Supabase
          _upsertAssignmentStatus(
            assignmentId: assignmentId,
            isDone: a['isDone'] == true,
            isMcq: a['mcqData'] != null,
          );
          return;
        }
      }
    }
  }

  void submitFiles(String assignmentId, List<PlatformFile> files) {
    // Only keep the first file if multiple were somehow provided,
    // and replace any existing submissions per the 'one file' rule.
    if (files.isNotEmpty) {
      assignmentSubmissions[assignmentId] = [files.first];
      notifyListeners();

      // Persist to Supabase if already turned in
      for (var list in classAssignments.values) {
        for (var a in list) {
          if (a['id'] == assignmentId && (a['isDone'] ?? false)) {
            _upsertAssignmentStatus(
              assignmentId: assignmentId,
              isDone: true,
              isMcq: a['mcqData'] != null,
            );
          }
        }
      }
    }
  }

  void removeFile(String assignmentId, int index) {
    assignmentSubmissions[assignmentId]?.removeAt(index);
    notifyListeners();
  }

  void addComment(String assignmentId, String comment) {
    assignmentComments.putIfAbsent(assignmentId, () => []).add(comment);
    notifyListeners();
  }

  Future<void> deleteAssignment(String classId, String assignmentId) async {
    classAssignments[classId]?.removeWhere((a) => a['id'] == assignmentId);
    // Cleanup other maps
    assignmentSubmissions.remove(assignmentId);
    assignmentComments.remove(assignmentId);
    mcqScores.remove(assignmentId);
    mcqStudentAnswers.remove(assignmentId);
    assignmentSubmissionCounts.remove(assignmentId);
    assignmentUnsubmitCounts.remove(assignmentId);
    mcqFlagged.remove(assignmentId);
    notifyListeners();
    // Delete from Supabase
    try {
      await supabase
          .from('teacher_mcq_content')
          .delete()
          .eq('id', assignmentId);
      await supabase
          .from('teacher_assignment_content')
          .delete()
          .eq('id', assignmentId);
    } catch (e) {
      debugPrint('Supabase deleteAssignment error: $e');
    }
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
          title: 'PTU',
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
          home: AppData().isLoggedIn
              ? const MainLayoutScreen()
              : (AppData().isRegistrationPending
                    ? (AppData().currentUserRole == UserRole.teacher
                          ? const TeacherRegistrationScreen()
                          : const StudentRegistrationScreen())
                    : const LoginScreen()),
        );
      },
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
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 1000;

    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) => Scaffold(
        drawer: isMobile
            ? Drawer(
                width: 280,
                backgroundColor: Colors.white,
                child: SafeArea(child: _buildSidebarContent()),
              )
            : null,
        body: Row(
          children: [
            if (!isMobile)
              Container(
                width: 260,
                color: Colors.white,
                child: _buildSidebarContent(),
              ),

            // Vertical Divider (Desktop Only)
            if (!isMobile) Container(width: 1, color: Colors.grey.shade200),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Header
                  Container(
                    height: 80,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 40,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isMobile)
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu_rounded),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                            ),
                          ),
                        if (isMobile) const SizedBox(width: 8),
                        if (isMobile)
                          const Text(
                            'PTU',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        const Spacer(),
                        const SizedBox(width: 8),
                        if (!isMobile)
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
                                    color: const Color(
                                      0xFF6C5CE7,
                                    ).withAlpha(200),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded),
                          onPressed: () {},
                        ),
                        if (!isMobile)
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
      ),
    );
  }

  Widget _buildSidebarContent() {
    return Column(
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
                'PTU_PORTAL',
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
              if (AppData().currentUserRole == UserRole.admin) ...[
                _buildNavItem(
                  Icons.dashboard_customize_rounded,
                  'Admin Dashboard',
                  NavPage.adminDashboard,
                ),
                _buildNavItem(
                  Icons.menu_book_rounded,
                  'Manage Courses',
                  NavPage.manageCourses,
                ),
                _buildNavItem(
                  Icons.people_alt_rounded,
                  'Manage Teachers',
                  NavPage.manageTeachers,
                ),
                _buildNavItem(
                  Icons.person_search_rounded,
                  'Manage Students',
                  NavPage.manageStudents,
                ),
                _buildNavItem(
                  Icons.school_rounded,
                  'Student details',
                  NavPage.studentDetails,
                ),
              ] else ...[
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
              _buildNavItem(Icons.person_rounded, 'Profile', NavPage.profile),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: OutlinedButton.icon(
            onPressed: () {
              AppData().logout();
            },
            icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
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
    );
  }

  Widget _buildUserInfo() {
    UserRole role = AppData().currentUserRole;
    String name =
        AppData().loggedName ??
        (role == UserRole.admin
            ? 'Administrator'
            : (role == UserRole.teacher ? 'Teacher' : 'Student'));

    Color bgColor = Colors.blue.shade100;
    Color iconColor = Colors.blue.shade800;
    IconData icon = Icons.face;
    String subText = 'Student Portal';

    if (role == UserRole.teacher) {
      bgColor = Colors.amber.shade100;
      iconColor = Colors.amber.shade800;
      icon = Icons.person_4;
      subText = 'Teacher Portal';
    } else if (role == UserRole.admin) {
      bgColor = Colors.purple.shade100;
      iconColor = Colors.purple.shade800;
      icon = Icons.admin_panel_settings_rounded;
      subText = 'Admin Portal';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subText,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, NavPage page) {
    bool isSelected = AppData().currentPage == page;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          AppData().setPage(page);
          if (MediaQuery.of(context).size.width < 1000) {
            Navigator.pop(context); // Auto-close drawer on mobile
          }
        },
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
    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) {
        switch (AppData().currentPage) {
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
          case NavPage.profile:
            return const ProfileView();
          case NavPage.adminDashboard:
            return const AdminDashboardView();
          case NavPage.manageCourses:
            return const ManageCoursesView();
          case NavPage.manageTeachers:
            return const ManageTeachersView();
          case NavPage.manageStudents:
            return const ManageStudentsView();
          case NavPage.studentDetails:
            return const ManageStudentsView();
        }
      },
    );
  }
}

class McqCentralView extends StatefulWidget {
  const McqCentralView({super.key});

  @override
  State<McqCentralView> createState() => _McqCentralViewState();
}

class _McqCentralViewState extends State<McqCentralView> {
  Set<String> selectedIds = {};
  bool isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppData().loadAssignmentsFromSupabase();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) {
        // Flatten assignments that have mcqData
        List<Map<String, dynamic>> allMcqTests = [];
        for (var cls in AppData().filteredClasses) {
          var assigns = AppData().filteredAssignments(cls['id'] ?? '');
          for (var a in assigns) {
            if (a['mcqData'] != null) {
              allMcqTests.add({'classData': cls, 'assignment': a});
            }
          }
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: () => AppData().loadAssignmentsFromSupabase(),
            color: const Color(0xFF6C5CE7),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12.0 : 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isTeacher ? 'Review MCQs' : 'MCQs To-Do',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isTeacher && selectedIds.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.download_for_offline,
                                  color: Color(0xFF6C5CE7),
                                ),
                                onPressed: () =>
                                    _bulkDownloadMarks(allMcqTests),
                                tooltip: 'Download Selected Marks',
                              ),
                          ],
                        ),
                        if (isTeacher) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => openCreateMcqTestDialog(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Upload MCQ JSON'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              isTeacher
                                  ? 'MCQ Tests To Review'
                                  : 'Your MCQ Tests To-Do',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isTeacher && selectedIds.isNotEmpty) ...[
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _bulkDownloadMarks(allMcqTests),
                                icon: const Icon(Icons.download_rounded),
                                label: Text(
                                  'Download Marks (${selectedIds.length})',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF6C5CE7),
                                  side: const BorderSide(
                                    color: Color(0xFF6C5CE7),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (isTeacher)
                          ElevatedButton.icon(
                            onPressed: () => openCreateMcqTestDialog(context),
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
              SizedBox(height: isMobile ? 16 : 32),
              Expanded(
                child: allMcqTests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No pending MCQ Tests found for your department.',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Checked: ${AppData().loggedDepartment ?? 'Unset'}',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                            const SizedBox(height: 24),
                            TextButton.icon(
                              onPressed: () => AppData().loadAssignmentsFromSupabase(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh Data'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: allMcqTests.length,
                        padding: const EdgeInsets.only(bottom: 100),
                        itemBuilder: (ctx, idx) {
                          var item = allMcqTests[idx];
                          var a = item['assignment'];
                          var cls = item['classData'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (isSelectionMode) {
                                  setState(() {
                                    if (selectedIds.contains(a['id'])) {
                                      selectedIds.remove(a['id']);
                                      if (selectedIds.isEmpty) isSelectionMode = false;
                                    } else {
                                      selectedIds.add(a['id']!);
                                    }
                                  });
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AssignmentInteractionScreen(
                                      assignment: a,
                                      classColor: cls['color'],
                                      classData: cls,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: isTeacher
                                  ? () {
                                      setState(() {
                                        isSelectionMode = true;
                                        selectedIds.add(a['id']);
                                      });
                                    }
                                  : null,
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                                child: Row(
                                  children: [
                                    if (isTeacher)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: GestureDetector(
                                          onTap:
                                              () {}, // Prevent card tap when clicking checkbox
                                          child: Checkbox(
                                            value: selectedIds.contains(a['id']),
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  selectedIds.add(a['id']);
                                                } else {
                                                  selectedIds.remove(a['id']);
                                                  if (selectedIds.isEmpty) isSelectionMode = false;
                                                }
                                              });
                                            },
                                            activeColor: const Color(
                                              0xFF6C5CE7,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ),
                                    CircleAvatar(
                                      radius: isMobile ? 20 : 24,
                                      backgroundColor: cls['color'].withAlpha(
                                        20,
                                      ),
                                      child: Icon(
                                        Icons.quiz,
                                        color: cls['color'],
                                        size: isMobile ? 20 : 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a['title'],
                                            style: TextStyle(
                                              fontSize: isMobile ? 16 : 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${cls['title']}\nExpires: ${a['dueDateTime']?.toString().substring(0, 16) ?? a['dueDate']}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: isMobile ? 12 : 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isTeacher)
                                      isMobile
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _showDeleteConfirmation(
                                                    context,
                                                    cls['id'],
                                                    a['id'],
                                                  ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Assigned',
                                                  style: TextStyle(
                                                    color: Color(0xFF6C5CE7),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _showDeleteConfirmation(
                                                        context,
                                                        cls['id'],
                                                        a['id'],
                                                      ),
                                                ),
                                              ],
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
          ),
        );
      },
    );
  }

  Future<void> _bulkDownloadMarks(List<Map<String, dynamic>> allTests) async {
    List<Map<String, dynamic>> testsToExport = [];
    for (String id in selectedIds) {
      final test = allTests.firstWhere(
        (t) => t['assignment']['id'] == id,
        orElse: () => {},
      );
      if (test.isNotEmpty) {
        testsToExport.add(test);
      }
    }

    if (testsToExport.isEmpty) return;

    // We will download them one by one
    for (var item in testsToExport) {
      var cls = item['classData'];
      var a = item['assignment'];

      String targetCourse = (cls['title'] ?? 'Course').toString();
      String displayName = (a['title'] ?? 'Test').toString();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Generating $displayName...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        var excel = ex.Excel.createExcel();

        // Fetch students for THIS department
        final studentsResponse = await supabase
            .from('student_registered_details')
            .select()
            .eq('department', cls['title']);
        final students = List<Map<String, dynamic>>.from(studentsResponse);

        // Fetch MCQ results for THIS test
        final statusResponse = await supabase
            .from('student_mcq_results')
            .select()
            .eq('mcq_id', a['id']);
        final statusList = List<Map<String, dynamic>>.from(statusResponse);

        final Map<String, Map<String, dynamic>> statuses = {};
        for (var row in statusList) {
          statuses[row['student_id'].toString()] = {
            'is_done': row['is_completed'],
            'mcq_score': row['score'],
            'is_flagged': row['is_flagged'] ?? false,
          };
        }

        String safeSheetName = displayName.replaceAll(
          RegExp(r'[\[\]\*\/\\\?\:]'),
          '_',
        );
        if (safeSheetName.length > 30)
          safeSheetName = safeSheetName.substring(0, 30);

        ex.Sheet sheet = excel[safeSheetName];

        // Headers
        sheet.appendRow([
          ex.TextCellValue('Student Name'),
          ex.TextCellValue('ID / Enrollment'),
          ex.TextCellValue('Status'),
          ex.TextCellValue('Score'),
          ex.TextCellValue('Flagged'),
        ]);

        for (var student in students) {
          String name = student['name'] ?? 'Unknown';
          String stdId = (student['enrollno'] ?? student['Enrollment No'] ?? '')
              .toString();

          final status = statuses[stdId];
          bool hasSubmitted = status?['is_done'] ?? false;
          int? score = status?['mcq_score'];
          bool flagged = status?['is_flagged'] ?? false;
          int totalQ =
              (a['questionsToShow'] as int?) ??
              (a['mcqData'] as List?)?.length ??
              1;

          sheet.appendRow([
            ex.TextCellValue(name),
            ex.TextCellValue(stdId),
            ex.TextCellValue(hasSubmitted ? 'Submitted' : 'Pending'),
            ex.TextCellValue(score != null ? '$score / $totalQ' : '-'),
            ex.TextCellValue(flagged ? 'YES' : 'NO'),
          ]);
        }

        if (excel.tables.containsKey('Sheet1') && excel.tables.length > 1) {
          excel.delete('Sheet1');
        }

        var fileBytes = excel.encode();
        if (mounted) Navigator.pop(context); // Close loading

        if (fileBytes != null) {
          String finalFileName = "${targetCourse}_$displayName"
              .replaceAll(RegExp(r'[^\w\s\-]'), '')
              .replaceAll(' ', '_');

          await FilePicker.platform.saveFile(
            dialogTitle: 'Save Marks for $displayName',
            fileName: '$finalFileName.xlsx',
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
            bytes: Uint8List.fromList(fileBytes),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error downloading $displayName: $e')),
          );
        }
      }
    }

    setState(() {
      selectedIds.clear();
      isSelectionMode = false;
    });
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String classId,
    String assignmentId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this test? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              AppData().deleteAssignment(classId, assignmentId);
              Navigator.pop(ctx);
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

void openCreateMcqTestDialog(
  BuildContext context, {
  String? paperId,
  VoidCallback? onComplete,
}) {
  String selectedYear = AppData().loggedYear ?? 'All';
  String selectedSem = AppData().loggedSemester ?? 'All';
  String? defaultClassId = AppData().filteredClasses.isNotEmpty
      ? AppData().filteredClasses.first['id']
      : null;

  // Initially one session with current time
  List<Map<String, dynamic>> sessions = [
    {
      'titleCtrl': TextEditingController(),
      'timeCtrl': TextEditingController(text: '30'),
      'randomCtrl': TextEditingController(),
      'isTimed': false,
      'isFlagged': false,
      'start': DateTime.now(),
      'end': DateTime.now().add(const Duration(hours: 3)),
      'mcqData': null,
      'selectedClassId': defaultClassId,
      'label': 'Session 1',
    },
  ];

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          int activeSessions = sessions
              .where((s) => s['mcqData'] != null)
              .length;

          return AlertDialog(
            backgroundColor: const Color(0xFFF8F9FE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configure MCQ Sessions',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        'Set up independent batches for the same test',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  IconButton(
                    onPressed: () => downloadMcqTemplate(context),
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Download Excel Format',
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 1000,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: sessions.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var s = entry.value;
                          return SizedBox(
                            width: 450,
                            child: Stack(
                              children: [
                                buildAdvancedSessionCard(
                                  label: s['label'],
                                  sublabel: 'Batch Session',
                                  icon: idx % 2 == 0
                                      ? Icons.wb_sunny_rounded
                                      : Icons.nights_stay_rounded,
                                  themeColor: idx % 2 == 0
                                      ? const Color(0xFF6C5CE7)
                                      : const Color(0xFFFD79A8),
                                  data: s['mcqData'],
                                  titleCtrl: s['titleCtrl'],
                                  randomCtrl: s['randomCtrl'],
                                  timeCtrl: s['timeCtrl'],
                                  isTimed: s['isTimed'],
                                  isFlagged: s['isFlagged'] ?? false,
                                  start: s['start'],
                                  end: s['end'],
                                  onToggleTimed: () => setDialogState(
                                    () => s['isTimed'] = !s['isTimed'],
                                  ),
                                  onToggleFlagged: () => setDialogState(
                                    () => s['isFlagged'] =
                                        !(s['isFlagged'] ?? false),
                                  ),
                                  onPickFile: () async {
                                    var res = await pickMcqFile(ctx);
                                    if (res != null) {
                                      setDialogState(() {
                                        s['mcqData'] = res;
                                      });
                                    }
                                  },
                                  onPickTime: (isStart) async {
                                    var dt = await pickDateTime(
                                      ctx,
                                      isStart ? s['start'] : s['end'],
                                    );
                                    if (dt != null)
                                      setDialogState(
                                        () => isStart
                                            ? s['start'] = dt
                                            : s['end'] = dt,
                                      );
                                  },
                                  selectedCourse: s['selectedClassId'],
                                  onCourseChanged: (val) => setDialogState(
                                    () => s['selectedClassId'] = val,
                                  ),
                                  context: ctx,
                                ),
                                if (sessions.length > 1)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => setDialogState(
                                        () => sessions.removeAt(idx),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            // Inherit from last session
                            var last = sessions.last;
                            sessions.add({
                              'titleCtrl': TextEditingController(), // Must be NEW
                              'timeCtrl': TextEditingController(text: last['timeCtrl'].text), // Inherit
                              'randomCtrl': TextEditingController(text: last['randomCtrl'].text), // Inherit
                              'isTimed': last['isTimed'], // Inherit
                              'isFlagged': last['isFlagged'], // Inherit
                              'start': last['start'], // Inherit
                              'end': last['end'], // Inherit
                              'mcqData': null, // Must be NEW
                              'selectedClassId': last['selectedClassId'], // Inherit
                              'label': 'Session ${sessions.length + 1}',
                            });
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Session Batch'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          side: const BorderSide(color: Color(0xFF6C5CE7)),
                          foregroundColor: const Color(0xFF6C5CE7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withAlpha(30)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade400,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Sessions marked as "Active" will be published as separate tests. Ensure document is uploaded for each batch you want to activate.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (activeSessions > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7).withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$activeSessions Active Session(s)',
                                  style: const TextStyle(
                                    color: Color(0xFF6C5CE7),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel Task',
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  // Strict Validation: Every session must be complete
                  for (var s in sessions) {
                    if (s['selectedClassId'] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a course for ${s['label']}')),
                      );
                      return;
                    }
                    if (s['titleCtrl'].text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Display Title required for ${s['label']}')),
                      );
                      return;
                    }
                    if (s['mcqData'] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please upload MCQ data for ${s['label']}')),
                      );
                      return;
                    }
                  }

                  for (var s in sessions) {
                    if (s['mcqData'] != null) {
                      await AppData().addAssignment(
                        s['selectedClassId'],
                        s['titleCtrl'].text,
                        s['end'].toString().substring(0, 16),
                        paperId: paperId, // Pass paperId
                        year: selectedYear,
                        semester: selectedSem,
                        mcqData: s['mcqData'],
                        timePerQuestion: s['isTimed']
                            ? (int.tryParse(s['timeCtrl'].text) ?? 30)
                            : 0,
                        questionsToShow: int.tryParse(s['randomCtrl'].text),
                        startDateTime: s['start'],
                        dueDateTime: s['end'],
                        isFlagged: s['isFlagged'] ?? false,
                      );
                    }
                  }

                  Navigator.pop(ctx);
                  onComplete?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF6C5CE7).withAlpha(100),
                ),
                child: Text(
                  'Deploy Test Sessions',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget buildAdvancedSessionCard({
  required String label,
  required String sublabel,
  required IconData icon,
  required Color themeColor,
  required List<dynamic>? data,
  required TextEditingController titleCtrl,
  required TextEditingController randomCtrl,
  required TextEditingController timeCtrl,
  required bool isTimed,
  required bool isFlagged,
  required DateTime start,
  required DateTime end,
  required VoidCallback onToggleTimed,
  required VoidCallback onToggleFlagged,
  required VoidCallback onPickFile,
  required Function(bool) onPickTime,
  String? selectedCourse,
  required Function(String?) onCourseChanged,
  required BuildContext context,
}) {
  bool isActive = data != null;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: isActive
              ? themeColor.withAlpha(20)
              : Colors.black.withAlpha(10),
          blurRadius: 30,
          offset: const Offset(0, 15),
        ),
      ],
      border: Border.all(
        color: isActive ? themeColor.withAlpha(80) : Colors.grey.withAlpha(30),
        width: isActive ? 2 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? themeColor.withAlpha(30)
                    : Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isActive ? themeColor : Colors.grey),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isActive ? themeColor : Colors.grey.shade800,
                  ),
                ),
                Text(
                  sublabel,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            if (isActive)
              const Icon(Icons.check_circle, color: Colors.green, size: 24)
            else
              Icon(
                Icons.circle_outlined,
                color: Colors.grey.withAlpha(50),
                size: 24,
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'BATCH CONFIGURATION',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedCourse,
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black),
          decoration: InputDecoration(
            labelText: 'Target Course',
            prefixIcon: const Icon(Icons.class_outlined),
            filled: true,
            fillColor: const Color(0xFFF8F9FE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          isExpanded: true,
          hint: const Text('Select handled course'),
          items: AppData().filteredClasses.map((cls) {
            return DropdownMenuItem<String>(
              value: cls['id'],
              child: Text(cls['title'], overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onCourseChanged,
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleCtrl,
          style: GoogleFonts.outfit(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Display Title',
            hintText: 'Enter session name',
            prefixIcon: const Icon(Icons.edit_note_rounded),
            filled: true,
            fillColor: const Color(0xFFF8F9FE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: randomCtrl,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Question Pull',
                  hintText: 'All',
                  prefixIcon: const Icon(Icons.shuffle_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: timeCtrl,
                enabled: isTimed,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Sec/Q',
                  prefixIcon: const Icon(Icons.timer_rounded),
                  filled: true,
                  fillColor: isTimed
                      ? const Color(0xFFF8F9FE)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Limited Duration Mode',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          value: isTimed,
          onChanged: (v) => onToggleTimed(),
          activeColor: themeColor,
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Anti-Cheat Flagging',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          value: isFlagged,
          onChanged: (v) => onToggleFlagged(),
          activeColor: Colors.redAccent,
        ),
        const SizedBox(height: 24),
        Text(
          'TIME WINDOW',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: buildModernTimeBox(
                'Starts At',
                _formatDateTime12h(start),
                () => onPickTime(true),
                isActive ? themeColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: buildModernTimeBox(
                'Ends At',
                _formatDateTime12h(end),
                () => onPickTime(false),
                isActive ? themeColor : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPickFile,
            icon: Icon(
              isActive ? Icons.file_present_rounded : Icons.upload_file_rounded,
            ),
            label: Text(isActive ? 'Document Ready' : 'Choose MCQ Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? themeColor : Colors.grey.shade100,
              foregroundColor: isActive ? Colors.white : Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        if (!isActive)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(
              child: TextButton.icon(
                onPressed: () => downloadMcqTemplate(context),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  'Download Template Format',
                  style: GoogleFonts.outfit(fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget buildModernTimeBox(
  String label,
  String value,
  VoidCallback onTap,
  Color themeColor,
) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  DateTime? date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime(2030),
  );
  if (date != null) {
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null) {
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
  }
  return null;
}

Future<List<dynamic>?> pickMcqFile(BuildContext context) async {
  var res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json', 'xlsx', 'xls', 'csv'],
    withData: true,
  );
  if (res == null || res.files.isEmpty || res.files.first.bytes == null)
    return null;

  final file = res.files.first;
  final extension = file.extension?.toLowerCase() ?? '';
  final bytes = file.bytes!;

  try {
    if (extension == 'json') {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is List) return data;
      return null;
    }

    if (extension == 'xlsx' || extension == 'xls') {
      var excel = ex.Excel.decodeBytes(bytes);
      List<dynamic> parsedMcq = [];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Robust extraction helper
        String getCellValue(ex.Data? data) {
          if (data == null || data.value == null) return '';
          var v = data.value;
          if (v is ex.TextCellValue) return v.value.toString().trim();
          if (v is ex.IntCellValue) return v.value.toString().trim();
          if (v is ex.DoubleCellValue) return v.value.toString().trim();
          if (v is ex.BoolCellValue) return v.value.toString().trim();
          return v.toString().trim();
        }

        // Search for the data starting point (first row with a question)
        int startRow = 1; // Default skip index 0 header
        for (int i = 0; i < sheet.maxRows && i < 10; i++) {
          if (i >= sheet.rows.length) break;
          String cellA = getCellValue(sheet.rows[i].isNotEmpty ? sheet.rows[i][0] : null).toLowerCase();
          String cellB = getCellValue(sheet.rows[i].length > 1 ? sheet.rows[i][1] : null).toLowerCase();
          if (cellA.contains('qno') || cellB.contains('question')) {
            startRow = i + 1;
            break;
          }
        }

        for (int i = startRow; i < sheet.maxRows; i++) {
          try {
            if (i >= sheet.rows.length) break;
            var row = sheet.rows[i];
            if (row.isEmpty) continue;

            // Question is Column B (index 1)
            String question = getCellValue(row.length > 1 ? row[1] : null);
            if (question.isEmpty) continue;

            // Options are Columns C-F (index 2-5)
            List<String> options = [];
            for (int col = 2; col <= 5; col++) {
              if (row.length > col) {
                String opt = getCellValue(row[col]);
                if (opt.isNotEmpty) options.add(opt);
              }
            }

            // Answer is Column G (index 6)
            String answer = getCellValue(row.length > 6 ? row[6] : null);

            if (options.length >= 2) {
              parsedMcq.add({
                'question': question,
                'options': options,
                'answer': answer,
              });
            }
          } catch (rowErr) {
            debugPrint('Error parsing row $i: $rowErr');
          }
        }
        if (parsedMcq.isNotEmpty) return parsedMcq;
      }
      throw Exception(
        'No valid questions found. Ensure Excel format: QNo, Question, Option A, Option B, Option C, Option D, Correct Answer',
      );
    }

    if (extension == 'csv') {
      final content = utf8.decode(bytes);
      final rows = const CsvToListConverter().convert(content);
      List<dynamic> parsedMcq = [];

      // Start from index 1 (skip header)
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        String question = (row.length > 1) ? row[1]?.toString().trim() ?? '' : '';
        if (question.isEmpty) continue;

        List<String> options = [];
        for (int col = 2; col <= 5; col++) {
          if (row.length > col && row[col] != null) {
            String opt = row[col].toString().trim();
            if (opt.isNotEmpty) options.add(opt);
          }
        }

        String answer = (row.length > 6 && row[6] != null)
            ? row[6].toString().trim()
            : '';

        if (options.length >= 2) {
          parsedMcq.add({
            'question': question,
            'options': options,
            'answer': answer,
          });
        }
      }
      if (parsedMcq.isNotEmpty) return parsedMcq;
      throw Exception(
        'No valid questions found in CSV file. Check format: QNo, Question, Option A, Option B, Option C, Option D, Correct Answer',
      );
    }
  } catch (e) {
    debugPrint('MCQ File Parse Error: $e');
    if (context.mounted) {
      String msg = e.toString().contains('null value')
          ? 'Format Error: Ensure Excel has QNo, Question, 4 Options, and Correct Answer columns.'
          : 'Failed to pick or parse the MCQ file.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }
  return null;
}

Future<void> downloadMcqTemplate(BuildContext context) async {
  try {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['Sheet1'];

    // Header row
    sheet.appendRow([
      ex.TextCellValue('QNo'),
      ex.TextCellValue('Question'),
      ex.TextCellValue('Option A'),
      ex.TextCellValue('Option B'),
      ex.TextCellValue('Option C'),
      ex.TextCellValue('Option D'),
      ex.TextCellValue('Correct Answer (Must match one of the options text)'),
    ]);

    // Sample data row
    sheet.appendRow([
      ex.IntCellValue(1),
      ex.TextCellValue('What is the capital of France?'),
      ex.TextCellValue('London'),
      ex.TextCellValue('Berlin'),
      ex.TextCellValue('Paris'),
      ex.TextCellValue('Madrid'),
      ex.TextCellValue('Paris'),
    ]);

    var fileBytes = excel.encode();
    if (fileBytes != null) {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save MCQ Template',
        fileName: 'mcq_template.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(fileBytes),
      );
      if (outputFile != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved successfully!')),
        );
      }
    }
  } catch (e) {
    debugPrint('Template Download Error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating template: $e')));
    }
  }
}

// ---------------------------------------------------------
// Profile View (Highly detailed and stunning)
// ---------------------------------------------------------
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    // Refresh user data from database when profile page is opened
    Future.microtask(() => AppData().refreshCurrentUserData());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) {
        final role = AppData().currentUserRole;
        final isTeacher = role == UserRole.teacher;
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(context, isTeacher, isMobile),
              const SizedBox(height: 32),
              isMobile
                  ? Column(
                      children: [
                        _buildPersonalAndAcademicInfo(isTeacher),
                        const SizedBox(height: 24),
                        _buildAccountStatusCard(),
                        const SizedBox(height: 24),
                        _buildQuickActionsCard(context),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildPersonalAndAcademicInfo(isTeacher),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildAccountStatusCard(),
                              const SizedBox(height: 24),
                              _buildQuickActionsCard(context),
                            ],
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalAndAcademicInfo(bool isTeacher) {
    final isAdmin = AppData().currentUserRole == UserRole.admin;
    return Column(
      children: [
        _buildInfoCard('Personal Information', Icons.person_outline, [
          _buildInfoRow('Full Name', AppData().loggedName ?? 'N/A'),
          if (!isAdmin) ...[
            if (isTeacher &&
                AppData().loggedEmail != null &&
                AppData().loggedEmail!.isNotEmpty)
              _buildInfoRow('Email Address', AppData().loggedEmail!),
            _buildInfoRow('Phone Number', AppData().loggedPhone ?? 'N/A'),
            if (!isTeacher)
              _buildInfoRow(
                'Registration No',
                AppData().loggedEnrollNo ?? 'N/A',
              ),
            if (isTeacher)
              _buildInfoRow('Teacher ID', AppData().loggedTeacherId ?? 'N/A'),
          ],
        ]),
        if (!isAdmin) ...[
          const SizedBox(height: 24),
          _buildInfoCard(
            isTeacher ? 'Professional Details' : 'Academic Details',
            isTeacher ? Icons.work_outline : Icons.school_outlined,
            isTeacher
                ? [
                    _buildInfoRow(
                      'Department',
                      AppData().loggedDepartment ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Designation',
                      AppData().loggedDesignation ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Academic Year',
                      AppData().loggedYear ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Current Semester',
                      AppData().loggedSemester ?? 'N/A',
                    ),
                  ]
                : [
                    _buildInfoRow(
                      'Department',
                      AppData().loggedDepartment ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Year / Semester',
                      '${AppData().loggedYear ?? 'N/A'} / ${AppData().loggedSemester ?? 'N/A'}',
                    ),
                  ],
          ),
        ],
      ],
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    bool isTeacher,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5CE7),
            const Color(0xFF6C5CE7).withBlue(255).withGreen(150),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withAlpha(60),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                _buildAvatar(isTeacher, isMobile),
                const SizedBox(height: 16),
                _buildProfileDetails(isTeacher, isMobile),
                const SizedBox(height: 16),
                _buildEditProfileButton(context, isTeacher, isMobile),
              ],
            )
          : Row(
              children: [
                _buildAvatar(isTeacher, isMobile),
                const SizedBox(width: 32),
                Expanded(child: _buildProfileDetails(isTeacher, isMobile)),
                _buildEditProfileButton(context, isTeacher, isMobile),
              ],
            ),
    );
  }

  Widget _buildAvatar(bool isTeacher, bool isMobile) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: isMobile ? 40 : 60,
            backgroundColor: Colors.white,
            child: Hero(
              tag: 'profile_avatar',
              child: Icon(
                isTeacher ? Icons.person_4 : Icons.face,
                size: isMobile ? 45 : 70,
                color: const Color(0xFF6C5CE7),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDetails(bool isTeacher, bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          AppData().loggedName ?? 'Guest User',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 22 : 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                AppData().currentUserRole == UserRole.admin
                    ? 'Administrator'
                    : (isTeacher ? 'Senior Faculty' : 'Undergraduate Student'),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            if (AppData().currentUserRole != UserRole.admin)
              Text(
                'ID: ${isTeacher ? AppData().loggedTeacherId : AppData().loggedEnrollNo}',
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditProfileButton(
    BuildContext context,
    bool isTeacher,
    bool isMobile,
  ) {
    return SizedBox(
      width: isMobile ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: () => _showEditProfileDialog(context, isTeacher),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Edit Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF6C5CE7),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, bool isTeacher) {
    final nameCtrl = TextEditingController(text: AppData().loggedName);
    final emailCtrl = TextEditingController(text: AppData().loggedEmail);
    final phoneCtrl = TextEditingController(text: AppData().loggedPhone);
    final sectionCtrl = TextEditingController(text: AppData().loggedSection);

    String? selectedYear = AppData().loggedYear;
    String? selectedSem = AppData().loggedSemester;
    String? selectedDesignation = AppData().loggedDesignation;

    final years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    final semsMap = {
      '1st Year': ['1', '2'],
      '2nd Year': ['3', '4'],
      '3rd Year': ['5', '6'],
      '4th Year': ['7', '8'],
    };
    final designations = [
      'Assistant Professor',
      'Associate Professor',
      'Professor',
      'Head of Department',
      'Lab Assistant',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final List<String> availableSems =
              semsMap[selectedYear] ?? ['1', '2', '3', '4', '5', '6', '7', '8'];
          if (!availableSems.contains(selectedSem)) {
            selectedSem = availableSems.first;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(Icons.edit_square, color: const Color(0xFF6C5CE7)),
                const SizedBox(width: 8),
                const Text('Edit Profile'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    if (!isTeacher) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: sectionCtrl,
                        decoration: InputDecoration(
                          labelText: 'Section',
                          prefixIcon: const Icon(Icons.groups_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: years.contains(selectedYear)
                                ? selectedYear
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Academic Year',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: years
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text(y),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedYear = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: availableSems.contains(selectedSem)
                                ? selectedSem
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Semester',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: availableSems
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('Sem $s'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedSem = v),
                          ),
                        ),
                      ],
                    ),
                    if (isTeacher) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: designations.contains(selectedDesignation)
                            ? selectedDesignation
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Designation',
                          prefixIcon: const Icon(Icons.work_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: designations
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedDesignation = v),
                      ),
                    ],
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
                onPressed: () async {
                  String? error = await AppData().updateProfile(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    year: selectedYear,
                    semester: selectedSem,
                    designation: isTeacher ? selectedDesignation : null,
                  );
                  if (error == null) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile Updated Successfully!'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6C5CE7), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFF0EDFF),
            child: Icon(
              Icons.verified_user,
              color: Color(0xFF6C5CE7),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Account Verified',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your account is fully registered and verified with the university portal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildActionButton(Icons.lock_outline, 'Change Password', () {}),
          _buildActionButton(
            Icons.notifications_outlined,
            'Notifications',
            () {},
          ),
          _buildActionButton(Icons.help_outline, 'Get Support', () {}),
          const Divider(height: 32),
          _buildActionButton(Icons.logout, 'Log Out', () {
            AppData().logout();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        icon,
        size: 20,
        color: isDestructive ? Colors.redAccent : Colors.grey.shade600,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.redAccent : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards - Responsive Grid/Wrap
          isMobile
              ? Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCard(
                          isTeacher ? 'Active Courses' : 'Enrolled Courses',
                          AppData().filteredClasses.length.toString(),
                          Icons.library_books,
                          Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          isTeacher ? 'Assignments' : 'Pending Tasks',
                          AppData().filteredClasses
                              .expand((cls) => AppData().filteredAssignments(cls['id'] ?? ''))
                              .where((a) => !a['isDone'])
                              .length.toString(),
                          Icons.assignment,
                          Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard(
                          isTeacher ? 'Submissions' : 'Completed',
                          AppData().filteredClasses
                              .expand((cls) => AppData().filteredAssignments(cls['id'] ?? ''))
                              .where((a) => a['isDone'])
                              .length.toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Upcoming Tests',
                          AppData().filteredClasses
                              .expand((cls) => AppData().filteredAssignments(cls['id'] ?? ''))
                              .where((a) => a['mcqData'] != null && !a['isDone'])
                              .length.toString(),
                          Icons.quiz,
                          const Color(0xFF6C5CE7),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    _buildStatCard(
                      isTeacher ? 'Active Courses' : 'Enrolled Courses',
                      AppData().filteredClasses.length.toString(),
                      Icons.library_books,
                      Colors.blue,
                    ),
                    const SizedBox(width: 24),
                    _buildStatCard(
                      isTeacher ? 'Assignments' : 'Pending Tasks',
                      AppData().filteredClasses
                          .expand((cls) => AppData().filteredAssignments(cls['id'] ?? ''))
                          .where((a) => !a['isDone'])
                          .length.toString(),
                      Icons.assignment,
                      Colors.orange,
                    ),
                    const SizedBox(width: 24),
                    _buildStatCard(
                      isTeacher ? 'Submissions' : 'Completed Work',
                      AppData().filteredClasses
                          .expand((cls) => AppData().filteredAssignments(cls['id'] ?? ''))
                          .where((a) => a['isDone'])
                          .length.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                    const SizedBox(width: 24),
                    _buildStatCard(
                      'Upcoming Tests',
                      AppData().filteredClasses
                          .expand((cls) => AppData().filteredAssignments(cls['id'] ?? ''))
                          .where((a) => a['mcqData'] != null && !a['isDone'])
                          .length.toString(),
                      Icons.quiz,
                      const Color(0xFF6C5CE7),
                    ),
                  ],
                ),
          const SizedBox(height: 32),

          // Main Content Layout
          if (isMobile)
            Column(
              children: [
                _buildActivityAnalytics(),
                const SizedBox(height: 24),
                _buildLiveClassesPanel(),
                const SizedBox(height: 24),
                _buildRecentCoursesTable(isMobile),
                const SizedBox(height: 24),
                _buildAssignmentBreakdown(),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _buildActivityAnalytics(),
                      const SizedBox(height: 32),
                      _buildRecentCoursesTable(isMobile),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildLiveClassesPanel(),
                      const SizedBox(height: 32),
                      _buildAssignmentBreakdown(),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActivityAnalytics() {
    return Container(
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
    );
  }

  Widget _buildRecentCoursesTable(bool isMobile) {
    return Container(
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ...AppData().filteredClasses.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: c['color'].withAlpha(20),
                    child: Icon(Icons.menu_book, color: c['color'], size: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Text(
                      c['title'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isMobile)
                    Expanded(
                      child: Text(
                        c['subtitle'],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c['color'].withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: c['color'],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isMobile)
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      onPressed: () {},
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveClassesPanel() {
    return Container(
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          _buildLiveClassItem('PH', 'Bank', 'Motion', Colors.teal),
          const Divider(height: 32),
          _buildLiveClassItem('LT', 'Literature', 'Sonnets', Colors.indigo),
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
    );
  }

  Widget _buildAssignmentBreakdown() {
    return Container(
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            height: 16,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(color: Colors.green.shade400),
                ),
                Expanded(
                  flex: 3,
                  child: Container(color: const Color(0xFF6C5CE7)),
                ),
                Expanded(
                  flex: 2,
                  child: Container(color: Colors.grey.shade300),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendDot(Colors.green.shade400, 'Submitted'),
              _buildLegendDot(const Color(0xFF6C5CE7), 'Grading'),
              _buildLegendDot(Colors.grey.shade300, 'Pending'),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    // Choose column count based on width
    int crossAxisCount = 3;
    if (screenWidth < 600) {
      crossAxisCount = 1;
    } else if (screenWidth < 1100) {
      crossAxisCount = 2;
    }

    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) => Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Courses',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 32),
            Expanded(
              child: GridView.builder(
                itemCount: AppData().filteredClasses.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: isMobile ? 16 : 32,
                  mainAxisSpacing: isMobile ? 16 : 32,
                  childAspectRatio: isMobile ? 1.8 : 1.3,
                ),
                itemBuilder: (context, index) {
                  final cls = AppData().filteredClasses[index];
                  return GestureDetector(
                    onTap: () {
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
                              padding: EdgeInsets.all(isMobile ? 16 : 24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          cls['title'],
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isMobile ? 16 : 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          cls['subtitle'],
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(200),
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.menu_book,
                                    color: Colors.white.withAlpha(150),
                                    size: isMobile ? 24 : 32,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Explore Syllabus',
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: cls['color'],
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
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String courseName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: Text(
          'Are you sure you want to remove "$courseName"? This will remove it from your dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              AppData().removeTeacherCourse(courseName);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$courseName" removed successfully.'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(20),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    String? selectedCourse;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Add New Course',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a course from the following list to add it to your profile.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: selectedCourse,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Choose Course',
                    prefixIcon: const Icon(Icons.library_books_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF6C5CE7),
                        width: 2,
                      ),
                    ),
                  ),
                  items: AppData().predefinedCourses.map((
                    Map<String, dynamic> course,
                  ) {
                    final name = course['name'].toString();
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setDialogState(() {
                      selectedCourse = newValue;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: selectedCourse == null
                  ? null
                  : () {
                      AppData().addTeacherCourse(selectedCourse!);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Course "$selectedCourse" added successfully!',
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add Course'),
            ),
          ],
        ),
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
  bool isVideoOff = true;

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
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildPreCall() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.all(isMobile ? 24 : 40),
        child: Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Camera Preview Section
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 600,
              ),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
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
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off,
                              color: Colors.white54,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Camera module removed",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
            if (!isMobile) const SizedBox(width: 80),
            if (isMobile) const SizedBox(height: 48),
            // Join Controls Section
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 400,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: isMobile
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to join?',
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: isMobile ? 32 : 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No one else is here yet',
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  Wrap(
                    alignment: isMobile
                        ? WrapAlignment.center
                        : WrapAlignment.start,
                    spacing: 16,
                    runSpacing: 16,
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
                  Text(
                    'Other joining options',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.screen_share,
                      color: Color(0xFF6C5CE7),
                      size: 20,
                    ),
                    label: const Text(
                      'Use companion mode',
                      style: TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontWeight: FontWeight.w600,
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
  }

  Widget _buildStudentThumbnail(int i) {
    if (i == 0 && !isVideoOff) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Icon(Icons.person, color: Colors.white54, size: 48),
            ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.all(isMobile ? 24 : 60),
        child: Column(
          children: [
            if (isMobile) ...[
              const SizedBox(height: 20),
              _buildMeetIllustration(isMobile, screenWidth),
              const SizedBox(height: 40),
            ],
            Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: isMobile
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium video meetings. Now free for everyone.',
                        textAlign: isMobile
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          fontSize: isMobile ? 28 : 48,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'We re-engineered the service we built for secure business meetings, Google Meet, to make it free and available for all.',
                        textAlign: isMobile
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: isMobile ? 15 : 18,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (isTeacher)
                        _buildTeacherActions(isMobile)
                      else
                        _buildStudentActions(isMobile),
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
                if (!isMobile) ...[
                  const SizedBox(width: 80),
                  Expanded(
                    flex: 1,
                    child: _buildMeetIllustration(isMobile, screenWidth),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetIllustration(bool isMobile, double screenWidth) {
    return Center(
      child: CircleAvatar(
        radius: isMobile ? screenWidth * 0.3 : 150,
        backgroundColor: const Color(0xFF6C5CE7).withAlpha(20),
        child: Icon(
          Icons.groups,
          size: isMobile ? screenWidth * 0.2 : 120,
          color: const Color(0xFF6C5CE7),
        ),
      ),
    );
  }

  Widget _buildTeacherActions(bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? double.infinity : null,
          child: ElevatedButton.icon(
            onPressed: _generateAndShowMeetingCode,
            icon: const Icon(Icons.video_call),
            label: const Text('New meeting'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
      ],
    );
  }

  Widget _buildStudentActions(bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? double.infinity : 280,
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
                      onChanged: (val) => setState(() => joinErrorMsg = null),
                      decoration: const InputDecoration(
                        hintText: 'Enter a code or link',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 12 : 0),
            TextButton(
              onPressed: () {
                if (joinCodeCtrl.text.trim() == AppData().activeMeetingCode) {
                  setState(() => isCodeVerified = true);
                } else {
                  setState(() => joinErrorMsg = 'Invalid meeting code');
                }
              },
              child: Text(
                'Join',
                style: TextStyle(
                  fontSize: 16,
                  color: joinCodeCtrl.text.isEmpty
                      ? Colors.grey
                      : const Color(0xFF6C5CE7),
                  fontWeight: FontWeight.bold,
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
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    );
  }

  void _generateAndShowMeetingCode() {
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
              "Copy this link and send it to people you want to meet with.",
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
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
                  icon: const Icon(Icons.copy, color: Colors.grey),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: newCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
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
  }

  @override
  Widget build(BuildContext context) {
    if (!isCodeVerified) return _buildGoogleMeetHome();
    if (!isInCall) return _buildPreCall();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Container(
      color: const Color(0xFF202124), // Google Meet dark grey
      child: Stack(
        children: [
          Row(
            children: [
              // Video Area
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
                        child: GridView.builder(
                          itemCount: 6,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isMobile
                                    ? 2
                                    : (isChatOpen ? 2 : 3),
                                crossAxisSpacing: isMobile ? 8 : 16,
                                mainAxisSpacing: isMobile ? 8 : 16,
                                childAspectRatio: isMobile ? 1.0 : (16 / 9),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 24,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isMobile)
                            const Text(
                              "10:24 AM • Class Sync",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          // Center Controls
                          Expanded(
                            child: Row(
                              mainAxisAlignment: isMobile
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                _buildControlBtn(
                                  isMicMuted ? Icons.mic_off : Icons.mic_none,
                                  isMicMuted
                                      ? Colors.red
                                      : const Color(0xFF3C4043),
                                  () =>
                                      setState(() => isMicMuted = !isMicMuted),
                                  iconColor: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                                const SizedBox(width: 8),
                                _buildControlBtn(
                                  isVideoOff
                                      ? Icons.videocam_off
                                      : Icons.videocam_outlined,
                                  isVideoOff
                                      ? Colors.red
                                      : const Color(0xFF3C4043),
                                  () =>
                                      setState(() => isVideoOff = !isVideoOff),
                                  iconColor: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                                if (!isMobile) ...[
                                  const SizedBox(width: 8),
                                  _buildControlBtn(
                                    Icons.closed_caption_off_outlined,
                                    const Color(0xFF3C4043),
                                    () {},
                                    iconColor: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildControlBtn(
                                    Icons.back_hand_outlined,
                                    const Color(0xFF3C4043),
                                    () {},
                                    iconColor: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildControlBtn(
                                    Icons.present_to_all_outlined,
                                    const Color(0xFF3C4043),
                                    () {},
                                    iconColor: Colors.white,
                                  ),
                                ],
                                const SizedBox(width: 8),
                                _buildControlBtn(
                                  Icons.call_end,
                                  Colors.red,
                                  () => setState(() => isInCall = false),
                                  iconColor: Colors.white,
                                  isLarge: true,
                                  size: isMobile ? 20 : 24,
                                ),
                              ],
                            ),
                          ),
                          // Right Controls
                          Row(
                            children: [
                              if (!isMobile)
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
                                  size: 20,
                                ),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.chat_bubble_outline,
                                  color: isChatOpen
                                      ? const Color(0xFF8AB4F8)
                                      : Colors.white,
                                  size: 20,
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

              // Desktop Chat Panel
              if (!isMobile && isChatOpen)
                Container(
                  width: 320,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                    ),
                  ),
                  margin: const EdgeInsets.only(top: 16),
                  child: _buildChatContent(),
                ),
            ],
          ),

          // Mobile Chat Overlay
          if (isMobile && isChatOpen)
            Positioned.fill(
              child: Container(color: Colors.white, child: _buildChatContent()),
            ),
        ],
      ),
    );
  }

  Widget _buildChatContent() {
    return Column(
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
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              suffixIcon: const Icon(Icons.send, color: Color(0xFF6C5CE7)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildControlBtn(
  IconData icon,
  Color bgColor,
  VoidCallback onTap, {
  bool isLarge = false,
  Color iconColor = Colors.white,
  double? size,
}) {
  double containerWidth = isLarge ? 80 : 48;
  double containerHeight = isLarge ? 56 : 48;

  // Scale container if custom size is provided
  if (size != null) {
    containerWidth = isLarge ? size * 3 : size * 2;
    containerHeight = isLarge ? size * 2.2 : size * 2;
  }

  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: containerHeight,
      width: containerWidth,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Icon(icon, color: iconColor, size: size ?? (isLarge ? 28 : 22)),
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
        Text(msg, style: const TextStyle(color: Colors.black87, fontSize: 14)),
      ],
    ),
  );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    // Flatten assignments
    List<Map<String, dynamic>> allAssignments = [];
    for (var cls in AppData().filteredClasses) {
      var assigns = AppData().filteredAssignments(cls['id'] ?? '');
      for (var a in assigns) {
        if (a['mcqData'] == null) {
          allAssignments.add({'classData': cls, 'assignment': a});
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTeacher ? 'Review Assignments' : 'Your To-Do',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isTeacher) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => openCreateAssignmentDialog(
                              context,
                              null,
                              onComplete: () => setState(() {}),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('New Global Assignment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C5CE7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
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
                          onPressed: () => openCreateAssignmentDialog(
                            context,
                            null,
                            onComplete: () => setState(() {}),
                          ),
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
            SizedBox(height: isMobile ? 16 : 32),
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
                              classData: cls,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: isMobile ? 20 : 24,
                              backgroundColor: cls['color'].withAlpha(20),
                              child: Icon(
                                Icons.assignment,
                                color: cls['color'],
                                size: isMobile ? 20 : 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['title'],
                                    style: TextStyle(
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (a['startDateTime'] != null &&
                                            a['dueDateTime'] != null)
                                        ? '${cls['title']}\n${a['dueDateTime'].toString().substring(0, 16)}'
                                        : '${cls['title']}  •  Due: ${a['dueDate']}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isTeacher)
                              isMobile
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => _showDeleteConfirmation(
                                        context,
                                        cls['id'],
                                        a['id'],
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Assigned',
                                          style: TextStyle(
                                            color: const Color(0xFF6C5CE7),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _showDeleteConfirmation(
                                                context,
                                                cls['id'],
                                                a['id'],
                                              ),
                                        ),
                                      ],
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

  void _showDeleteConfirmation(
    BuildContext context,
    String classId,
    String assignmentId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this assignment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              AppData().deleteAssignment(classId, assignmentId);
              Navigator.pop(ctx);
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
} // Added closing brace for class

void openCreateAssignmentDialog(
  BuildContext context,
  String? manualClassId, {
  String? paperId,
  VoidCallback? onComplete,
}) {
  TextEditingController titleCtrl = TextEditingController();
  DateTime startDateTime = DateTime.now();
  DateTime endDateTime = DateTime.now().add(const Duration(days: 7));
  PlatformFile? pickedFile;
  List<dynamic>? mcqData;
  String selectedYear = AppData().loggedYear ?? 'All';
  String selectedSem = AppData().loggedSemester ?? 'All';

  String? currentSelectedClassId =
      manualClassId ??
      (AppData().filteredClasses.isNotEmpty
          ? AppData().filteredClasses.first['id']
          : null);

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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: currentSelectedClassId,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Target Course',
                        prefixIcon: Icon(Icons.class_outlined),
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      hint: const Text('Select handled course'),
                      items: AppData().filteredClasses.map((cls) {
                        return DropdownMenuItem<String>(
                          value: cls['id'],
                          child: Text(
                            cls['title'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => currentSelectedClassId = val),
                      validator: (v) => v == null ? 'Required' : null,
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
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          TimeOfDay? time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(startDateTime),
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
                  if (titleCtrl.text.isNotEmpty &&
                      currentSelectedClassId != null) {
                    AppData().addAssignment(
                      currentSelectedClassId!,
                      titleCtrl.text,
                      endDateTime.toString().substring(0, 16),
                      paperId: paperId, // Pass paperId
                      year: selectedYear,
                      semester: selectedSem,
                      file: pickedFile,
                      mcqData: mcqData,
                      startDateTime: startDateTime,
                      dueDateTime: endDateTime,
                    );
                    Navigator.pop(ctx);
                    if (onComplete != null) onComplete();
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
  List<Map<String, dynamic>> papers = [];
  bool papersLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPapers();
    // Fetch students enrolled in this course (based on department title)
    AppData().fetchStudentsByDepartment(widget.classData['title']);
  }

  Future<void> _loadPapers() async {
    // Ensure predefinedCourses are loaded for name -> ID mapping
    if (AppData().predefinedCourses.isEmpty) {
      await AppData().fetchPredefinedCourses();
    }

    final cId = AppData().getCourseIdByName(widget.classData['title']);
    if (cId != null) {
      setState(() => papersLoading = true);
      try {
        final p = await AppData().fetchPapersForCourse(cId);
        if (mounted) {
          setState(() {
            papers = p;
            papersLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => papersLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    String classId = widget.classData['id'];
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classData['title']),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 40),
        child: Column(
          children: [
            // Massive Header Banner
            Container(
              height: isMobile ? 180 : 250,
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
              padding: EdgeInsets.all(isMobile ? 24 : 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.classData['title'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 22 : 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.classData['subtitle'],
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: isMobile ? 13 : 18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 24 : 48),

            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPapersSection(isMobile),
                      const SizedBox(height: 32),
                      const SizedBox(height: 16),
                      _buildUpcomingDueCard(),
                      if (AppData().currentUserRole == UserRole.teacher) ...[
                        const SizedBox(height: 24),
                        _buildEnrolledStudentsSection(isMobile),
                      ],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPapersSection(isMobile),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      SizedBox(
                        width: 380,
                        child: Column(
                          children: [
                            _buildUpcomingDueCard(),
                            if (AppData().currentUserRole == UserRole.teacher) ...[
                              const SizedBox(height: 24),
                              _buildEnrolledStudentsSection(isMobile),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingDueCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Course Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRowItem(
            Icons.portrait,
            'Faculty In-Charge',
            widget.classData['teacherName'] ?? 'Dr. Rajesh Kumar',
          ),
          _buildInfoRowItem(
            Icons.workspace_premium_outlined,
            'Designation',
            widget.classData['teacherDesignation'] ?? 'Professor',
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledStudentsSection(bool isMobile) {
    return AnimatedBuilder(
      animation: AppData(),
      builder: (context, _) {
        final students = AppData().enrolledStudents;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enrolled Students',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${students.length}',
                      style: const TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No students enrolled yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: students.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade100, height: 24),
                  itemBuilder: (context, index) {
                    final s = students[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(
                                0xFF6C5CE7,
                              ).withAlpha(20),
                              child: Text(
                                s['name']?.substring(0, 1).toUpperCase() ?? 'S',
                                style: const TextStyle(
                                  color: Color(0xFF6C5CE7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['name'] ?? 'Unknown Name',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Enroll: ${s['enrollno'] ?? s['Enrollment No']}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: Row(
                            children: [
                              _buildStudentTag(s['year'] ?? 'N/A'),
                              const SizedBox(width: 8),
                              _buildStudentTag('Sem ${s['semester'] ?? 'N/A'}'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPapersSection(bool isMobile) {
    if (papersLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (papers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withAlpha(30)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 16),
            Text('No papers assigned to this course yet.'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Papers',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: papers.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 1 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 100,
          ),
          itemBuilder: (ctx, idx) {
            final p = papers[idx];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaperDetailScreen(
                      paperData: p,
                      classData: widget.classData,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
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
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: widget.classData['color'].withAlpha(20),
                      child: Icon(
                        Icons.description,
                        color: widget.classData['color'],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p['paper_name'] ?? 'Unknown Paper',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ID: ${p['paper_id'] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStudentTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoRowItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6C5CE7).withAlpha(150)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String classId,
    String assignmentId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this assignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              AppData().deleteAssignment(classId, assignmentId);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openCreateAssignmentDialog(BuildContext context, String classId) {
    TextEditingController titleCtrl = TextEditingController();
    DateTime startDateTime = DateTime.now();
    DateTime endDateTime = DateTime.now().add(const Duration(days: 7));
    String selectedYear = AppData().loggedYear ?? 'All';
    String selectedSem = AppData().loggedSemester ?? 'All';
    PlatformFile? pickedFile;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Assignment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Assignment Title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        'Start: ${startDateTime.toString().substring(0, 16)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        DateTime? d = await showDatePicker(
                          context: ctx,
                          initialDate: startDateTime,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setDialogState(() => startDateTime = d);
                      },
                    ),
                    ListTile(
                      title: Text(
                        'End: ${endDateTime.toString().substring(0, 16)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        DateTime? d = await showDatePicker(
                          context: ctx,
                          initialDate: endDateTime,
                          firstDate: startDateTime,
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setDialogState(() => endDateTime = d);
                      },
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
                        endDateTime.toString().substring(0, 16),
                        year: selectedYear,
                        semester: selectedSem,
                        file: pickedFile,
                        startDateTime: startDateTime,
                        dueDateTime: endDateTime,
                      );
                      Navigator.pop(ctx);
                      setState(() {});
                    }
                  },
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
  Set<int> _visitedMcqIndices = {};

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
                  'This test starts at ${_formatDateTime12h(startTime)}.\nPlease return when the timer begins.',
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
      } else if (answersData is Map && answersData.isNotEmpty) {
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
                  if (presentedCount > originalMcqData.length)
                    presentedCount = originalMcqData.length;

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
                  if (presentedCount > originalMcqData.length)
                    presentedCount = originalMcqData.length;

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