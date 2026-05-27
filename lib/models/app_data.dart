import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

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

    final list =
        classAssignments[normalizedId] ?? classAssignments[classId] ?? [];

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
      final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(
        data as List,
      );
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
          debugPrint(
            'Supabase insert failed with extra columns, retrying basic: $e',
          );
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
        'paperId':
            (row['paper_id'] != null &&
                row['paper_id'].toString().trim().isNotEmpty)
            ? row['paper_id']
            : null,
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
