import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class AdminChatbotScreen extends StatefulWidget {
  const AdminChatbotScreen({super.key});

  @override
  State<AdminChatbotScreen> createState() => _AdminChatbotScreenState();
}

class _AdminChatbotScreenState extends State<AdminChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      fromUser: false,
      text:
          'Hello. I can help with e-PolyPariksha HP app workflows, admin accounts, student accounts, Excel import, tests, security logs, passwords, and release updates.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _faqs.take(8).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatBot'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _Bubble(message: _messages[index]),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final faq = suggestions[index];
                return ActionChip(
                  label: Text(faq.question, overflow: TextOverflow.ellipsis),
                  onPressed: () => _ask(faq.question),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        labelText: 'Ask a question',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onSubmitted: _ask,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: () => _ask(_controller.text),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _ask(String raw) {
    final question = raw.trim();
    if (question.isEmpty) return;
    _controller.clear();
    final answer = _answer(question);
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: question));
      _messages.add(_ChatMessage(fromUser: false, text: answer));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _answer(String question) {
    final q = _normalize(question);
    if (q.isEmpty) {
      return 'Please enter a e-PolyPariksha HP, admin, or student-related question and I will help.';
    }
    var bestScore = 0;
    _Faq? best;
    for (final faq in _faqs) {
      var score = 0;
      for (final keyword in faq.keywords) {
        if (q.contains(_normalize(keyword))) {
          score += keyword.length > 5 ? 3 : 1;
        }
      }
      for (final word in _normalize(faq.question).split(' ')) {
        if (word.length > 3 && q.contains(word)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = faq;
      }
    }
    if (best != null && bestScore > 0) return best.answer;
    if (!_isAppRelated(q)) {
      return 'I can only help with e-PolyPariksha HP app, admin, and student-related queries. Please ask about accounts, approvals, Excel import, student records, tests, PDFs, security logs, passwords, updates, or login.';
    }
    return 'I can help with that area, but I need a little more detail. Please ask specifically about Excel import, board roll number login, student fields, admin approvals, tests, PDFs, security logs, clearing data, updates, or account passwords.';
  }

  bool _isAppRelated(String normalizedQuestion) {
    const terms = [
      'poly',
      'poly h t',
      'app',
      'admin',
      'student',
      'login',
      'password',
      'account',
      'approval',
      'application',
      'excel',
      'import',
      'export',
      'board roll',
      'br no',
      'semester',
      'branch',
      'test',
      'pdf',
      'exam',
      'security',
      'log',
      '2fa',
      'update',
      'release',
      'apk',
      'profile',
      'photo',
      'college',
      'course',
    ];
    return terms.any(normalizedQuestion.contains);
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final color = isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface;
    final foreground =
        isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: isUser
              ? null
              : Border.all(
                  color: AppTheme.primaryLight.withValues(alpha: 0.12)),
        ),
        child: Text(message.text,
            style: TextStyle(color: foreground, height: 1.35)),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

class _Faq {
  const _Faq(
      {required this.question, required this.answer, required this.keywords});

  final String question;
  final String answer;
  final List<String> keywords;
}

const _faqs = <_Faq>[
  _Faq(
      question: 'Hello',
      answer:
          'Hello. I can help with e-PolyPariksha HP app, admin, and student workflows. Please ask about accounts, approvals, Excel import, tests, security logs, updates, or login.',
      keywords: ['hello', 'hi', 'hey', 'good morning', 'good evening']),
  _Faq(
      question: 'How do I add students using Excel?',
      answer:
          'Open Admin > Student Directory, use Import Excel, and upload an .xlsx file with complete columns: BR NO, Name, Father Name, Mobile No, email, college, branch, semester, dob, password, Joining year, drop out year, roll no, course, address, and college ID. Branch can be code or name.',
      keywords: ['excel', 'add students', 'import', 'xlsx', 'sheet']),
  _Faq(
      question: 'Which Excel columns are required?',
      answer:
          'Every student field is required for Excel import. Include BR NO, Name, branch, semester from 1 to 6, dob, password, Mobile No, email, college, Father Name, Joining year, drop out year, roll no, course, address, and college ID.',
      keywords: ['required columns', 'fields', 'excel columns', 'all fields']),
  _Faq(
      question: 'What is BR NO?',
      answer:
          'BR NO is the board roll number. Students use it as their login ID.',
      keywords: ['br no', 'board roll', 'login id']),
  _Faq(
      question: 'What is the default student password?',
      answer:
          'Student creation now requires a password. Use the password entered in the Add Student form or Excel sheet when the student logs in.',
      keywords: ['default password', 'dob', 'date of birth']),
  _Faq(
      question: 'How does a student log in?',
      answer:
          'The student taps Student, enters board roll number in the Board roll no field, and enters the password given by the admin.',
      keywords: ['student login', 'board roll', 'password']),
  _Faq(
      question: 'Can students register themselves?',
      answer:
          'No. Student registration is admin-only. Students can only log in after an admin creates or imports them.',
      keywords: ['student register', 'student signup']),
  _Faq(
      question: 'How do admins register?',
      answer:
          'On the Admin login screen, tap Register admin account. Fill every field except middle name, choose college and state, then submit. The superuser must approve the application.',
      keywords: ['admin register', 'application', 'approval']),
  _Faq(
      question: 'Is middle name compulsory?',
      answer:
          'No. Middle name is optional. First name, last name, mobile, email, college, state, and password are compulsory.',
      keywords: ['middle name', 'optional', 'compulsory']),
  _Faq(
      question: 'Who can approve admin applications?',
      answer:
          'Only the superuser or primary admin can open Admin Accounts and approve, reject, or remove admin applications.',
      keywords: ['approve application', 'superuser', 'primary admin']),
  _Faq(
      question: 'Where do admin applications appear?',
      answer:
          'Superuser opens Admin Accounts and taps the Applications box. The application list opens in a dialog with Add, Reject, and Remove actions.',
      keywords: ['applications box', 'application menu']),
  _Faq(
      question: 'How do I upload a test PDF?',
      answer:
          'Open the admin dashboard and tap Upload PDF. Select branch, semester, schedule, duration, and the PDF file.',
      keywords: ['upload pdf', 'test paper', 'question paper']),
  _Faq(
      question: 'Who can see my uploaded tests?',
      answer:
          'Students can see tests only when their branch, semester, and admin/college ownership match the uploaded test.',
      keywords: ['see tests', 'separate data', 'college data']),
  _Faq(
      question: 'How is admin data separated?',
      answer:
          'Regular admins only see their own students and tests. The superuser can manage all admin accounts and applications.',
      keywords: ['separate data', 'admin data', 'ownership']),
  _Faq(
      question: 'How is college data separated?',
      answer:
          'Student and test records store the admin/college context. Regular admins work only with their own records, and students see assigned tests only.',
      keywords: ['college data', 'separate college']),
  _Faq(
      question: 'Can normal admins add other admins?',
      answer:
          'No. Normal admins cannot add, approve, remove, or list admins. Only the superuser can.',
      keywords: ['normal admin', 'add admin']),
  _Faq(
      question: 'How do I remove an admin?',
      answer:
          'Superuser opens Admin Accounts, opens the admin menu, and selects Delete. Primary admin cannot be deleted until another primary admin is set.',
      keywords: ['remove admin', 'delete admin']),
  _Faq(
      question: 'How do I reject an application?',
      answer:
          'Superuser opens Admin Accounts, taps Applications, then taps Reject on the pending application.',
      keywords: ['reject application']),
  _Faq(
      question: 'How do I remove an application?',
      answer:
          'Superuser opens Admin Accounts, taps Applications, then uses the delete icon on the application row.',
      keywords: ['remove application', 'delete application']),
  _Faq(
      question: 'How do I clear logs?',
      answer:
          'Superuser opens Admin Accounts, taps the clear icon, selects All logs, enters 2FA code, and confirms.',
      keywords: ['clear logs', 'delete logs']),
  _Faq(
      question: 'How do I clear applications?',
      answer:
          'Superuser opens Admin Accounts, taps the clear icon, selects All applications, enters 2FA code, and confirms.',
      keywords: ['clear applications']),
  _Faq(
      question: 'Why is 2FA required for clearing data?',
      answer:
          'Clearing data is destructive. 2FA prevents accidental or unauthorized deletion.',
      keywords: ['2fa', 'clear data']),
  _Faq(
      question: 'How do I enable admin 2FA?',
      answer:
          'Open Admin Accounts and tap My 2FA, or open Settings where available. Scan the QR code and enter the authenticator code.',
      keywords: ['enable 2fa', 'authenticator']),
  _Faq(
      question: 'How do I change password?',
      answer:
          'Open Settings, tap Change, enter current password, new strong password, confirm it, and provide 2FA code if enabled.',
      keywords: ['change password']),
  _Faq(
      question: 'What password is valid for admin registration?',
      answer:
          'Use at least 8 characters with uppercase, lowercase, number, and symbol.',
      keywords: ['admin password', 'strong password']),
  _Faq(
      question: 'What mobile number format is valid?',
      answer:
          'Use digits only, 7 to 20 digits. Do not include spaces, dashes, or country-code plus signs.',
      keywords: ['mobile', 'phone']),
  _Faq(
      question: 'How do I edit a student?',
      answer:
          'Open Student Directory, tap a student, then use the edit controls to update profile, branch, semester, or status.',
      keywords: ['edit student', 'student profile']),
  _Faq(
      question: 'How do I delete a student?',
      answer:
          'Open Student Directory, select the student, and use the delete action. This removes related sessions and attempt records.',
      keywords: ['delete student']),
  _Faq(
      question: 'Can I export students?',
      answer:
          'Yes. In Student Directory, use Export Excel to download current student records in the supported sheet format.',
      keywords: ['export students', 'download excel']),
  _Faq(
      question: 'Can I import admins from Excel?',
      answer:
          'Admin Excel import is restricted to the superuser. Normal admins cannot import or create admins.',
      keywords: ['import admins']),
  _Faq(
      question: 'What branch values are accepted in Excel?',
      answer:
          'Use branch code like CE, ME, EE, EC, CV, or the branch name. The importer matches codes and names.',
      keywords: ['branch code', 'branch name']),
  _Faq(
      question: 'What semester values are valid?',
      answer: 'Semester must be a number from 1 to 6.',
      keywords: ['semester']),
  _Faq(
      question: 'How do students access test history?',
      answer:
          'Students open the menu and tap Test History. Ended papers are visible for the configured history window.',
      keywords: ['test history']),
  _Faq(
      question: 'Why does a student not see a test?',
      answer:
          'Check the student branch, semester, active status, test branch, test semester, schedule time, and admin/college ownership.',
      keywords: ['student not see test', 'missing test']),
  _Faq(
      question: 'How do I end a test early?',
      answer:
          'On the admin dashboard, tap End Now on the test card and confirm.',
      keywords: ['end test']),
  _Faq(
      question: 'How do I hide or reactivate a test?',
      answer:
          'On the test card, use Cancel to hide an active test or Reactivate to make it active again.',
      keywords: ['hide test', 'reactivate']),
  _Faq(
      question: 'How do I replace a PDF?',
      answer: 'On the test card, tap Re-upload and choose the new PDF.',
      keywords: ['replace pdf', 're-upload']),
  _Faq(
      question: 'What file size should PDF have?',
      answer:
          'Keep PDFs small. Mobile upload warns above 4 MB because large files may be blocked before reaching the server.',
      keywords: ['pdf size', 'large pdf']),
  _Faq(
      question: 'What are exam security logs?',
      answer:
          'They record important student test events such as starting, PDF access, app backgrounding, and completion.',
      keywords: ['security logs', 'exam logs']),
  _Faq(
      question: 'Can normal admins see security logs?',
      answer: 'No. Logs are visible only to the superuser.',
      keywords: ['normal admins logs']),
  _Faq(
      question: 'What does locked attempt mean?',
      answer:
          'A locked or blocked attempt means the system recorded a critical exam event. Superuser/admin controls can review allowed actions.',
      keywords: ['locked attempt', 'blocked attempt']),
  _Faq(
      question: 'How do I force users to sign in again?',
      answer:
          'Superuser opens clear data, selects All login sessions, enters 2FA code, and confirms.',
      keywords: ['logout users', 'sessions']),
  _Faq(
      question: 'How do I update the app?',
      answer:
          'The update prompt opens the e-PolyPariksha HP Play Store page when a Play Store build is available. GitHub release APKs remain available for direct installs.',
      keywords: ['update app', 'latest apk', 'play store']),
  _Faq(
      question: 'Why do I see server route not available?',
      answer:
          'That means the backend deployment has not received the route yet or the API base URL is wrong. Wait for deployment or verify API_BASE_URL.',
      keywords: ['server route', 'html error', 'backend deployment']),
  _Faq(
      question: 'Why does login fail after approval?',
      answer:
          'Check that the superuser approved the application and the admin is active. Use the same email and password submitted during registration.',
      keywords: ['login fail', 'approved admin']),
  _Faq(
      question: 'What is the superuser email?',
      answer:
          'The permanent superuser is admin@gpkangra.edu. It is marked primary when the backend schema guard runs.',
      keywords: ['superuser email', 'admin@gpkangra.edu']),
  _Faq(
      question: 'Can the primary admin be deactivated?',
      answer:
          'No. The primary admin cannot be deactivated or deleted until another active admin is made primary.',
      keywords: ['primary admin', 'deactivate']),
  _Faq(
      question: 'How do I search colleges during registration?',
      answer:
          'Tap the College field, type part of the polytechnic name, and select the matching college from the dialog.',
      keywords: ['search college', 'choose college']),
  _Faq(
      question: 'Can I use dark mode?',
      answer:
          'Yes. Dark mode is saved securely and works across login, register, admin, and student pages.',
      keywords: ['dark mode']),
  _Faq(
      question: 'Why is the student menu blank?',
      answer:
          'Use the latest app. The combined app uses one shared theme provider so the student menu renders correctly in dark and light mode.',
      keywords: ['student menu blank', 'hamburger']),
  _Faq(
      question: 'How do I upload profile photos?',
      answer:
          'Open profile or student details and use the photo upload control. Images are sent through the authenticated API.',
      keywords: ['profile photo']),
  _Faq(
      question: 'How do I verify backend health?',
      answer:
          'Open the backend /health endpoint. It should return JSON with service e-PolyPariksha HP-api.',
      keywords: ['backend health']),
  _Faq(
      question: 'What happens after admin application approval?',
      answer:
          'After approval, the application is automatically added to the Admin Accounts list as an active admin account. The admin signs in with the same email and password submitted during registration.',
      keywords: [
        'after approval',
        'approved application',
        'admin account list'
      ]),
  _Faq(
      question: 'How do I keep records professional?',
      answer:
          'Use complete Excel rows, consistent branch codes, correct semesters, real mobile/email values, and review imported students before tests.',
      keywords: ['records', 'professional']),
  _Faq(
      question: 'Can I ask this assistant anything?',
      answer:
          'This assistant is a local FAQ helper for e-PolyPariksha HP workflows. It does not send data outside the app and does not require an API key.',
      keywords: ['assistant', 'chatbot', 'ai']),
];
