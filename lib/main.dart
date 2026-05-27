import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as ex;
import 'package:csv/csv.dart';

import 'package:ptu/models/app_data.dart';
import 'package:ptu/screens/edu_portal_app.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Replace these with your actual Supabase Project URL and Anon Key
  try {
    await Supabase.initialize(
      url: 'https://wagtgvrfiscusihqgsds.supabase.co',
      anonKey: 'sb_publishable_5w97jQG482KDYVVGlbALAg_HsZxEgHq',
    );
  } catch (e) {
    debugPrint('Supabase init failed. Please update the URL and Anon Key.');
  }

  runApp(const EduPortalApp());
}

final supabase = Supabase.instance.client;

String formatDateTime12h(DateTime? dt) {
  if (dt == null) return '--';
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  return '${dt.year}-$month-$day  $hour:$minute $period';
}

// ---------------------------------------------------------
// Global Mock Database
// ---------------------------------------------------------



// ---------------------------------------------------------
// Main App Shell
// ---------------------------------------------------------

// ---------------------------------------------------------
// Main Layout (Sidebar + Content)
// ---------------------------------------------------------




void openCreateMcqTestDialog(
  BuildContext context, {
  String? paperId,
  VoidCallback? onComplete,
}) {
  String selectedYear = AppData().loggedYear ?? 'All';
  String selectedSem = AppData().loggedSemester ?? 'All';
  String? defaultClassId = AppData().filteredClasses.isNotEmpty
      ? AppData().filteredClasses.first['id']
      : null;

  // Initially one session with current time
  List<Map<String, dynamic>> sessions = [
    {
      'titleCtrl': TextEditingController(),
      'timeCtrl': TextEditingController(text: '30'),
      'randomCtrl': TextEditingController(),
      'isTimed': false,
      'isFlagged': false,
      'start': DateTime.now(),
      'end': DateTime.now().add(const Duration(hours: 3)),
      'mcqData': null,
      'selectedClassId': defaultClassId,
      'label': 'Session 1',
    },
  ];

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          int activeSessions = sessions
              .where((s) => s['mcqData'] != null)
              .length;

          return AlertDialog(
            backgroundColor: const Color(0xFFF8F9FE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configure MCQ Sessions',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        'Set up independent batches for the same test',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  IconButton(
                    onPressed: () => downloadMcqTemplate(context),
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Download Excel Format',
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 1000,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: sessions.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var s = entry.value;
                          return SizedBox(
                            width: 450,
                            child: Stack(
                              children: [
                                buildAdvancedSessionCard(
                                  label: s['label'],
                                  sublabel: 'Batch Session',
                                  icon: idx % 2 == 0
                                      ? Icons.wb_sunny_rounded
                                      : Icons.nights_stay_rounded,
                                  themeColor: idx % 2 == 0
                                      ? const Color(0xFF6C5CE7)
                                      : const Color(0xFFFD79A8),
                                  data: s['mcqData'],
                                  titleCtrl: s['titleCtrl'],
                                  randomCtrl: s['randomCtrl'],
                                  timeCtrl: s['timeCtrl'],
                                  isTimed: s['isTimed'],
                                  isFlagged: s['isFlagged'] ?? false,
                                  start: s['start'],
                                  end: s['end'],
                                  onToggleTimed: () => setDialogState(
                                    () => s['isTimed'] = !s['isTimed'],
                                  ),
                                  onToggleFlagged: () => setDialogState(
                                    () => s['isFlagged'] =
                                        !(s['isFlagged'] ?? false),
                                  ),
                                  onPickFile: () async {
                                    var res = await pickMcqFile(ctx);
                                    if (res != null) {
                                      setDialogState(() {
                                        s['mcqData'] = res;
                                      });
                                    }
                                  },
                                  onPickTime: (isStart) async {
                                    var dt = await pickDateTime(
                                      ctx,
                                      isStart ? s['start'] : s['end'],
                                    );
                                    if (dt != null) {
                                      setDialogState(
                                        () => isStart
                                            ? s['start'] = dt
                                            : s['end'] = dt,
                                      );
                                    }
                                  },
                                  selectedCourse: s['selectedClassId'],
                                  onCourseChanged: (val) => setDialogState(
                                    () => s['selectedClassId'] = val,
                                  ),
                                  context: ctx,
                                ),
                                if (sessions.length > 1)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => setDialogState(
                                        () => sessions.removeAt(idx),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            // Inherit from last session
                            var last = sessions.last;
                            sessions.add({
                              'titleCtrl': TextEditingController(), // Must be NEW
                              'timeCtrl': TextEditingController(text: last['timeCtrl'].text), // Inherit
                              'randomCtrl': TextEditingController(text: last['randomCtrl'].text), // Inherit
                              'isTimed': last['isTimed'], // Inherit
                              'isFlagged': last['isFlagged'], // Inherit
                              'start': last['start'], // Inherit
                              'end': last['end'], // Inherit
                              'mcqData': null, // Must be NEW
                              'selectedClassId': last['selectedClassId'], // Inherit
                              'label': 'Session ${sessions.length + 1}',
                            });
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Session Batch'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          side: const BorderSide(color: Color(0xFF6C5CE7)),
                          foregroundColor: const Color(0xFF6C5CE7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withAlpha(30)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade400,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Sessions marked as "Active" will be published as separate tests. Ensure document is uploaded for each batch you want to activate.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (activeSessions > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7).withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$activeSessions Active Session(s)',
                                  style: const TextStyle(
                                    color: Color(0xFF6C5CE7),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel Task',
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  // Strict Validation: Every session must be complete
                  for (var s in sessions) {
                    if (s['selectedClassId'] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a course for ${s['label']}')),
                      );
                      return;
                    }
                    if (s['titleCtrl'].text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Display Title required for ${s['label']}')),
                      );
                      return;
                    }
                    if (s['mcqData'] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please upload MCQ data for ${s['label']}')),
                      );
                      return;
                    }
                  }

                  for (var s in sessions) {
                    if (s['mcqData'] != null) {
                      await AppData().addAssignment(
                        s['selectedClassId'],
                        s['titleCtrl'].text,
                        s['end'].toString().substring(0, 16),
                        paperId: paperId, // Pass paperId
                        year: selectedYear,
                        semester: selectedSem,
                        mcqData: s['mcqData'],
                        timePerQuestion: s['isTimed']
                            ? (int.tryParse(s['timeCtrl'].text) ?? 30)
                            : 0,
                        questionsToShow: int.tryParse(s['randomCtrl'].text),
                        startDateTime: s['start'],
                        dueDateTime: s['end'],
                        isFlagged: s['isFlagged'] ?? false,
                      );
                    }
                  }

                  Navigator.pop(ctx);
                  onComplete?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF6C5CE7).withAlpha(100),
                ),
                child: Text(
                  'Deploy Test Sessions',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget buildAdvancedSessionCard({
  required String label,
  required String sublabel,
  required IconData icon,
  required Color themeColor,
  required List<dynamic>? data,
  required TextEditingController titleCtrl,
  required TextEditingController randomCtrl,
  required TextEditingController timeCtrl,
  required bool isTimed,
  required bool isFlagged,
  required DateTime start,
  required DateTime end,
  required VoidCallback onToggleTimed,
  required VoidCallback onToggleFlagged,
  required VoidCallback onPickFile,
  required Function(bool) onPickTime,
  String? selectedCourse,
  required Function(String?) onCourseChanged,
  required BuildContext context,
}) {
  bool isActive = data != null;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: isActive
              ? themeColor.withAlpha(20)
              : Colors.black.withAlpha(10),
          blurRadius: 30,
          offset: const Offset(0, 15),
        ),
      ],
      border: Border.all(
        color: isActive ? themeColor.withAlpha(80) : Colors.grey.withAlpha(30),
        width: isActive ? 2 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? themeColor.withAlpha(30)
                    : Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isActive ? themeColor : Colors.grey),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isActive ? themeColor : Colors.grey.shade800,
                  ),
                ),
                Text(
                  sublabel,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            if (isActive)
              const Icon(Icons.check_circle, color: Colors.green, size: 24)
            else
              Icon(
                Icons.circle_outlined,
                color: Colors.grey.withAlpha(50),
                size: 24,
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'BATCH CONFIGURATION',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedCourse,
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black),
          decoration: InputDecoration(
            labelText: 'Target Course',
            prefixIcon: const Icon(Icons.class_outlined),
            filled: true,
            fillColor: const Color(0xFFF8F9FE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          isExpanded: true,
          hint: const Text('Select handled course'),
          items: AppData().filteredClasses.map((cls) {
            return DropdownMenuItem<String>(
              value: cls['id'],
              child: Text(cls['title'], overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onCourseChanged,
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleCtrl,
          style: GoogleFonts.outfit(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Display Title',
            hintText: 'Enter session name',
            prefixIcon: const Icon(Icons.edit_note_rounded),
            filled: true,
            fillColor: const Color(0xFFF8F9FE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: randomCtrl,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Question Pull',
                  hintText: 'All',
                  prefixIcon: const Icon(Icons.shuffle_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: timeCtrl,
                enabled: isTimed,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Sec/Q',
                  prefixIcon: const Icon(Icons.timer_rounded),
                  filled: true,
                  fillColor: isTimed
                      ? const Color(0xFFF8F9FE)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Limited Duration Mode',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          value: isTimed,
          onChanged: (v) => onToggleTimed(),
          activeColor: themeColor,
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Anti-Cheat Flagging',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          value: isFlagged,
          onChanged: (v) => onToggleFlagged(),
          activeColor: Colors.redAccent,
        ),
        const SizedBox(height: 24),
        Text(
          'TIME WINDOW',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: buildModernTimeBox(
                'Starts At',
                formatDateTime12h(start),
                () => onPickTime(true),
                isActive ? themeColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: buildModernTimeBox(
                'Ends At',
                formatDateTime12h(end),
                () => onPickTime(false),
                isActive ? themeColor : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPickFile,
            icon: Icon(
              isActive ? Icons.file_present_rounded : Icons.upload_file_rounded,
            ),
            label: Text(isActive ? 'Document Ready' : 'Choose MCQ Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? themeColor : Colors.grey.shade100,
              foregroundColor: isActive ? Colors.white : Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        if (!isActive)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(
              child: TextButton.icon(
                onPressed: () => downloadMcqTemplate(context),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  'Download Template Format',
                  style: GoogleFonts.outfit(fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget buildModernTimeBox(
  String label,
  String value,
  VoidCallback onTap,
  Color themeColor,
) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  DateTime? date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime(2030),
  );
  if (date != null) {
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null) {
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
  }
  return null;
}

Future<List<dynamic>?> pickMcqFile(BuildContext context) async {
  var res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json', 'xlsx', 'xls', 'csv'],
    withData: true,
  );
  if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
    return null;
  }

  final file = res.files.first;
  final extension = file.extension?.toLowerCase() ?? '';
  final bytes = file.bytes!;

  try {
    if (extension == 'json') {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is List) return data;
      return null;
    }

    if (extension == 'xlsx' || extension == 'xls') {
      var excel = ex.Excel.decodeBytes(bytes);
      List<dynamic> parsedMcq = [];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Robust extraction helper
        String getCellValue(ex.Data? data) {
          if (data == null || data.value == null) return '';
          var v = data.value;
          if (v is ex.TextCellValue) return v.value.toString().trim();
          if (v is ex.IntCellValue) return v.value.toString().trim();
          if (v is ex.DoubleCellValue) return v.value.toString().trim();
          if (v is ex.BoolCellValue) return v.value.toString().trim();
          return v.toString().trim();
        }

        // Search for the data starting point (first row with a question)
        int startRow = 1; // Default skip index 0 header
        for (int i = 0; i < sheet.maxRows && i < 10; i++) {
          if (i >= sheet.rows.length) break;
          String cellA = getCellValue(sheet.rows[i].isNotEmpty ? sheet.rows[i][0] : null).toLowerCase();
          String cellB = getCellValue(sheet.rows[i].length > 1 ? sheet.rows[i][1] : null).toLowerCase();
          if (cellA.contains('qno') || cellB.contains('question')) {
            startRow = i + 1;
            break;
          }
        }

        for (int i = startRow; i < sheet.maxRows; i++) {
          try {
            if (i >= sheet.rows.length) break;
            var row = sheet.rows[i];
            if (row.isEmpty) continue;

            // Question is Column B (index 1)
            String question = getCellValue(row.length > 1 ? row[1] : null);
            if (question.isEmpty) continue;

            // Options are Columns C-F (index 2-5)
            List<String> options = [];
            for (int col = 2; col <= 5; col++) {
              if (row.length > col) {
                String opt = getCellValue(row[col]);
                if (opt.isNotEmpty) options.add(opt);
              }
            }

            // Answer is Column G (index 6)
            String answer = getCellValue(row.length > 6 ? row[6] : null);

            if (options.length >= 2) {
              parsedMcq.add({
                'question': question,
                'options': options,
                'answer': answer,
              });
            }
          } catch (rowErr) {
            debugPrint('Error parsing row $i: $rowErr');
          }
        }
        if (parsedMcq.isNotEmpty) return parsedMcq;
      }
      throw Exception(
        'No valid questions found. Ensure Excel format: QNo, Question, Option A, Option B, Option C, Option D, Correct Answer',
      );
    }

    if (extension == 'csv') {
      final content = utf8.decode(bytes);
      final rows = const CsvToListConverter().convert(content);
      List<dynamic> parsedMcq = [];

      // Start from index 1 (skip header)
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        String question = (row.length > 1) ? row[1]?.toString().trim() ?? '' : '';
        if (question.isEmpty) continue;

        List<String> options = [];
        for (int col = 2; col <= 5; col++) {
          if (row.length > col && row[col] != null) {
            String opt = row[col].toString().trim();
            if (opt.isNotEmpty) options.add(opt);
          }
        }

        String answer = (row.length > 6 && row[6] != null)
            ? row[6].toString().trim()
            : '';

        if (options.length >= 2) {
          parsedMcq.add({
            'question': question,
            'options': options,
            'answer': answer,
          });
        }
      }
      if (parsedMcq.isNotEmpty) return parsedMcq;
      throw Exception(
        'No valid questions found in CSV file. Check format: QNo, Question, Option A, Option B, Option C, Option D, Correct Answer',
      );
    }
  } catch (e) {
    debugPrint('MCQ File Parse Error: $e');
    if (context.mounted) {
      String msg = e.toString().contains('null value')
          ? 'Format Error: Ensure Excel has QNo, Question, 4 Options, and Correct Answer columns.'
          : 'Failed to pick or parse the MCQ file.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }
  return null;
}

Future<void> downloadMcqTemplate(BuildContext context) async {
  try {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['Sheet1'];

    // Header row
    sheet.appendRow([
      ex.TextCellValue('QNo'),
      ex.TextCellValue('Question'),
      ex.TextCellValue('Option A'),
      ex.TextCellValue('Option B'),
      ex.TextCellValue('Option C'),
      ex.TextCellValue('Option D'),
      ex.TextCellValue('Correct Answer (Must match one of the options text)'),
    ]);

    // Sample data row
    sheet.appendRow([
      ex.IntCellValue(1),
      ex.TextCellValue('What is the capital of France?'),
      ex.TextCellValue('London'),
      ex.TextCellValue('Berlin'),
      ex.TextCellValue('Paris'),
      ex.TextCellValue('Madrid'),
      ex.TextCellValue('Paris'),
    ]);

    var fileBytes = excel.encode();
    if (fileBytes != null) {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save MCQ Template',
        fileName: 'mcq_template.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(fileBytes),
      );
      if (outputFile != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved successfully!')),
        );
      }
    }
  } catch (e) {
    debugPrint('Template Download Error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating template: $e')));
    }
  }
}

// ---------------------------------------------------------
// Profile View (Highly detailed and stunning)
// ---------------------------------------------------------


// ---------------------------------------------------------
// Dashboard View (Image-inspired stunning layout)
// ---------------------------------------------------------

// ---------------------------------------------------------
// Courses View
// ---------------------------------------------------------

// ---------------------------------------------------------
// Live Class WebRTC Mock View
// ---------------------------------------------------------


Widget buildControlBtn(
  IconData icon,
  Color bgColor,
  VoidCallback onTap, {
  bool isLarge = false,
  Color iconColor = Colors.white,
  double? size,
}) {
  double containerWidth = isLarge ? 80 : 48;
  double containerHeight = isLarge ? 56 : 48;

  // Scale container if custom size is provided
  if (size != null) {
    containerWidth = isLarge ? size * 3 : size * 2;
    containerHeight = isLarge ? size * 2.2 : size * 2;
  }

  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: containerHeight,
      width: containerWidth,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Icon(icon, color: iconColor, size: size ?? (isLarge ? 28 : 22)),
    ),
  );
}

Widget buildChatMsg(String name, String msg, String time) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(msg, style: const TextStyle(color: Colors.black87, fontSize: 14)),
      ],
    ),
  );
}

// ---------------------------------------------------------
// Assignments Central View
// ---------------------------------------------------------


void openCreateAssignmentDialog(
  BuildContext context,
  String? manualClassId, {
  String? paperId,
  VoidCallback? onComplete,
}) {
  TextEditingController titleCtrl = TextEditingController();
  DateTime startDateTime = DateTime.now();
  DateTime endDateTime = DateTime.now().add(const Duration(days: 7));
  PlatformFile? pickedFile;
  List<dynamic>? mcqData;
  String selectedYear = AppData().loggedYear ?? 'All';
  String selectedSem = AppData().loggedSemester ?? 'All';

  String? currentSelectedClassId =
      manualClassId ??
      (AppData().filteredClasses.isNotEmpty
          ? AppData().filteredClasses.first['id']
          : null);

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Create New Assignment'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: currentSelectedClassId,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Target Course',
                        prefixIcon: Icon(Icons.class_outlined),
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      hint: const Text('Select handled course'),
                      items: AppData().filteredClasses.map((cls) {
                        return DropdownMenuItem<String>(
                          value: cls['id'],
                          child: Text(
                            cls['title'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => currentSelectedClassId = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Assignment Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text(
                        'Start: ${startDateTime.toString().substring(0, 16)}',
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        DateTime? date = await showDatePicker(
                          context: ctx,
                          initialDate: startDateTime,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          TimeOfDay? time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(startDateTime),
                          );
                          if (time != null) {
                            setDialogState(() {
                              startDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text(
                        'End: ${endDateTime.toString().substring(0, 16)}',
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        DateTime? date = await showDatePicker(
                          context: ctx,
                          initialDate: endDateTime,
                          firstDate: startDateTime,
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          TimeOfDay? time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(endDateTime),
                          );
                          if (time != null) {
                            setDialogState(() {
                              endDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        var res = await FilePicker.platform.pickFiles();
                        if (res != null) {
                          setDialogState(() => pickedFile = res.files.first);
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        pickedFile != null
                            ? pickedFile!.name
                            : 'Attach Assignment File',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty &&
                      currentSelectedClassId != null) {
                    AppData().addAssignment(
                      currentSelectedClassId!,
                      titleCtrl.text,
                      endDateTime.toString().substring(0, 16),
                      paperId: paperId, // Pass paperId
                      year: selectedYear,
                      semester: selectedSem,
                      file: pickedFile,
                      mcqData: mcqData,
                      startDateTime: startDateTime,
                      dueDateTime: endDateTime,
                    );
                    Navigator.pop(ctx);
                    if (onComplete != null) onComplete();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upload Assignment'),
              ),
            ],
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------
// Class Details Screen (Stream, Assignments layout)
// ---------------------------------------------------------


// ---------------------------------------------------------
// Assignment Interaction Screen (Upload/Review)
// ---------------------------------------------------------
