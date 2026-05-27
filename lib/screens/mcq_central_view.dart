import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;

import 'package:ptu/models/app_data.dart';
import 'package:ptu/screens/assignment_interaction_screen.dart';
import '../main.dart';
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
        if (safeSheetName.length > 30) {
          safeSheetName = safeSheetName.substring(0, 30);
        }

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
