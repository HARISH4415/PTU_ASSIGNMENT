import 'package:flutter/material.dart';
import '../admin_views.dart';

import 'package:ptu/models/app_data.dart';
import 'package:ptu/screens/mcq_central_view.dart';
import 'package:ptu/screens/profile_view.dart';
import 'package:ptu/screens/dashboard_view.dart';
import 'package:ptu/screens/courses_view.dart';
import 'package:ptu/screens/live_class_view.dart';
import 'package:ptu/screens/assignments_view.dart';
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
