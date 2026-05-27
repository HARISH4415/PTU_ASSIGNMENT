import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../paper_views.dart';

import 'package:ptu/models/app_data.dart';
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
