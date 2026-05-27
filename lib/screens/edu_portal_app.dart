import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth.dart';

import 'package:ptu/models/app_data.dart';
import 'package:ptu/screens/main_layout_screen.dart';
class EduPortalApp extends StatelessWidget {
  const EduPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData(),
      builder: (context, _) {
        return MaterialApp(
          title: 'PTU',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C5CE7),
              primary: const Color(0xFF6C5CE7),
              surface: const Color(0xFFF8F9FE),
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.plusJakartaSansTextTheme(
              Theme.of(context).textTheme,
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F6FB),
          ),
          home: AppData().isLoggedIn
              ? const MainLayoutScreen()
              : (AppData().isRegistrationPending
                    ? (AppData().currentUserRole == UserRole.teacher
                          ? const TeacherRegistrationScreen()
                          : const StudentRegistrationScreen())
                    : const LoginScreen()),
        );
      },
    );
  }
}
