import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth.dart';


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


  runApp(const PTU_PORTALApp());
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
enum UserRole { student, teacher }

enum NavPage { dashboard, courses, liveClass, assignments, mcq, profile }

class AppData extends ChangeNotifier {
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;
  AppData._internal() {
    loadSession();
  }

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

      notifyListeners();
      loadAssignmentsFromSupabase();
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  UserRole currentUserRole = UserRole.student;
  NavPage currentPage = NavPage.dashboard;
  String? activeMeetingCode;

  bool isLoggedIn = false;
  String? loggedEmail;
  String? loggedPhone;
  String? loggedEnrollNo;
  String? loggedTeacherId;
  String? loggedName;
  String? loggedDepartment;
  String? loggedDesignation;
  String? loggedYear;
  String? loggedSemester;
  String? loggedSection;
  bool isRegistrationPending = false;
  List<Map<String, dynamic>> registeredStudents = [];
  List<String> activeDepartments = [];
  Map<String, Map<String, dynamic>> currentAssignmentStatuses =
      {}; // student_id -> status_row

  void setPage(NavPage page) {
    currentPage = page;
    notifyListeners();
  }

  // Shared state (now dynamic based on department)
  List<Map<String, dynamic>> classes = [];

  List<Map<String, dynamic>> get filteredClasses {
    if (!isLoggedIn) return [];

    if (currentUserRole == UserRole.teacher) {
      String? dept = loggedDepartment;
      if (dept == null || dept.isEmpty) return [];
      return [_buildClassNode(dept)];
    } else {
      // Students see all active departments
      if (activeDepartments.isEmpty) {
        // Fallback to their own department if no others found yet
        if (loggedDepartment != null && loggedDepartment!.isNotEmpty) {
          return [_buildClassNode(loggedDepartment!)];
        }
        return [];
      }
      return activeDepartments.map((d) => _buildClassNode(d)).toList();
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
    }

    return {
      'id': 'dept_${dept.replaceAll(' ', '_').toLowerCase()}',
      'title': dept,
      'subtitle': currentUserRole == UserRole.teacher
          ? 'Prof. $loggedName'
          : 'Faculty Course',
      'color': courseColor,
      'progress': 0.50,
      'time': '00:00:00',
    };
  }

  List<Map<String, dynamic>> filteredAssignments(String classId) {
    final list = classAssignments[classId];
    if (list == null) return [];

    // Filter by Year/Sem for BOTH students and teachers
    return list.where((a) {
      final targetYear = a['year']?.toString().trim() ?? 'All';
      final targetSem = a['semester']?.toString().trim() ?? 'All';

      // "All" is a wildcard that matches everyone
      bool yearMatch =
          targetYear == 'All' ||
          targetYear.toLowerCase() == (loggedYear?.toLowerCase().trim() ?? '');
      bool semMatch =
          targetSem == 'All' ||
          targetSem.toLowerCase() ==
              (loggedSemester?.toLowerCase().trim() ?? '');

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

  Future<void> fetchActiveDepartments() async {
    try {
      final data = await supabase
          .from('teacher_register_details')
          .select('department');
      final List<String> depts = (data as List)
          .map((e) => e['department']?.toString() ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
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

      if (registeredCheck != null){
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
          saveSession();
          notifyListeners();
          return true;
        }
      } catch (_) {}
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

  void setMeetingCode(String code) {
    activeMeetingCode = code;
    notifyListeners();
  }

  Future<void> addAssignment(
    String classId,
    String title,
    String dueDate, {
    String year = 'All',
    String semester = 'All',
    PlatformFile? file,
    List<dynamic>? mcqData,
    int timePerQuestion = 30,
    int? questionsToShow,
    DateTime? startDateTime,
    DateTime? dueDateTime,
  }) async {
    final newId = 'a_${DateTime.now().millisecondsSinceEpoch}';
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
    };
    classAssignments.putIfAbsent(classId, () => []).insert(0, assignment);
    notifyListeners();

    // Persist to Supabase
    try {
      if (mcqData != null) {
        await supabase.from('teacher_mcq_content').insert({
          'id': newId,
          'class_id': classId,
          'title': title,
          'due_datetime': dueDateTime?.toUtc().toIso8601String(),
          'start_datetime': startDateTime?.toUtc().toIso8601String(),
          'mcq_data': mcqData,
          'time_per_question': timePerQuestion,
          'random_question_count': questionsToShow,
        });
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
        });
      }
    } catch (e) {
      debugPrint('Supabase addAssignment error: $e');
    }
  }

  // Load assignments from Supabase and merge into local maps
  Future<void> loadAssignmentsFromSupabase() async {
    try {
      fetchRegisteredStudents(); // Load students
      fetchActiveDepartments(); // Load active departments (courses)

      // 1. Fetch MCQs
      final mcqRows = await supabase.from('teacher_mcq_content').select();
      for (final row in mcqRows) {
        _processAssignmentRow(row, isMcq: true);
      }

      // 2. Fetch Assignments
      final assRows = await supabase
          .from('teacher_assignment_content')
          .select();
      for (final row in assRows) {
        _processAssignmentRow(row, isMcq: false);
      }

      // 3. Load Student Statuses (Current student ONLY)
      final studentId = loggedEnrollNo ?? loggedPhone ?? loggedEmail;
      if (studentId != null) {
        // Load MCQ Results
        final mcqResults = await supabase
            .from('student_mcq_results')
            .select()
            .eq('student_id', studentId);
        for (final r in mcqResults) {
          _updateLocalStatus(r['mcq_id'], r, isMcq: true);
        }

        // Load Assignment Results
        final assResults = await supabase
            .from('student_assignment_responses')
            .select()
            .eq('student_id', studentId);
        for (final r in assResults) {
          _updateLocalStatus(r['assignment_id'], r, isMcq: false);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase loadAssignments error: $e');
    }
  }

  void _processAssignmentRow(Map<String, dynamic> row, {required bool isMcq}) {
    final classId = row['class_id'] as String?;
    if (classId == null) return;
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
class PTU_PORTALApp extends StatelessWidget {
  const PTU_PORTALApp({super.key});

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
                              onPressed: () => Scaffold.of(context).openDrawer(),
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
                                    color:
                                        const Color(0xFF6C5CE7).withAlpha(200),
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
              _buildNavItem(
                Icons.person_rounded,
                'Profile',
                NavPage.profile,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: OutlinedButton.icon(
            onPressed: () {
              AppData().logout();
            },
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
    );
  }

  Widget _buildUserInfo() {
    UserRole role = AppData().currentUserRole;
    String name = AppData().loggedName ??
        (role == UserRole.teacher ? 'Teacher' : 'Student');
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
                  role == UserRole.teacher
                      ? 'Teacher Portal'
                      : 'Student Portal',
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
  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
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
                                          '${cls['title']}\nStart: ${a['startDateTime']?.toString().substring(0, 16) ?? 'N/A'}  •  End: ${a['dueDateTime']?.toString().substring(0, 16) ?? a['dueDate']}  •  ${a['questionsToShow'] ?? a['mcqData'].length} Questions${a['questionsToShow'] != null ? ' (Randomly selected from ${a['mcqData'].length})' : ''}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isTeacher)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${AppData().registeredStudents.length} Assigned',
                                          style: const TextStyle(
                                            color: Color(0xFF6C5CE7),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          tooltip: 'Delete Test',
                                          onPressed: () {
                                            _showDeleteConfirmation(
                                              context,
                                              cls['id'],
                                              a['id'],
                                            );
                                          },
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

  void _openCreateMcqTestDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController timeCtrl = TextEditingController(text: '30');
    TextEditingController randomCountCtrl = TextEditingController();
    DateTime startDateTime = DateTime.now();
    DateTime endDateTime = DateTime.now().add(const Duration(minutes: 30));
    String selectedYear = AppData().loggedYear ?? 'All';
    String selectedSem = AppData().loggedSemester ?? 'All';
    String? selectedClassId = AppData().filteredClasses.isNotEmpty
        ? AppData().filteredClasses.first['id']
        : null;
    List<dynamic>? mcqData;
    bool isTimed = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            int qCount = mcqData?.length ?? 0;
            int timePerQ = int.tryParse(timeCtrl.text) ?? 30;

            int showCount = int.tryParse(randomCountCtrl.text) ?? qCount;
            if (showCount <= 0 || showCount > qCount) showCount = qCount;

            int totalSeconds = showCount * timePerQ;
            String totalTimeStr = isTimed
                ? '${totalSeconds ~/ 60}m ${totalSeconds % 60}s'
                : 'No Limit';

            return AlertDialog(
              title: const Text('Upload MCQ JSON Test'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'MCQ Test Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: randomCountCtrl,
                        decoration: InputDecoration(
                          labelText: 'Questions to randomly select',
                          border: const OutlineInputBorder(),
                          hintText: qCount > 0
                              ? 'Max: $qCount'
                              : 'Upload JSON first',
                          helperText: qCount > 0
                              ? 'Leave empty to share all $qCount questions'
                              : null,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (val) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: Text(
                          'Start: ${_formatDateTime12h(startDateTime)}',
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
                        title: Text('End: ${_formatDateTime12h(endDateTime)}'),
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
                      SwitchListTile(
                        title: const Text('Enable Timer'),
                        subtitle: const Text(
                          'Sets a time limit per question',
                        ),
                        value: isTimed,
                        onChanged: (val) => setDialogState(() => isTimed = val),
                        activeColor: const Color(0xFF6C5CE7),
                      ),
                      const SizedBox(height: 16),
                      if (isTimed)
                        TextField(
                          controller: timeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Time per question (seconds)',
                            border: const OutlineInputBorder(),
                            helperText: 'Total Test Time: $totalTimeStr',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (val) => setDialogState(() {}),
                        ),
                      if (isTimed) const SizedBox(height: 16),
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
                              debugPrint('MCQ JSON Error: $e');
                            }
                          }
                        },
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          mcqData != null
                              ? 'JSON Selected (${mcqData!.length} Qs)'
                              : 'Select MCQ JSON File',
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
                      int timePerQ = isTimed
                          ? (int.tryParse(timeCtrl.text) ?? 30)
                          : 0;

                      int? questionsToShow = int.tryParse(randomCountCtrl.text);
                      if (questionsToShow != null &&
                          (questionsToShow <= 0 || questionsToShow > qCount)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Invalid number of questions to select. Must be between 1 and $qCount.',
                            ),
                          ),
                        );
                        return;
                      }

                      int effectiveShowCount = questionsToShow ?? qCount;
                      int totalSeconds = effectiveShowCount * timePerQ;
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
                        year: selectedYear,
                        semester: selectedSem,
                        mcqData: mcqData,
                        timePerQuestion: timePerQ,
                        questionsToShow: questionsToShow,
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
// Profile View (Highly detailed and stunning)
// ---------------------------------------------------------
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final role = AppData().currentUserRole;
    final isTeacher = role == UserRole.teacher;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(context, isTeacher),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildInfoCard(
                      'Personal Information',
                      Icons.person_outline,
                      [
                        _buildInfoRow(
                          'Full Name',
                          AppData().loggedName ?? 'N/A',
                        ),
                        if (isTeacher && AppData().loggedEmail != null && AppData().loggedEmail!.isNotEmpty)
                          _buildInfoRow(
                            'Email Address',
                            AppData().loggedEmail!,
                          ),
                        _buildInfoRow(
                          'Phone Number',
                          AppData().loggedPhone ?? 'N/A',
                        ),
                        if (!isTeacher)
                          _buildInfoRow(
                            'Registration No',
                            AppData().loggedEnrollNo ?? 'N/A',
                          ),
                        if (isTeacher)
                          _buildInfoRow(
                            'Teacher ID',
                            AppData().loggedTeacherId ?? 'N/A',
                          ),
                      ],
                    ),
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
                ),
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
  }

  Widget _buildProfileHeader(BuildContext context, bool isTeacher) {
    return Container(
      padding: const EdgeInsets.all(32),
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
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: Hero(
                    tag: 'profile_avatar',
                    child: Icon(
                      isTeacher ? Icons.person_4 : Icons.face,
                      size: 70,
                      color: const Color(0xFF6C5CE7),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppData().loggedName ?? 'Guest User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        isTeacher ? 'Senior Faculty' : 'Undergraduate Student',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ID: ${isTeacher ? AppData().loggedTeacherId : AppData().loggedEnrollNo}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showEditProfileDialog(context, isTeacher),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6C5CE7),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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
                AppData().filteredClasses.length.toString(),
                Icons.library_books,
                Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                isTeacher ? 'Assignments Created' : 'Pending Assignments',
                AppData().filteredClasses
                    .expand(
                      (cls) => AppData().filteredAssignments(cls['id'] ?? ''),
                    )
                    .where((a) => !a['isDone'])
                    .length
                    .toString(),
                Icons.assignment,
                Colors.orange,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                isTeacher ? 'Submissions to Review' : 'Completed Work',
                AppData().filteredClasses
                    .expand(
                      (cls) => AppData().filteredAssignments(cls['id'] ?? ''),
                    )
                    .where((a) => a['isDone'])
                    .length
                    .toString(),
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
                          ...AppData().filteredClasses.map(
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
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c['color'].withAlpha(20),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'Active',
                                          style: TextStyle(
                                            color: c['color'],
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
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
                            'Bank',
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
              itemCount: AppData().filteredClasses.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 32,
                mainAxisSpacing: 32,
                childAspectRatio: 1.3,
              ),
              itemBuilder: (context, index) {
                final cls = AppData().filteredClasses[index];
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                Icon(
                                  Icons.menu_book,
                                  color: Colors.white.withAlpha(150),
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Explore Syllabus',
                                  style: TextStyle(
                                    fontSize: 13,
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
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off, color: Colors.white54, size: 64),
                          SizedBox(height: 16),
                          Text(
                            "Camera module removed",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
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
                                    (a['startDateTime'] != null &&
                                            a['dueDateTime'] != null)
                                        ? '${cls['title']}\nWindow: ${a['startDateTime'].toString().substring(0, 16)} to ${a['dueDateTime'].toString().substring(0, 16)}  •  ${a['year']} ${a['semester']}'
                                        : '${cls['title']}  •  Due: ${a['dueDate']}  •  ${a['year']} ${a['semester']}',
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${AppData().registeredStudents.length} Assigned',
                                    style: const TextStyle(
                                      color: Color(0xFF6C5CE7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Delete Assignment',
                                    onPressed: () {
                                      _showDeleteConfirmation(
                                        context,
                                        cls['id'],
                                        a['id'],
                                      );
                                    },
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

  void _openCreateAssignmentDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    DateTime startDateTime = DateTime.now();
    DateTime endDateTime = DateTime.now().add(const Duration(days: 7));
    String? selectedClassId = AppData().filteredClasses.first['id'];
    String selectedYear = AppData().loggedYear ?? 'All';
    String selectedSem = AppData().loggedSemester ?? 'All';
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
                        endDateTime.toString().substring(0, 16),
                        year: selectedYear,
                        semester: selectedSem,
                        file: pickedFile,
                        mcqData: mcqData,
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
                          List assigns = AppData()
                              .filteredAssignments(classId)
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
                                                (a['startDateTime'] != null &&
                                                        a['dueDateTime'] !=
                                                            null)
                                                    ? 'Window: ${a['startDateTime'].toString().substring(0, 16)} to ${a['dueDateTime'].toString().substring(0, 16)}  •  ${a['year']} ${a['semester']}'
                                                    : 'Due: ${a['dueDate']}  •  ${a['year']} ${a['semester']}',
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
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                ((a['isDone'] ?? false) &&
                                                        !(a['isMissed'] ??
                                                            false))
                                                    ? '1 Submitted'
                                                    : '0 Submitted',
                                                style: const TextStyle(
                                                  color: Color(0xFF6C5CE7),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _showDeleteConfirmation(
                                                    context,
                                                    classId,
                                                    a['id'],
                                                  );
                                                },
                                              ),
                                            ],
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
          'Are you sure you want to delete this classwork? This action cannot be undone.',
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
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
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
                        endDateTime.toString().substring(0, 16),
                        year: selectedYear,
                        semester: selectedSem,
                        file: pickedFile,
                        mcqData: mcqData,
                        startDateTime: startDateTime,
                        dueDateTime: endDateTime,
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
    extends State<AssignmentInteractionScreen>
    with WidgetsBindingObserver {
  int currentMcqIndex = 0;
  final Map<int, int> mcqAnswers = {};
  Timer? _mcqTimer;
  int _mcqTimeLeft = 30;
  int _tabSwitchCount = 0;
  int _backPressCount = 0;
  bool _isNavigatingOut = false;

  bool _isWarningDialogShown = false;
  bool _hasTabSwitchPending = false;
  bool _isMcqStartPressed = false;

  List<dynamic> _shuffledMcqData = [];

  Timer? _clockTimer;

  get stdId => null;

  @override
  void initState() {
    super.initState();
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
             _isNavigatingOut = true;
             _submitMcq(); // Auto-saves any progress and redirects
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
        _submitMcq(); // Correctly calculates score and redirects
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

    if (isStudent && !isTurnedIn && isMcq && _isMcqStartPressed) {
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

    if (isStudent && !isTurnedIn && isMcq && _isMcqStartPressed) {
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
      // For non-MCQ, already finished, or before test start, just pop normally
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
      if (currentMcqIndex < mcqData.length - 1) {
        currentMcqIndex++;
        _startMcqTimer();
      } else {
        _mcqTimer?.cancel();
        _submitMcq();
      }
    });
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

    if (context.mounted) {
      AppData().setPage(NavPage.dashboard);
      Navigator.popUntil(context, (route) => route.isFirst);
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
        body: AnimatedBuilder(
          animation: AppData(),
          builder: (context, _) {
            List<PlatformFile> attachedFiles =
                AppData().assignmentSubmissions[widget.assignment['id']] ?? [];
            bool isTurnedIn = widget.assignment['isDone'] ?? false;

            DateTime? dueTime = widget.assignment['dueDateTime'];
            bool isPastDue = dueTime != null && DateTime.now().isAfter(dueTime);

            if (AppData().currentUserRole == UserRole.student &&
                !isTurnedIn &&
                isPastDue) {
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(150),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_note_rounded,
                                size: 16,
                                color: widget.classColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (widget.assignment['startDateTime'] != null &&
                                        widget.assignment['dueDateTime'] !=
                                            null)
                                    ? 'Window: ${widget.assignment['startDateTime'].toString().substring(0, 16)} to ${widget.assignment['dueDateTime'].toString().substring(0, 16)}'
                                    : 'Due by ${widget.assignment['dueDate']}',
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
              return FutureBuilder(
                future: AppData().fetchAssignmentStatusesForTeacher(
                  widget.assignment['id'],
                  isMcq: widget.assignment['mcqData'] != null,
                ),
                builder: (context, snapshot) {
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
                                final assignmentId = widget.assignment['id'];
                                final fName =
                                    widget.assignment['instructorFileName'];
                                final storagePath = '$assignmentId/$fName';

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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not open file URL'),
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
                                        color: widget.classColor.withAlpha(20),
                                        borderRadius: BorderRadius.circular(12),
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
                              border: Border.all(color: Colors.grey.shade200),
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
                  const SizedBox(width: 64),
                  Expanded(
                    flex: 2,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentUploadPanel(
    List<PlatformFile> attachedFiles,
    bool isTurnedIn,
    bool isPastDue,
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
                  'This test starts at ${_formatDateTime12h(startTime)}.\nPlease return when the timer begins.',
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
                        color:
                            (isFlagged || isTimedOut
                                    ? Colors.red
                                    : Colors.green)
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
                    color: (isFlagged || isTimedOut)
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isFlagged
                      ? 'Test Terminated!'
                      : (isTimedOut
                            ? 'Test is Over!'
                            : 'Quiz Completed or Finished!'),
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
                  const SizedBox(height: 48),
                  const Text(
                    'Examination Instructions',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInstructionItem(
                    Icons.check_circle_outline,
                    'Do: Ensure a stable internet connection before starting.',
                    Colors.green,
                  ),
                  _buildInstructionItem(
                    Icons.check_circle_outline,
                    'Do: Read each question carefully before selecting an answer.',
                    Colors.green,
                  ),
                  _buildInstructionItem(
                    Icons.highlight_off_rounded,
                    'Don\'t: Switch tabs or minimize the test window (Security Violation).',
                    Colors.red,
                  ),
                  _buildInstructionItem(
                    Icons.highlight_off_rounded,
                    'Don\'t: Attempt to go back to the previous page during the test.',
                    Colors.red,
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

    var q = mcqData[currentMcqIndex];
    double progress = (currentMcqIndex + 1) / mcqData.length;

    return Stack(
      children: [
        Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Navigation Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
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
                                    backgroundColor: widget.classColor
                                        .withAlpha(20),
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
                    if (_mcqTimeLeft >= 0)
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
                                onTap: () {
                                  setState(() {
                                    mcqAnswers[currentMcqIndex] = optIndex;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? widget.classColor.withAlpha(20)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? widget.classColor
                                          : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: widget.classColor
                                                  .withAlpha(15),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Info text about auto-submit at the end
                    if (currentMcqIndex == mcqData.length - 1 && _mcqTimeLeft >= 0)
                      Text(
                        'Auto-submitting in $_mcqTimeLeft s...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    else
                      const SizedBox(),

                    // Control Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Skip Button
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              mcqAnswers.remove(currentMcqIndex);
                            });
                            _moveToNextQuestionOrSubmit();
                          },
                          icon: const Icon(
                            Icons.keyboard_double_arrow_right,
                            color: Colors.orange,
                          ),
                          label: const Text(
                            'Skip Question',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            _moveToNextQuestionOrSubmit();
                          },
                          icon: Icon(
                            currentMcqIndex == mcqData.length - 1
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            currentMcqIndex == mcqData.length - 1
                                ? 'Finish Test & Submit'
                                : 'Next Question',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.classColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
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


      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                AppData().registeredStudents.length.toString(),
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
        if (AppData().registeredStudents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No students found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...AppData().registeredStudents.map((student) {
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
                if (DateTime.now().isBefore(
                  widget.assignment['dueDateTime'] ??
                      DateTime.now().add(const Duration(days: 1)),
                ))
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: TextButton.icon(
                      onPressed: () {
                        AppData().unTerminateMcq(widget.assignment['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Student attempt restored. Student can now retry the quiz.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
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
                  ),
              ],
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
    final allStudents = AppData().registeredStudents;
    final statuses = AppData().currentAssignmentStatuses;
    final originalMcqData = (widget.assignment['mcqData'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Students MCQ Summary'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: SingleChildScrollView(
            child: DataTable(
              horizontalMargin: 12,
              columnSpacing: 16,
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
                int presentedCount = (widget.assignment['questionsToShow'] as int?) ?? originalMcqData.length;
                if (presentedCount > originalMcqData.length) presentedCount = originalMcqData.length;

                if (rawAnswers is Map) {
                  if (rawAnswers.containsKey('responses')) {
                    // Modern format: has 'questions' and 'responses' keys
                    answeredCount = (rawAnswers['responses'] as Map).length;
                    presentedCount = (rawAnswers['questions'] as List?)?.length ?? presentedCount;
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
                    DataCell(Text(name, style: const TextStyle(fontSize: 12))),
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
                            color: hasSubmitted ? Colors.green : Colors.orange,
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
                  int presentedCount = (widget.assignment['questionsToShow'] as int?) ?? originalMcqData.length;
                  if (presentedCount > originalMcqData.length) presentedCount = originalMcqData.length;

                  if (rawAnswers is Map) {
                    if (rawAnswers.containsKey('responses')) {
                      answeredCount = (rawAnswers['responses'] as Map).length;
                      presentedCount = (rawAnswers['questions'] as List?)?.length ?? presentedCount;
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
                    ex.TextCellValue(score != null ? "$score / $presentedCount" : "-"),
                    ex.TextCellValue(isFlagged ? "YES" : "NO"),
                  ]);
                }

                var fileBytes = excel.save();
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
