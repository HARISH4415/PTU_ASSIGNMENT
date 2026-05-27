import 'package:flutter/material.dart';

import 'package:ptu/models/app_data.dart';
import 'package:ptu/screens/assignment_interaction_screen.dart';
import '../main.dart';
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
