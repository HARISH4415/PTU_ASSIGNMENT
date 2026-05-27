import 'package:flutter/material.dart';

import 'package:ptu/models/app_data.dart';
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
