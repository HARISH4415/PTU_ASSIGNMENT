import 'package:flutter/material.dart';
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
            ],
          ],
        ),
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
                          course,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Course'),
                              content: Text(
                                'Are you sure you want to delete "$course"?',
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
                            await AppData().deleteCourseMaster(course);
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
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _teachers.map((t) {
                      return DataRow(
                        cells: [
                          DataCell(Text(t['teacher_id']?.toString() ?? '-')),
                          DataCell(Text(t['teacher_name']?.toString() ?? '-')),
                          DataCell(
                            IconButton(
                              onPressed: () async {
                                final teacherId =
                                    t['teacher_id']?.toString() ?? '';
                                final name =
                                    t['teacher_name']?.toString() ?? '';
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Teacher'),
                                    content: Text(
                                      'Are you sure you want to delete "$name" ($teacherId)?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await AppData().deleteTeacherEnrollment(
                                    teacherId,
                                  );
                                  _loadTeachers();
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Delete Teacher',
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
}

class ManageStudentsView extends StatefulWidget {
  const ManageStudentsView({super.key});

  @override
  State<ManageStudentsView> createState() => _ManageStudentsViewState();
}

class _ManageStudentsViewState extends State<ManageStudentsView> {
  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    await AppData().fetchRegisteredStudents();
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
              children: [
                IconButton(
                  onPressed: () => AppData().setPage(NavPage.adminDashboard),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Text(
                  'Manage Students',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 24 : 32),
            if (isMobile)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppData().registeredStudents.length,
                itemBuilder: (context, index) {
                  final s = AppData().registeredStudents[index];
                  bool isBlocked = s['is_blocked'] == true;
                  String enrollNo =
                      s['enrollno']?.toString() ??
                      s['Enrollment No']?.toString() ??
                      '-';
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
                              onPressed: () => _handleBlockToggle(
                                enrollNo,
                                isBlocked,
                                s['name'],
                              ),
                              icon: Icon(
                                isBlocked
                                    ? Icons.lock_open_rounded
                                    : Icons.lock_person_rounded,
                                size: 18,
                              ),
                              label: Text(isBlocked ? 'Unblock' : 'Block User'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isBlocked
                                    ? Colors.green
                                    : Colors.red,
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
              )
            else
              Container(
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
                          s['enrollno']?.toString() ??
                          s['Enrollment No']?.toString() ??
                          '-';
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
                                  onPressed: () => _handleBlockToggle(
                                    enrollNo,
                                    isBlocked,
                                    s['name'],
                                  ),
                                  icon: Icon(
                                    isBlocked
                                        ? Icons.lock_open_rounded
                                        : Icons.lock_person_rounded,
                                    color: isBlocked
                                        ? Colors.green
                                        : Colors.red,
                                    size: 18,
                                  ),
                                  tooltip: isBlocked
                                      ? 'Unblock student'
                                      : 'Block student',
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
}
