import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';

// ---------------------------------------------------------
// Paper Details Screen
// ---------------------------------------------------------
class PaperDetailScreen extends StatefulWidget {
  final Map<String, dynamic> paperData;
  final Map<String, dynamic> classData;

  const PaperDetailScreen({
    super.key,
    required this.paperData,
    required this.classData,
  });

  @override
  State<PaperDetailScreen> createState() => _PaperDetailScreenState();
}

class _PaperDetailScreenState extends State<PaperDetailScreen> {
  @override
  Widget build(BuildContext context) {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    String classId = widget.classData['id'];
    String paperId = widget.paperData['paper_id'].toString();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(widget.paperData['paper_name']),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Paper Info Header
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.classData['color'] ?? const Color(0xFF6C5CE7), (widget.classData['color'] ?? const Color(0xFF6C5CE7)).withAlpha(180)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (widget.classData['color'] ?? const Color(0xFF6C5CE7)).withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withAlpha(50),
                    child: const Icon(Icons.description, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.paperData['paper_name'],
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: isMobile ? 20 : 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Course: ${widget.classData['title']}  •  Paper ID: $paperId',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            if (isTeacher) ...[
              Text(
                'Assessment Controls',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'Create Assignment',
                      sub: 'Upload descriptive tasks',
                      icon: Icons.assignment_add,
                      color: const Color(0xFF6C5CE7),
                      onTap: () => openCreateAssignmentDialog(context, classId, paperId: paperId, onComplete: () => setState(() {})),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      title: 'Create MCQ Test',
                      sub: 'Set up automated quiz',
                      icon: Icons.quiz_outlined,
                      color: const Color(0xFFFD79A8),
                      onTap: () => openCreateMcqTestDialog(context, paperId: paperId, onComplete: () => setState(() {})),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],

            Text(
              'Paper Resources & History',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildPaperClassworkList(classId, paperId, isMobile, isTeacher),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(20),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperClassworkList(String classId, String paperId, bool isMobile, bool isTeacher) {
    return AnimatedBuilder(
      animation: AppData(),
      builder: (ctx, _) {
        // Filter assignments by THIS paper
        List assigns = AppData()
            .filteredAssignments(classId)
            .where((a) => a['paperId'] == paperId || a['paperId'] == null)
            .toList();

        if (assigns.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No activities or assignments for this paper yet.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: assigns.map((a) {
            bool isMcq = a['mcqData'] != null;
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AssignmentInteractionScreen(
                        assignment: a,
                        classColor: widget.classData['color'] ?? const Color(0xFF6C5CE7),
                        classData: widget.classData,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 18 : 24,
                        backgroundColor: (isMcq ? const Color(0xFFFD79A8) : (widget.classData['color'] ?? const Color(0xFF6C5CE7))).withAlpha(20),
                        child: Icon(
                          isMcq ? Icons.quiz_outlined : Icons.assignment,
                          color: isMcq ? const Color(0xFFFD79A8) : (widget.classData['color'] ?? const Color(0xFF6C5CE7)),
                          size: isMobile ? 18 : 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['title'],
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (a['dueDateTime'] != null)
                                  ? 'Due: ${a['dueDateTime'].toString().substring(0, 16)}'
                                  : 'Due: ${a['dueDate']}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: isMobile ? 11 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isTeacher)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _showDeleteConfirmation(context, classId, a['id']),
                        )
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String classId, String assignmentId) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this activity?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
