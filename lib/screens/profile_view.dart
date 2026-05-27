import 'dart:async';
import 'package:flutter/material.dart';
import '../auth.dart';

import 'package:ptu/models/app_data.dart';
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}
class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    // Refresh user data from database when profile page is opened
    Future.microtask(() => AppData().refreshCurrentUserData());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData(),
      builder: (context, _) {
        final role = AppData().currentUserRole;
        final isTeacher = role == UserRole.teacher;
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(context, isTeacher, isMobile),
              const SizedBox(height: 32),
              isMobile
                  ? Column(
                      children: [
                        _buildPersonalAndAcademicInfo(isTeacher),
                        const SizedBox(height: 24),
                        _buildAccountStatusCard(),
                        const SizedBox(height: 24),
                        _buildQuickActionsCard(context),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildPersonalAndAcademicInfo(isTeacher),
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
      },
    );
  }

  Widget _buildPersonalAndAcademicInfo(bool isTeacher) {
    final isAdmin = AppData().currentUserRole == UserRole.admin;
    return Column(
      children: [
        _buildInfoCard('Personal Information', Icons.person_outline, [
          _buildInfoRow('Full Name', AppData().loggedName ?? 'N/A'),
          if (!isAdmin) ...[
            if (isTeacher &&
                AppData().loggedEmail != null &&
                AppData().loggedEmail!.isNotEmpty)
              _buildInfoRow('Email Address', AppData().loggedEmail!),
            _buildInfoRow('Phone Number', AppData().loggedPhone ?? 'N/A'),
            if (!isTeacher)
              _buildInfoRow(
                'Registration No',
                AppData().loggedEnrollNo ?? 'N/A',
              ),
            if (isTeacher)
              _buildInfoRow('Teacher ID', AppData().loggedTeacherId ?? 'N/A'),
          ],
        ]),
        if (!isAdmin) ...[
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
      ],
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    bool isTeacher,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 32),
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
      child: isMobile
          ? Column(
              children: [
                _buildAvatar(isTeacher, isMobile),
                const SizedBox(height: 16),
                _buildProfileDetails(isTeacher, isMobile),
                const SizedBox(height: 16),
                _buildEditProfileButton(context, isTeacher, isMobile),
              ],
            )
          : Row(
              children: [
                _buildAvatar(isTeacher, isMobile),
                const SizedBox(width: 32),
                Expanded(child: _buildProfileDetails(isTeacher, isMobile)),
                _buildEditProfileButton(context, isTeacher, isMobile),
              ],
            ),
    );
  }

  Widget _buildAvatar(bool isTeacher, bool isMobile) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: isMobile ? 40 : 60,
            backgroundColor: Colors.white,
            child: Hero(
              tag: 'profile_avatar',
              child: Icon(
                isTeacher ? Icons.person_4 : Icons.face,
                size: isMobile ? 45 : 70,
                color: const Color(0xFF6C5CE7),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDetails(bool isTeacher, bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          AppData().loggedName ?? 'Guest User',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 22 : 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                AppData().currentUserRole == UserRole.admin
                    ? 'Administrator'
                    : (isTeacher ? 'Senior Faculty' : 'Undergraduate Student'),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            if (AppData().currentUserRole != UserRole.admin)
              Text(
                'ID: ${isTeacher ? AppData().loggedTeacherId : AppData().loggedEnrollNo}',
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditProfileButton(
    BuildContext context,
    bool isTeacher,
    bool isMobile,
  ) {
    return SizedBox(
      width: isMobile ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: () => _showEditProfileDialog(context, isTeacher),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Edit Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF6C5CE7),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
