import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'main.dart';

// ---------------------------------------------------------
// Login Screen
// ---------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _studentName;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _idController.addListener(_onIdChanged);
  }

  @override
  void dispose() {
    _idController.removeListener(_onIdChanged);
    _idController.dispose();
    _passController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onIdChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final id = _idController.text.trim();
      if (id.length < 3) {
        if (mounted) setState(() => _studentName = null);
        return;
      }
      
      final name = await AppData().fetchUserName(id);
      if (mounted) {
        setState(() => _studentName = name);
      }
    });
  }

  void _handleLogin() async {
    final id = _idController.text.trim();
    final pass = _passController.text.trim();

    if (id.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all credentials')),
      );
      return;
    }

    AppData().loginErrorMessage = null; 
    bool success = await AppData().loginStudent(id, pass);
    
    if (!success) {
      // If not a student, try as a teacher
      success = await AppData().loginTeacher(id, pass);
    }

    if (!success) {
      // If not a teacher, try as an admin
      success = await AppData().loginAdmin(id, pass);
    }

    if (success) {
      if (!mounted) return;
      // The PTU_PORTALApp in main.dart handles the routing automatically via AnimatedBuilder
      // We don't need to push manually here.
    } else {
      String msg = AppData().loginErrorMessage ?? 'Invalid credentials or user not found';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left Side - Info/Branding
          Expanded(
            child: Container(
              color: const Color(0xFF6C5CE7).withAlpha(10),
              padding: const EdgeInsets.all(60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'PTU PORTAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The ultimate academic management system for modern education.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildBullet('Role-based access control'),
                  _buildBullet('Real-time assignment tracking'),
                  _buildBullet('Instant MCQ results & analytics'),
                ],
              ),
            ),
          ),
          // Right Side - Login Form
          Container(
            width: 500,
            padding: const EdgeInsets.all(60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome Back',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please enter your details to sign in.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 40),
                // Input Fields
                _buildLabel('User ID / Enrollment Number'),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    hintText: 'Enter User ID',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_studentName != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Welcome, $_studentName',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF6C5CE7),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildLabel('Password'),
                TextField(
                  controller: _passController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed:
                          () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showForgotPasswordDialog(),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF6C5CE7), size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Student Registration Screen
// ---------------------------------------------------------
class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Dropdown selections
  String? _selectedDepartment;
  String? _selectedYear;
  String? _selectedSemester;
  DateTime? _selectedDob;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: AppData().loggedName);
    _phoneController = TextEditingController(text: AppData().loggedPhone);
    _selectedDepartment = AppData().loggedDepartment;
    _selectedYear = AppData().loggedYear;
    _selectedSemester = AppData().loggedSemester;
    
    if (AppData().loggedDob != null) {
      _selectedDob = DateTime.tryParse(AppData().loggedDob!);
    }
  }

  // Options
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

  final Map<String, List<String>> _semestersByYear = {
    '1st Year': ['1', '2'],
    '2nd Year': ['3', '4'],
    '3rd Year': ['5', '6'],
    '4th Year': ['7', '8'],
  };



  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year - 15),
      helpText: 'Select Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6C5CE7)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDob = picked);
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your Date of Birth')),
        );
        return;
      }
      if (_passController.text != _confirmPassController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }
      setState(() => _isLoading = true);
      final dob =
          '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}';

      String? errorMessage = await AppData().registerStudentDetails(
        enrollNo: AppData().loggedEnrollNo ?? '',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        dob: dob,
        department: _selectedDepartment ?? '',
        year: _selectedYear ?? '',
        semester: _selectedSemester ?? '',
        password: _passController.text.trim(),
      );
      setState(() => _isLoading = false);

      if (errorMessage != null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $errorMessage'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> semOptions =
        _selectedYear != null ? (_semestersByYear[_selectedYear!] ?? []) : [];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Color(0xFF6C5CE7),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Complete Registration',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome, ${AppData().loggedName ?? 'Student'}! Please fill in your details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),

                  // Enrollment No (readonly)
                  _buildRegLabel('Enrollment No'),
                  TextFormField(
                    initialValue: AppData().loggedEnrollNo,
                    enabled: false,
                    decoration: _inputDeco(Icons.assignment_ind),
                  ),
                  const SizedBox(height: 16),

                  // Full Name
                  _buildRegLabel('Full Name'),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDeco(Icons.person_outline),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  _buildRegLabel('Phone Number'),
                  TextFormField(
                    controller: _phoneController,
                    enabled: false,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: _inputDeco(
                      Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),



                  // Date of Birth
                  _buildRegLabel('Date of Birth'),
                  AbsorbPointer(
                    absorbing: true,
                    child: TextFormField(
                      readOnly: true,
                      enabled: false,
                      decoration: _inputDeco(
                        Icons.calendar_today_outlined,
                      ).copyWith(
                        hintText:
                            _selectedDob != null
                                ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
                                : '-',
                      ),
                      controller: TextEditingController(
                        text:
                            _selectedDob != null
                                ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
                                : '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Department
                  _buildRegLabel('Department'),
                  TextFormField(
                    initialValue: _selectedDepartment ?? '-',
                    enabled: false,
                    decoration: _inputDeco(Icons.account_balance_outlined),
                  ),
                  const SizedBox(height: 16),

                  // Year + Semester (side by side)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRegLabel('Year'),
                            TextFormField(
                              initialValue: _selectedYear ?? '-',
                              enabled: false,
                              decoration: _inputDeco(Icons.school_outlined),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRegLabel('Semester'),
                            TextFormField(
                              initialValue: _selectedSemester != null
                                  ? 'Semester $_selectedSemester'
                                  : '-',
                              enabled: false,
                              decoration: _inputDeco(Icons.book_outlined),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),



                  // Password
                  _buildRegLabel('Create New Password'),
                  TextFormField(
                    controller: _passController,
                    obscureText: !_isPasswordVisible,
                    decoration: _inputDeco(Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v!.length < 6) return 'Minimum 6 characters';
                      if (v == 'ptu@123') {
                        return 'Default password not allowed. Please choose a different one.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  _buildRegLabel('Confirm Password'),
                  TextFormField(
                    controller: _confirmPassController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: _inputDeco(Icons.lock_clock_outlined).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v != _passController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Finalize Registration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => AppData().logout(),
                    child: const Text('Cancel & Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  InputDecoration _inputDeco(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      counterText: '',
    );
  }
}

// ---------------------------------------------------------
// Teacher Registration Screen
// ---------------------------------------------------------
class TeacherRegistrationScreen extends StatefulWidget {
  const TeacherRegistrationScreen({super.key});

  @override
  State<TeacherRegistrationScreen> createState() =>
      _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends State<TeacherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController(
    text: AppData().loggedName,
  );
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  String? _selectedDepartment;
  String? _selectedDesignation;
  String? _selectedYear;
  String? _selectedSemester;

  final List<String> _designations = [
    'Assistant Professor',
    'Associate Professor',
    'Professor',
    'Head of Department',
    'Lab Assistant',
  ];

  final List<String> _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  final List<String> _semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      String? errorMessage = await AppData().registerTeacherDetails(
        teacherId: AppData().loggedTeacherId ?? '',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        department: _selectedDepartment ?? '',
        designation: _selectedDesignation ?? '',
        year: _selectedYear ?? '',
        semester: _selectedSemester ?? '',
        password: _passController.text.trim(),
      );
      setState(() => _isLoading = false);

      if (errorMessage != null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $errorMessage')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.amber.shade800,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Teacher Registration',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome, ${AppData().loggedName ?? 'Teacher'}! Please complete your profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),

                  _buildRegLabel('Teacher ID'),
                  TextFormField(
                    initialValue: AppData().loggedTeacherId,
                    enabled: false,
                    decoration: _inputDecoIcon(Icons.badge_outlined),
                  ),
                  const SizedBox(height: 16),

                  _buildRegLabel('Full Name'),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoIcon(Icons.person_outline),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),



                  _buildRegLabel('Phone Number'),
                  TextFormField(
                    controller: _phoneController,
                    maxLength: 10,
                    decoration: _inputDecoIcon(Icons.phone_outlined),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildRegLabel('Department'),
                  DropdownButtonFormField<String>(
                    value: _selectedDepartment,
                    decoration: _inputDecoIcon(Icons.account_balance_outlined),
                    items: AppData().predefinedCourses
                        .map((course) => DropdownMenuItem(
                            value: course['name'].toString(),
                            child: Text(course['name'].toString())))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDepartment = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildRegLabel('Designation'),
                  DropdownButtonFormField<String>(
                    value: _selectedDesignation,
                    decoration: _inputDecoIcon(Icons.work_outline),
                    items: _designations
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDesignation = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRegLabel('Academic Year'),
                            DropdownButtonFormField<String>(
                              value: _selectedYear,
                              decoration: _inputDecoIcon(Icons.calendar_month),
                              items: _years
                                  .map((y) => DropdownMenuItem(
                                      value: y, child: Text(y)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedYear = v;
                                  // Reset semester if it's not valid for the new year
                                  final semsMap = {
                                    '1st Year': ['1', '2'],
                                    '2nd Year': ['3', '4'],
                                    '3rd Year': ['5', '6'],
                                    '4th Year': ['7', '8']
                                  };
                                  final validSems = semsMap[v] ?? _semesters;
                                  if (!validSems.contains(_selectedSemester)) {
                                    _selectedSemester = validSems.first;
                                  }
                                });
                              },
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRegLabel('Semester'),
                            DropdownButtonFormField<String>(
                              value: _selectedSemester,
                              decoration: _inputDecoIcon(Icons.book),
                              items: (() {
                                final semsMap = {
                                  '1st Year': ['1', '2'],
                                  '2nd Year': ['3', '4'],
                                  '3rd Year': ['5', '6'],
                                  '4th Year': ['7', '8']
                                };
                                return (semsMap[_selectedYear] ?? _semesters)
                                    .map((s) => DropdownMenuItem(
                                        value: s, child: Text('Sem $s')))
                                    .toList();
                              })(),
                              onChanged: (v) =>
                                  setState(() => _selectedSemester = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildRegLabel('Create Password'),
                  TextFormField(
                    controller: _passController,
                    obscureText: !_isPasswordVisible,
                    decoration: _inputDecoIcon(Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (v) {
                      if (v!.length < 6) return 'Min 6 chars';
                      if (v == 'ptu@123') {
                        return 'Default password not allowed. Please choose a different one.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Registration',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => AppData().logout(),
                    child: const Text('Cancel & Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 4),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  InputDecoration _inputDecoIcon(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      counterText: '',
    );
  }
}

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isVerified = false;
  bool _isLoading = false;
  Map<String, dynamic>? _accountToken;

  Future<void> _handleVerify() async {
    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();

    if (id.isEmpty || name.isEmpty || dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all verification details')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await AppData().verifyUserIdentity(id, name, dob);
    setState(() => _isLoading = false);

    if (result != null) {
      setState(() {
        _isVerified = true;
        _accountToken = result;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identity verification failed. Please check your details.')),
      );
    }
  }

  Future<void> _handleReset() async {
    final pass = _newPassController.text.trim();
    final confirm = _confirmPassController.text.trim();

    if (pass.isEmpty || confirm.isEmpty) return;
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await AppData().updateUserPassword(
      _idController.text.trim(),
      _accountToken!['table'],
      _accountToken!['id_col'],
      pass,
    );
    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully! Please log in.')),
        );
      }
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1980),
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
    return AlertDialog(
      title: Text(
        _isVerified ? 'Reset Password' : 'Verify Identity',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isVerified) ...[
                const Text('Enter your details as provided during registration to verify your identity.'),
                const SizedBox(height: 16),
                _buildField('Enrollment No / ID', _idController, Icons.badge_outlined),
                const SizedBox(height: 12),
                _buildField('Full Name', _nameController, Icons.person_outline),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickDob,
                  child: AbsorbPointer(
                    child: _buildField('Date of Birth', _dobController, Icons.calendar_today_outlined),
                  ),
                ),
              ] else ...[
                const Text('Verification successful. Please enter a new password.'),
                const SizedBox(height: 16),
                _buildField('New Password', _newPassController, Icons.lock_outline, obscure: true),
                const SizedBox(height: 12),
                _buildField('Confirm Password', _confirmPassController, Icons.lock_reset_rounded, obscure: true),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : (_isVerified ? _handleReset : _handleVerify),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isVerified ? 'Reset Password' : 'Verify Identity'),
        ),
      ],
    );
  }

  Widget _buildField(String hint, TextEditingController controller, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}