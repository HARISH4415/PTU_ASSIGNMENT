import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ptu/models/app_data.dart';
import '../main.dart';
class LiveClassView extends StatefulWidget {
  const LiveClassView({super.key});

  @override
  State<LiveClassView> createState() => _LiveClassViewState();
}
class _LiveClassViewState extends State<LiveClassView> {
  bool isMicMuted = false;
  bool isVideoOff = true;

  bool isInCall = false;
  bool isChatOpen = true;
  bool isCodeVerified = false;
  final TextEditingController joinCodeCtrl = TextEditingController();
  String? joinErrorMsg;

  String stringIdGenerator() {
    var r = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    return '${String.fromCharCodes(Iterable.generate(3, (_) => chars.codeUnitAt(r.nextInt(chars.length))))}-${String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(r.nextInt(chars.length))))}-${String.fromCharCodes(Iterable.generate(3, (_) => chars.codeUnitAt(r.nextInt(chars.length))))}';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildPreCall() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.all(isMobile ? 24 : 40),
        child: Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Camera Preview Section
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 600,
              ),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off,
                              color: Colors.white54,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Camera module removed",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildControlBtn(
                        isMicMuted ? Icons.mic_off : Icons.mic,
                        isMicMuted ? Colors.red : Colors.grey.shade200,
                        () => setState(() => isMicMuted = !isMicMuted),
                        iconColor: isMicMuted ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 16),
                      buildControlBtn(
                        isVideoOff ? Icons.videocam_off : Icons.videocam,
                        isVideoOff ? Colors.red : Colors.grey.shade200,
                        () => setState(() => isVideoOff = !isVideoOff),
                        iconColor: isVideoOff ? Colors.white : Colors.black87,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isMobile) const SizedBox(width: 80),
            if (isMobile) const SizedBox(height: 48),
            // Join Controls Section
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 400,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: isMobile
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to join?',
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: isMobile ? 32 : 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No one else is here yet',
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  Wrap(
                    alignment: isMobile
                        ? WrapAlignment.center
                        : WrapAlignment.start,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() => isInCall = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Join now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Present',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Other joining options',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.screen_share,
                      color: Color(0xFF6C5CE7),
                      size: 20,
                    ),
                    label: const Text(
                      'Use companion mode',
                      style: TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentThumbnail(int i) {
    if (i == 0 && !isVideoOff) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Icon(Icons.person, color: Colors.white54, size: 48),
            ),
          ),
          const Positioned(
            bottom: 12,
            left: 12,
            child: Text(
              ' You ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isMicMuted)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.mic_off, color: Colors.white, size: 16),
              ),
            ),
        ],
      );
    }

    String label = i == 0 ? "You" : (i == 1 ? "Prof. Alan" : "Student $i");
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor:
                Colors.primaries[i % Colors.primaries.length].shade400,
            child: Text(
              label.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.mic_off, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleMeetHome() {
    bool isTeacher = AppData().currentUserRole == UserRole.teacher;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.all(isMobile ? 24 : 60),
        child: Column(
          children: [
            if (isMobile) ...[
              const SizedBox(height: 20),
              _buildMeetIllustration(isMobile, screenWidth),
              const SizedBox(height: 40),
            ],
            Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: isMobile
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium video meetings. Now free for everyone.',
                        textAlign: isMobile
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          fontSize: isMobile ? 28 : 48,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'We re-engineered the service we built for secure business meetings, Google Meet, to make it free and available for all.',
                        textAlign: isMobile
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: isMobile ? 15 : 18,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (isTeacher)
                        _buildTeacherActions(isMobile)
                      else
                        _buildStudentActions(isMobile),
                      const SizedBox(height: 32),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 32),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Text(
                          'Learn more',
                          style: TextStyle(color: Color(0xFF6C5CE7)),
                        ),
                        label: const Text(
                          'about Google Meet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 80),
                  Expanded(
                    flex: 1,
                    child: _buildMeetIllustration(isMobile, screenWidth),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetIllustration(bool isMobile, double screenWidth) {
    return Center(
      child: CircleAvatar(
        radius: isMobile ? screenWidth * 0.3 : 150,
        backgroundColor: const Color(0xFF6C5CE7).withAlpha(20),
        child: Icon(
          Icons.groups,
          size: isMobile ? screenWidth * 0.2 : 120,
          color: const Color(0xFF6C5CE7),
        ),
      ),
    );
  }

  Widget _buildTeacherActions(bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? double.infinity : null,
          child: ElevatedButton.icon(
            onPressed: _generateAndShowMeetingCode,
            icon: const Icon(Icons.video_call),
            label: const Text('New meeting'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (AppData().activeMeetingCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Active Session Code: ${AppData().activeMeetingCode}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStudentActions(bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? double.infinity : 280,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.keyboard, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: joinCodeCtrl,
                      onChanged: (val) => setState(() => joinErrorMsg = null),
                      decoration: const InputDecoration(
                        hintText: 'Enter a code or link',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 12 : 0),
            TextButton(
              onPressed: () {
                if (joinCodeCtrl.text.trim() == AppData().activeMeetingCode) {
                  setState(() => isCodeVerified = true);
                } else {
                  setState(() => joinErrorMsg = 'Invalid meeting code');
                }
              },
              child: Text(
                'Join',
                style: TextStyle(
                  fontSize: 16,
                  color: joinCodeCtrl.text.isEmpty
                      ? Colors.grey
                      : const Color(0xFF6C5CE7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (joinErrorMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              joinErrorMsg!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    );
  }

  void _generateAndShowMeetingCode() {
    String newCode = stringIdGenerator();
    AppData().setMeetingCode(newCode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Here's your meeting link"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Copy this link and send it to people you want to meet with.",
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(
                  newCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.grey),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: newCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => isCodeVerified = true);
            },
            child: const Text(
              'Join Now',
              style: TextStyle(
                color: Color(0xFF6C5CE7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isCodeVerified) return _buildGoogleMeetHome();
    if (!isInCall) return _buildPreCall();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Container(
      color: const Color(0xFF202124), // Google Meet dark grey
      child: Stack(
        children: [
          Row(
            children: [
              // Video Area
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
                        child: GridView.builder(
                          itemCount: 6,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isMobile
                                    ? 2
                                    : (isChatOpen ? 2 : 3),
                                crossAxisSpacing: isMobile ? 8 : 16,
                                mainAxisSpacing: isMobile ? 8 : 16,
                                childAspectRatio: isMobile ? 1.0 : (16 / 9),
                              ),
                          itemBuilder: (ctx, i) {
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF3C4043),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildStudentThumbnail(i),
                            );
                          },
                        ),
                      ),
                    ),
                    // Bottom Meet Controls Bar
                    Container(
                      height: 80,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 24,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isMobile)
                            const Text(
                              "10:24 AM • Class Sync",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          // Center Controls
                          Expanded(
                            child: Row(
                              mainAxisAlignment: isMobile
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                buildControlBtn(
                                  isMicMuted ? Icons.mic_off : Icons.mic_none,
                                  isMicMuted
                                      ? Colors.red
                                      : const Color(0xFF3C4043),
                                  () =>
                                      setState(() => isMicMuted = !isMicMuted),
                                  iconColor: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                                const SizedBox(width: 8),
                                buildControlBtn(
                                  isVideoOff
                                      ? Icons.videocam_off
                                      : Icons.videocam_outlined,
                                  isVideoOff
                                      ? Colors.red
                                      : const Color(0xFF3C4043),
                                  () =>
                                      setState(() => isVideoOff = !isVideoOff),
                                  iconColor: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                                if (!isMobile) ...[
                                  const SizedBox(width: 8),
                                  buildControlBtn(
                                    Icons.closed_caption_off_outlined,
                                    const Color(0xFF3C4043),
                                    () {},
                                    iconColor: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  buildControlBtn(
                                    Icons.back_hand_outlined,
                                    const Color(0xFF3C4043),
                                    () {},
                                    iconColor: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  buildControlBtn(
                                    Icons.present_to_all_outlined,
                                    const Color(0xFF3C4043),
                                    () {},
                                    iconColor: Colors.white,
                                  ),
                                ],
                                const SizedBox(width: 8),
                                buildControlBtn(
                                  Icons.call_end,
                                  Colors.red,
                                  () => setState(() => isInCall = false),
                                  iconColor: Colors.white,
                                  isLarge: true,
                                  size: isMobile ? 20 : 24,
                                ),
                              ],
                            ),
                          ),
                          // Right Controls
                          Row(
                            children: [
                              if (!isMobile)
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {},
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.people_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.chat_bubble_outline,
                                  color: isChatOpen
                                      ? const Color(0xFF8AB4F8)
                                      : Colors.white,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => isChatOpen = !isChatOpen),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Desktop Chat Panel
              if (!isMobile && isChatOpen)
                Container(
                  width: 320,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                    ),
                  ),
                  margin: const EdgeInsets.only(top: 16),
                  child: _buildChatContent(),
                ),
            ],
          ),

          // Mobile Chat Overlay
          if (isMobile && isChatOpen)
            Positioned.fill(
              child: Container(color: Colors.white, child: _buildChatContent()),
            ),
        ],
      ),
    );
  }

  Widget _buildChatContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'In-call messages',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => setState(() => isChatOpen = false),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Messages can only be seen by people in the call and are deleted when the call ends.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              buildChatMsg(
                'Student 2',
                'Can you re-explain the velocity formula?',
                '10:02 AM',
              ),
              buildChatMsg(
                'Prof. Alan',
                'Yes, let me pull up the slide again.',
                '10:03 AM',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Send a message to everyone',
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              suffixIcon: const Icon(Icons.send, color: Color(0xFF6C5CE7)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
