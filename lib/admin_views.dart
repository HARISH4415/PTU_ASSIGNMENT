import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';

// ---------------------------------------------------------
// Admin Specific Views
// ---------------------------------------------------------

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await AppData().fetchRegisteredStudents();
    await AppData().fetchPredefinedCourses();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome back! Here is what happening across the portal.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
            SizedBox(height: isMobile ? 32 : 48),

            if (isMobile)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Courses',
                      AppData().predefinedCourses.length.toString(),
                      Icons.book_rounded,
                      Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Total Students',
                      AppData().registeredStudents.length.toString(),
                      Icons.people_rounded,
                      Colors.blue,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Courses',
                      AppData().predefinedCourses.length.toString(),
                      Icons.book_rounded,
                      Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildStatCard(
                      'Total Students',
                      AppData().registeredStudents.length.toString(),
                      Icons.people_rounded,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 48),

            // Refreshed layout from here...
            Text(
              'Quick Access',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (isMobile) ...[
              _buildQuickAction(
                context,
                'Add New Course',
                'Expand the curriculum',
                Icons.add_business_rounded,
                Colors.blue,
                NavPage.manageCourses,
              ),
              const SizedBox(height: 16),
              _buildQuickAction(
                context,
                'Enroll Teacher',
                'Add faculty members',
                Icons.person_add_rounded,
                Colors.purple,
                NavPage.manageTeachers,
              ),
              const SizedBox(height: 16),
              _buildQuickAction(
                context,
                'Manage Students',
                'View all registered students',
                Icons.people_alt_rounded,
                Colors.orange,
                NavPage.manageStudents,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      'Add New Course',
                      'Expand the curriculum',
                      Icons.add_business_rounded,
                      Colors.blue,
                      NavPage.manageCourses,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      'Enroll Teacher',
                      'Add faculty members',
                      Icons.person_add_rounded,
                      Colors.purple,
                      NavPage.manageTeachers,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showInstructionDialog(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withAlpha(30)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.orange, size: 28),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Test Instruction',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Global rules for MCQ',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded, color: Colors.orange),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInstructionDialog(BuildContext context) {
    List<String> dos = [];
    List<String> donts = [];
    bool isLoading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isLoading) {
            AppData().fetchMcqInstruction().then((value) {
              dos = value['dos'] ?? [];
              donts = value['donts'] ?? [];
              setDialogState(() => isLoading = false);
            });
          }

          void _addPoint(bool isDo) {
            final entryController = TextEditingController();
            showDialog(
              context: ctx,
              builder: (pctx) => AlertDialog(
                title: Text(isDo ? 'Add DO Point' : 'Add DON''T Point'),
                content: TextField(
                  controller: entryController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Enter instruction point...'),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(pctx), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                      if (entryController.text.trim().isNotEmpty) {
                        setDialogState(() {
                          if (isDo) dos.add(entryController.text.trim());
                          else donts.add(entryController.text.trim());
                        });
                      }
                      Navigator.pop(pctx);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            );
          }

          Widget _buildSection(String title, List<String> items, bool isDo) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      onPressed: () => _addPoint(isDo),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add ${isDo ? 'Do' : 'Don''t'}'),
                      style: TextButton.styleFrom(foregroundColor: isDo ? Colors.green : Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No points added yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  ...items.asMap().entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(isDo ? Icons.check_circle_outline : Icons.cancel_outlined, 
                               size: 16, color: isDo ? Colors.green : Colors.red),
                          const SizedBox(width: 12),
                          Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13))),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            onPressed: () => setDialogState(() => items.removeAt(entry.key)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 16),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Manage Test Instructions'),
            content: SizedBox(
              width: 600,
              child: isLoading
                  ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSection('DO''S (Recommended actions)', dos, true),
                          const Divider(),
                          _buildSection('DON''TS (Prohibited actions)', donts, false),
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setDialogState(() => isLoading = true);
                        final success = await AppData().updateMcqInstruction(dos: dos, donts: donts);
                        if (success && ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test instructions updated successfully!')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Instructions'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String val,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: color.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            val,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3436),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String title,
    String sub,
    IconData icon,
    Color color,
    NavPage page,
  ) {
    return InkWell(
      onTap: () => AppData().setPage(page),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class ManageCoursesView extends StatefulWidget {
  const ManageCoursesView({super.key});

  @override
  State<ManageCoursesView> createState() => _ManageCoursesViewState();
}

class _ManageCoursesViewState extends State<ManageCoursesView> {
  final TextEditingController _courseController = TextEditingController();
  bool _isAdding = false;

  Future<void> _addCourse() async {
    final name = _courseController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await AppData().addCourseMaster(name);
      _courseController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => AppData().setPage(NavPage.adminDashboard),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
                Text(
                  'Manage Courses',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Course',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _courseController,
                          decoration: InputDecoration(
                            hintText: 'Enter course name (e.g. Data Science)',
                            prefixIcon: const Icon(Icons.book_outlined),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isAdding ? null : _addCourse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isAdding
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Add Course'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            const Text(
              'Existing Courses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width < 800 ? 1 : 3,
                mainAxisExtent: 80,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: AppData().predefinedCourses.length,
              itemBuilder: (context, index) {
                final course = AppData().predefinedCourses[index];
                final courseName = course['name'].toString();
                final courseId = course['id'] as int;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          courseName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showManagePapersDialog(context, courseId, courseName),
                        icon: const Icon(Icons.assignment_outlined, color: Color(0xFF6C5CE7), size: 20),
                        tooltip: 'Manage Papers',
                      ),
                      IconButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Course'),
                              content: Text(
                                'Are you sure you want to delete "$courseName"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await AppData().deleteCourseMaster(courseId);
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        tooltip: 'Delete Course',
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManagePapersDialog(BuildContext context, int courseId, String courseName) {
    final paperNameCtrl = TextEditingController();
    final paperIdCtrl = TextEditingController();
    bool isDialogLoading = false;
    List<Map<String, dynamic>> papers = [];
    bool initialLoad = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (initialLoad) {
            AppData().fetchPapersForCourse(courseId).then((val) {
              setDialogState(() {
                papers = val;
                initialLoad = false;
              });
            });
          }

          Future<void> _addNewPaper() async {
            final pName = paperNameCtrl.text.trim();
            final pId = paperIdCtrl.text.trim();
            if (pName.isEmpty || pId.isEmpty) return;

            setDialogState(() => isDialogLoading = true);
            final success = await AppData().addPaperToCourse(
              courseId: courseId,
              paperName: pName,
              paperId: pId,
            );
            if (success) {
              final updated = await AppData().fetchPapersForCourse(courseId);
              setDialogState(() {
                papers = updated;
                paperNameCtrl.clear();
                paperIdCtrl.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paper added successfully!')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to add paper. Check database permissions or schema.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
            setDialogState(() => isDialogLoading = false);
          }

          return AlertDialog(
            title: Text('Manage Papers: $courseName'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: paperNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Paper Name',
                            hintText: 'e.g. Fundamental of Marketing',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: paperIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Paper ID',
                            hintText: 'e.g. MKT101',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isDialogLoading ? null : _addNewPaper,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Paper'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C5CE7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Current Papers', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  if (initialLoad)
                    const Center(child: CircularProgressIndicator())
                  else if (papers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No papers added for this course.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        itemCount: papers.length,
                        itemBuilder: (context, idx) {
                          final p = papers[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(p['paper_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('ID: ${p['paper_id']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  await AppData().deletePaper(p['id']);
                                  final updated = await AppData().fetchPapersForCourse(courseId);
                                  setDialogState(() => papers = updated);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }
}

class ManageTeachersView extends StatefulWidget {
  const ManageTeachersView({super.key});

  @override
  State<ManageTeachersView> createState() => _ManageTeachersViewState();
}

class _ManageTeachersViewState extends State<ManageTeachersView> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final list = await AppData().fetchAllTeacherEnrollments();
    setState(() => _teachers = list);
  }

  Future<void> _handleDeleteTeacher(String teacherId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Teacher'),
        content: Text('Are you sure you want to delete "$name" ($teacherId)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AppData().deleteTeacherEnrollment(teacherId);
      _loadTeachers();
    }
  }

  Future<void> _enrollTeacher() async {
    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    if (id.isEmpty || name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await AppData().enrollTeacher(id, name);
      _idController.clear();
      _nameController.clear();
      _loadTeachers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher enrolled successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => AppData().setPage(NavPage.adminDashboard),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Text(
                'Enroll Teachers',
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 24 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 24 : 32),

          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Teacher Enrollment Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isSmall = constraints.maxWidth < 700;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isSmall) ...[
                            _buildTextField(
                              'Teacher ID',
                              _idController,
                              'e.g. TCH001',
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              'Full Name',
                              _nameController,
                              'e.g. Dr. John Doe',
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    'Teacher ID',
                                    _idController,
                                    'e.g. TCH001',
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildTextField(
                                    'Full Name',
                                    _nameController,
                                    'e.g. Dr. John Doe',
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: isSmall ? double.infinity : 200,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _enrollTeacher,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Enroll Teacher'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 48),
          const Center(
            child: Text(
              'Enrolled Teachers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: screenWidth < 800 ? screenWidth - 32 : 800,
                  ),
                  child: DataTable(
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    columns: const [
                      DataColumn(label: Text('Teacher ID')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Program')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _teachers.map((t) {
                      final List<dynamic> programs = t['assigned_courses'] ?? [];
                      return DataRow(
                        cells: [
                          DataCell(Text(t['teacher_id']?.toString() ?? '-')),
                          DataCell(Text(t['teacher_name']?.toString() ?? '-')),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                programs.isEmpty ? 'None' : programs.join(', '),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: programs.isEmpty ? Colors.grey : Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _showAssignProgramDialog(t),
                                  icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF6C5CE7)),
                                  tooltip: 'Assign Programs',
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final teacherId = t['teacher_id']?.toString() ?? '';
                                    final name = t['teacher_name']?.toString() ?? '';
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Teacher'),
                                        content: Text(
                                          'Are you sure you want to delete "$name" ($teacherId)?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await AppData().deleteTeacherEnrollment(teacherId);
                                      _loadTeachers();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete Teacher',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  void _showAssignProgramDialog(Map<String, dynamic> teacher) {
    List<String> currentSelected = List<String>.from(teacher['assigned_courses'] ?? []);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Assign Programs: ${teacher['teacher_name']}'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the courses this teacher will handle. Each course can only be handled by one teacher.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: AppData().predefinedCourses.length,
                      itemBuilder: (context, index) {
                        final course = AppData().predefinedCourses[index];
                        final name = course['name'].toString();
                        final isAlreadySelected = currentSelected.contains(name);
                        final isTakenByOther = AppData().isCourseAssignedToOther(
                          name,
                          teacher['teacher_id']?.toString() ?? '',
                          _teachers,
                        );

                        return CheckboxListTile(
                          title: Text(name),
                          subtitle: isTakenByOther
                              ? const Text('Already assigned to another teacher',
                                  style: TextStyle(color: Colors.red, fontSize: 11))
                              : null,
                          value: isAlreadySelected,
                          activeColor: const Color(0xFF6C5CE7),
                          onChanged: isTakenByOther
                              ? null
                              : (bool? val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      currentSelected.add(name);
                                    } else {
                                      currentSelected.remove(name);
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        final res = await AppData().updateTeacherPrograms(
                          teacher['teacher_id']?.toString() ?? '',
                          currentSelected,
                        );
                        if (res) {
                          await _loadTeachers();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Programs updated successfully!')),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update programs. Please try again.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                        setDialogState(() => isSaving = false);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white),
                child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ManageStudentsView extends StatefulWidget {
  const ManageStudentsView({super.key});

  @override
  State<ManageStudentsView> createState() => _ManageStudentsViewState();
}

class _ManageStudentsViewState extends State<ManageStudentsView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String? _selectedDept;
  String? _selectedYear;
  String? _selectedSem;
  bool _isAdding = false;
  bool _isLoadingData = false;
  int _registryPage = 0;
  int _trackingPage = 0;
  final int _pageSize = 10;

  final List<String> _departments = [
    'Marketing',
    'Finance',
    'International Business',
    'Human Resource Management',
    'General',
    'Hospital Management',
    'Tourism',
    'Operations & Supply Chain Management',
  ];

  final List<String> _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (AppData().registeredStudents.isNotEmpty && AppData().internalStudents.isNotEmpty) {
      // Data already here, fetch in background without blocking
      Future.wait([
        AppData().fetchRegisteredStudents(),
        AppData().fetchInternalStudents(),
      ]);
      return;
    }

    setState(() => _isLoadingData = true);
    await Future.wait([
      AppData().fetchRegisteredStudents(),
      AppData().fetchInternalStudents(),
    ]);
    if (mounted) setState(() => _isLoadingData = false);
  }

  Future<void> _handleAddStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDept == null || _selectedYear == null || _selectedSem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all dropdown fields')),
      );
      return;
    }

    setState(() => _isAdding = true);
    try {
      await AppData().addInternalStudent(
        enrollNo: _idController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        dob: _dobController.text.trim(),
        department: _selectedDept!,
        year: _selectedYear!,
        semester: _selectedSem!,
      );

      _idController.clear();
      _nameController.clear();
      _phoneController.clear();
      _dobController.clear();
      _selectedDept = null;
      _selectedYear = null;
      _selectedSem = null;

      await _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added to library successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding student: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => AppData().setPage(NavPage.adminDashboard),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppData().currentPage == NavPage.studentDetails
                          ? 'Student Details'
                          : 'Manage Students',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (AppData().currentPage != NavPage.studentDetails)
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Import Student'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7).withAlpha(30),
                      foregroundColor: const Color(0xFF6C5CE7),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // ADD STUDENT SECTION
            if (AppData().currentPage != NavPage.studentDetails) ...[
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add New Student to Library',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.library_add_rounded, color: Color(0xFF6C5CE7), size: 20),
                        ],
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          bool isSmall = constraints.maxWidth < 600;
                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildInput(
                                      'Enrollment No',
                                      _idController,
                                      '012345',
                                      keyboardType: TextInputType.number,
                                      formatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildInput('Full Name', _nameController, 'Suriya')),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildInput(
                                      'Phone Number',
                                      _phoneController,
                                      '9876543210',
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      formatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _pickDob,
                                      child: AbsorbPointer(
                                        child: _buildInput('DOB', _dobController, 'YYYY-MM-DD'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDropDownSmall('Dept', _selectedDept, _departments, (v) {
                                      setState(() => _selectedDept = v);
                                    }),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDropDownSmall('Year', _selectedYear, _years, (v) {
                                      setState(() => _selectedYear = v);
                                    }),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDropDownSmall('Sem', _selectedSem, List.generate(8, (i) => (i + 1).toString()), (v) {
                                      setState(() => _selectedSem = v);
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isAdding ? null : _handleAddStudent,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C5CE7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: _isAdding
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Add Student Details', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // NEW REGISTRY LIST
              Text(
                'Internal Student Registry',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _isLoadingData
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      children: [
                        _buildInternalRegistryTable(isMobile),
                        const SizedBox(height: 16),
                        _buildPaginationControls(
                          currentPage: _registryPage,
                          totalItems: AppData().internalStudents.length,
                          onPageChanged: (p) => setState(() => _registryPage = p),
                        ),
                      ],
                    ),
              const SizedBox(height: 48),
            ],

            if (AppData().currentPage == NavPage.studentDetails) ...[
              Text(
                'Enrolled Student Tracking',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _isLoadingData
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      children: [
                        _buildTrackingList(isMobile),
                        const SizedBox(height: 16),
                        _buildPaginationControls(
                          currentPage: _trackingPage,
                          totalItems: AppData().registeredStudents.length,
                          onPageChanged: (p) => setState(() => _trackingPage = p),
                        ),
                      ],
                    ),
              const SizedBox(height: 48),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isBlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBlocked ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isBlocked ? 'Blocked' : 'Active',
        style: TextStyle(
          color: isBlocked ? Colors.red.shade700 : Colors.green.shade700,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBlockToggle(
    String enrollNo,
    bool isBlocked,
    dynamic name,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBlocked ? 'Unblock Student' : 'Block Student'),
        content: Text(
          'Are you sure you want to ${isBlocked ? "unblock" : "block"} $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isBlocked ? 'Unblock' : 'Block',
              style: TextStyle(color: isBlocked ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AppData().toggleStudentBlock(enrollNo, !isBlocked);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Manual Import Entry'),
        content: const Text('Please use the quick-entry form at the top of the student management page for manual imports.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingList(bool isMobile) {
    final allStudents = AppData().registeredStudents;
    final startIndex = _trackingPage * _pageSize;
    final students = allStudents.skip(startIndex).take(_pageSize).toList();

    if (isMobile) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: AppData().registeredStudents.length,
        itemBuilder: (context, index) {
          final s = AppData().registeredStudents[index];
          bool isBlocked = s['is_blocked'] == true;
          String enrollNo =
              s['enrollno']?.toString() ?? s['Enrollment No']?.toString() ?? '-';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s['name']?.toString() ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      _buildStatusBadge(isBlocked),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Enroll No', enrollNo),
                  _buildDetailRow(
                    'Dept',
                    s['department']?.toString() ?? '-',
                  ),
                  _buildDetailRow(
                    'Year/Sem',
                    '${s['year']} / ${s['semester']}',
                  ),
                  const Divider(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _handleBlockToggle(enrollNo, isBlocked, s['name']),
                      icon: Icon(
                        isBlocked
                            ? Icons.lock_open_rounded
                            : Icons.lock_person_rounded,
                        size: 18,
                      ),
                      label: Text(isBlocked ? 'Unblock' : 'Block User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBlocked ? Colors.green : Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DataTable(
            columnSpacing: 20,
            headingRowColor: WidgetStateProperty.all(
              Colors.grey.shade50,
            ),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            columns: const [
              DataColumn(label: Text('Enrollment No')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Dept')),
              DataColumn(label: Text('Year')),
              DataColumn(label: Text('Sem')),
              DataColumn(label: Text('Account Status')),
            ],
            rows: AppData().registeredStudents.map((s) {
              bool isBlocked = s['is_blocked'] == true;
              String enrollNo =
                  s['enrollno']?.toString() ?? s['Enrollment No']?.toString() ?? '-';
              return DataRow(
                cells: [
                  DataCell(Text(enrollNo)),
                  DataCell(Text(s['name']?.toString() ?? '-')),
                  DataCell(Text(s['department']?.toString() ?? '-')),
                  DataCell(Text(s['year']?.toString() ?? '-')),
                  DataCell(Text(s['semester']?.toString() ?? '-')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusBadge(isBlocked),
                        const SizedBox(width: 8),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              _handleBlockToggle(enrollNo, isBlocked, s['name']),
                          icon: Icon(
                            isBlocked
                                ? Icons.lock_open_rounded
                                : Icons.lock_person_rounded,
                            color: isBlocked ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          tooltip: isBlocked ? 'Unblock student' : 'Block student',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    }
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? formatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: formatters,
          validator: (v) {
            if (v!.isEmpty) return 'Required';
            if (maxLength != null && v.length != maxLength) {
              return 'Must be $maxLength digits';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade50,
            counterText: "", // Hide the char counter for cleaner look
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropDownSmall(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildInternalRegistryTable(bool isMobile) {
    final allStudents = AppData().internalStudents;
    final startIndex = _registryPage * _pageSize;
    final students = allStudents.skip(startIndex).take(_pageSize).toList();

    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(child: Text('No students in registry yet.', style: TextStyle(color: Colors.grey))),
      );
    }

    if (isMobile) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final s = students[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s['name'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('ID: ${s['Enrollment No']}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildMobileField(Icons.phone_android_rounded, 'Phone', s['phone']),
                  _buildMobileField(Icons.business_rounded, 'Dept', s['department']),
                  _buildMobileField(Icons.calendar_month_rounded, 'DOB', s['dob']),
                  Row(
                    children: [
                      Expanded(child: _buildMobileField(Icons.history_edu_rounded, 'Year', s['year'])),
                      Expanded(child: _buildMobileField(Icons.school_rounded, 'Sem', s['semester'])),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
            columnSpacing: 32,
            horizontalMargin: 20,
            columns: const [
              DataColumn(label: Text('Enrollment No')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('DOB')),
              DataColumn(label: Text('Dept')),
              DataColumn(label: Text('Year')),
              DataColumn(label: Text('Sem')),
            ],
            rows: students.map((s) => DataRow(cells: [
              DataCell(Text(s['Enrollment No']?.toString() ?? '-')),
              DataCell(Text(s['name']?.toString() ?? '-')),
              DataCell(Text(s['phone']?.toString() ?? '-')),
              DataCell(Text(s['dob']?.toString() ?? '-')),
              DataCell(Text(s['department']?.toString() ?? '-')),
              DataCell(Text(s['year']?.toString() ?? '-')),
              DataCell(Text(s['semester']?.toString() ?? '-')),
            ])).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalItems,
    required Function(int) onPageChanged,
  }) {
    final totalPages = (totalItems / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withAlpha(10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Page ${currentPage + 1} of $totalPages',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C5CE7),
            ),
          ),
        ),
        IconButton(
          onPressed:
              currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildMobileField(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6C5CE7)),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text(value?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}