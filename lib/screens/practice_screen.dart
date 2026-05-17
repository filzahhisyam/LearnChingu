import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../models/difficulty_level.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────
// TOPICS
// ─────────────────────────────────────────────────────────────

const List<String> kTopics = [
  'NUMBER BASES',
  'LOGICAL REASONING',
  'QUADRATIC EQUATIONS',
];

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────

class PracticeQuestion {
  final String id;
  final String imageUrl;
  final String markingSchemeUrl;
  final String topic;
  final int difficulty;
  final int marksAvailable;
  final DifficultyLevel level;

  PracticeQuestion({
    required this.id,
    required this.imageUrl,
    required this.markingSchemeUrl,
    required this.topic,
    required this.difficulty,
    required this.marksAvailable,
    required this.level,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    final int rawDiff = int.tryParse(json['difficulty'].toString()) ?? 1;
    final int diff = (rawDiff - 1).clamp(0, 2); // 1,2,3 → 0,1,2
    return PracticeQuestion(
      id: json['id'].toString(),
      imageUrl: json['question_image_url'] ?? '',
      markingSchemeUrl: json['marking_scheme_image_url'] ?? '',
      topic: json['topic'] ?? '',
      difficulty: rawDiff,
      marksAvailable: json['marks_available'] ?? 1,
      level: DifficultyLevel.values[diff],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WHITEBOARD — same as diagnostic
// ─────────────────────────────────────────────────────────────

class _PracticeStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _PracticeStroke({required this.points, required this.color, required this.width});
}

class _PracticeWhiteboardPainter extends CustomPainter {
  final List<_PracticeStroke> strokes;
  final _PracticeStroke? current;
  _PracticeWhiteboardPainter({required this.strokes, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, if (current != null) current!]) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PracticeWhiteboardPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
// TOPIC PICKER — same style as diagnostic header
// ─────────────────────────────────────────────────────────────

class PracticeTopicScreen extends StatefulWidget {
  const PracticeTopicScreen({super.key});

  @override
  State<PracticeTopicScreen> createState() => _PracticeTopicScreenState();
}

class _PracticeTopicScreenState extends State<PracticeTopicScreen> {
  final Set<String> _selectedTopics = {};

  IconData _topicIcon(String topic) {
    switch (topic) {
      case 'NUMBER BASES': return Icons.tag_rounded;
      case 'LOGICAL REASONING': return Icons.psychology_rounded;
      case 'QUADRATIC EQUATIONS': return Icons.functions_rounded;
      default: return Icons.book_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 24),
              Text('Choose Topics',
                  style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Select 1 to 3 topics to practise',
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: kTopics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final topic = kTopics[index];
                    final selected = _selectedTopics.contains(topic);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedTopics.remove(topic);
                        } else if (_selectedTopics.length < 3) {
                          _selectedTopics.add(topic);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppColors.primary : AppColors.border,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withOpacity(0.15)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_topicIcon(topic),
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(topic,
                                  style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textPrimary)),
                            ),
                            if (selected)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selectedTopics.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PracticeScreen(
                                  topics: _selectedTopics.toList()),
                            ),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textHint,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    _selectedTopics.isEmpty
                        ? 'Select at least 1 topic'
                        : 'Start Practice (${_selectedTopics.length} topic${_selectedTopics.length > 1 ? 's' : ''})',
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PRACTICE SCREEN
// ─────────────────────────────────────────────────────────────

class PracticeScreen extends StatefulWidget {
  final List<String> topics;
  const PracticeScreen({super.key, required this.topics});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with TickerProviderStateMixin {

  final _supabase = Supabase.instance.client;
  final GlobalKey _whiteboardKey = GlobalKey();
  final TextEditingController _answerController = TextEditingController();

  List<PracticeQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitted = false;
  bool _evaluating = false;
  bool _done = false;
  bool _isCorrect = false;

  // Score tracking
  int _totalAnswered = 0;
  int _totalCorrect = 0;

  // Drawing — identical to diagnostic
  bool _isErasing = false;
  Color _strokeColor = Colors.black87;
  Color _savedColor = Colors.black;
  final List<_PracticeStroke> _strokes = [];
  _PracticeStroke? _currentStroke;
  double _strokeWidth = 3.0;
  int _retryAttempts = 0;

  // OCR
  String _recognizedText = '';

  // Animation — identical to diagnostic
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  // ── Fetch — ChatGPT's working logic, untouched ────────────────────────────

  Future<void> _fetchQuestions() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('questions')
          .select()
          .filter('topic', 'in', widget.topics);

      final data = List<Map<String, dynamic>>.from(response);
      data.shuffle();

      setState(() {
        _questions = data.map((e) => PracticeQuestion.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _loading = false);
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  PracticeQuestion get _current => _questions[_currentIndex];
  bool get _isLast => _currentIndex == _questions.length - 1;
  double get _progress => (_currentIndex + 1) / _questions.length;
  bool get _hasDrawing => _strokes.isNotEmpty;

  // ── Pointer handlers — identical to diagnostic ────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (_submitted) return;
    setState(() {
      _currentStroke = _PracticeStroke(
        points: [e.localPosition],
        color: _strokeColor,
        width: _strokeWidth,
      );
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_submitted || _currentStroke == null) return;
    setState(() => _currentStroke!.points.add(e.localPosition));
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_submitted || _currentStroke == null) return;
    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
  if (!_hasDrawing) return;

  setState(() {
    _submitted = true;
    _evaluating = true;
  });



  final pngBytes = await _exportWhiteboardToPng();
  print("PNG SIZE: ${pngBytes?.length}");

  // ── TEMPORARY: simulate backend response ──
  // Replace with real API call when backend is ready
  await Future.delayed(const Duration(seconds: 2));

  setState(() => _evaluating = false);

  // Show dialog so student can confirm/correct OCR text
  await _showAnswerConfirmationDialog();

  setState(() => _evaluating = true);

  setState(() {
    _isCorrect = true;           // placeholder
    _totalAnswered++;
    if (_isCorrect) _totalCorrect++;
    _evaluating = false;
    _done = true;
  });

  // ── REAL backend call (uncomment when backend gives you the URL) ──
  // try {
  //   final base64Image = base64Encode(pngBytes!);
  //   final response = await http.post(
  //     Uri.parse('https://YOUR_BACKEND_URL/api/evaluate/mark'),
  //     headers: {
  //       'Content-Type': 'application/json',
  //       'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
  //     },
  //     body: jsonEncode({
  //       'question_id': _current.id,
  //       'image': base64Image,
  //     }),
  //   );
  //   final result = jsonDecode(response.body);
  //   setState(() {
  //     _isCorrect = result['is_correct'];
  //     _totalAnswered++;
  //     if (_isCorrect) _totalCorrect++;
  //     _evaluating = false;
  //     _done = true;
  //   });
  // } catch (e) {
  //   print('Backend error: $e');
  //   setState(() => _evaluating = false);
  // }
}

  Future<Uint8List?> _exportWhiteboardToPng() async {
    try {
      final boundary = _whiteboardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      print("ERROR exporting image: $e");
      return null;
    }
  }

  // Identical to diagnostic
  Future<void> _showAnswerConfirmationDialog() async {
    _answerController.text = _recognizedText;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Your Answer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "We extracted this text from your handwriting. "
              "Please confirm or edit it if needed.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Edit your answer here...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Edit"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _recognizedText = _answerController.text);
              Navigator.pop(context);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (_isLast) {
      _showSessionComplete();
      return;
    }
    _slideController.reset();
    setState(() {
      _currentIndex++;
      _submitted = false;
      _evaluating = false;
      _done = false;
      _isCorrect = false;
      _strokes.clear();
      _currentStroke = null;
      _retryAttempts = 0;
      _isErasing = false;
      _strokeColor = Colors.black87;
      _strokeWidth = 3.0;
    });
    _slideController.forward();
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Practice Complete!',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '$_totalCorrect correct out of $_totalAnswered answered',
              style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(
                    context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Back to Home',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers — identical to diagnostic ────────────────────────────────────

  Color _levelColor(DifficultyLevel l) {
    switch (l) {
      case DifficultyLevel.beginner: return const Color(0xFF4CAF50);
      case DifficultyLevel.intermediate: return const Color(0xFFFFA726);
      case DifficultyLevel.advanced: return const Color(0xFFEF5350);
    }
  }

  String _levelLabel(DifficultyLevel l) {
    switch (l) {
      case DifficultyLevel.beginner: return 'Beginner';
      case DifficultyLevel.intermediate: return 'Intermediate';
      case DifficultyLevel.advanced: return 'Advanced';
    }
  }

  Widget _toolBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    final selected = _strokeColor == color;
    return GestureDetector(
      onTap: () => setState(() {
        _strokeColor = color;
        _savedColor = color;
        _isErasing = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? const ui.Color.fromARGB(255, 235, 234, 234)
                : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('No questions found.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopicAndLevelBadge(),
                      const SizedBox(height: 20),
                      _buildQuestionCard(),
                      const SizedBox(height: 28),
                      _buildWhiteboard(),
                      if (_done) ...[
                        const SizedBox(height: 20),
                        _buildMarkingScheme(),
                        const SizedBox(height: 16),
                        _buildFeedbackBanner(),
                        const SizedBox(height: 16),
                        _buildNextButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets — identical style to diagnostic ───────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Practice Mode',
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_currentIndex + 1} / ${_questions.length}',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 6,
          backgroundColor: AppColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
        ),
      ),
    );
  }

  Widget _buildTopicAndLevelBadge() {
    final color = _levelColor(_current.level);
    final label = _levelLabel(_current.level);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_current.topic,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      ],
    );
  }

  // Identical to diagnostic _buildQuestionCard
  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 4),
              blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question ${_currentIndex + 1}',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: SizedBox(
              height: 200,        // ✅ change this number to whatever fits
              width: double.infinity,
              child: Image.network(
                _current.imageUrl,
              headers: const {'Cache-Control': 'no-cache'},
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey.shade50,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Image error: $error');
                return Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            color: Colors.grey.shade400, size: 36),
                        const SizedBox(height: 8),
                        Text('Could not load image',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ),
        ]
      ),
    );
  }

  Widget _buildMarkingScheme() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 4),
              blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF4CAF50), size: 18),
                const SizedBox(width: 8),
                Text('Marking Scheme',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E7D32))),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.network(
                _current.markingSchemeUrl,
                fit: BoxFit.contain,
                headers: const {'Cache-Control': 'no-cache'},
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 150,
                  color: Colors.grey.shade50,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF4CAF50),
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: Colors.grey.shade100,
                child: Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.grey.shade400, size: 36),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCorrect ? const Color(0xFFDFF5E3) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCorrect
              ? const Color(0xFF4CAF50).withOpacity(0.4)
              : Colors.redAccent.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isCorrect ? Icons.celebration_rounded : Icons.lightbulb_rounded,
            color: _isCorrect ? const Color(0xFF2E7D32) : Colors.redAccent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCorrect ? 'Great job! 🎉' : 'Keep going! 💪',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _isCorrect
                        ? const Color(0xFF2E7D32)
                        : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCorrect
                      ? 'You got this one right. Review the marking scheme above to reinforce your understanding.'
                      : 'Study the marking scheme carefully and try the next one. You\'ve got this!',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: _isCorrect
                        ? const Color(0xFF2E7D32)
                        : Colors.redAccent.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Identical to diagnostic _buildWhiteboard
  Widget _buildWhiteboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('✏️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('Write your answer',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Show your full working in the whiteboard below to be evaluated',
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),

        if (!_submitted)
          Row(
            children: [
              _toolBtn(Icons.edit_rounded, 'Thin',
                  () => setState(() => _strokeWidth = 2.5)),
              const SizedBox(width: 8),
              _toolBtn(Icons.brush_rounded, 'Thick',
                  () => setState(() => _strokeWidth = 4.0)),
              const SizedBox(width: 10),
              _colorDot(Colors.black87),
              const SizedBox(width: 6),
              _colorDot(const Color(0xFF1565C0)),
              const SizedBox(width: 6),
              _colorDot(const Color(0xFFB71C1C)),
              const SizedBox(width: 18),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _strokes.clear();
                  _currentStroke = null;
                  _retryAttempts++;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.refresh_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Clear',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() {
                  _isErasing = !_isErasing;
                  if (_isErasing) {
                    _savedColor = _strokeColor;
                    _strokeColor = Colors.white;
                    _strokeWidth = 16.0;
                  } else {
                    _strokeColor = _savedColor;
                    _strokeWidth = 3.0;
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isErasing
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_fix_normal,
                          size: 14,
                          color: _isErasing
                              ? AppColors.primary
                              : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Eraser',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _isErasing
                                  ? AppColors.primary
                                  : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 12),

        RepaintBoundary(
          key: _whiteboardKey,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _done ? const Color(0xFF4CAF50) : AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    offset: const Offset(0, 3),
                    blurRadius: 10),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    child: CustomPaint(
                      painter: _PracticeWhiteboardPainter(
                          strokes: _strokes, current: _currentStroke),
                      child: _strokes.isEmpty && _currentStroke == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.draw_rounded,
                                      color: Colors.grey.shade300, size: 36),
                                  const SizedBox(height: 8),
                                  Text('Write or draw your working here...',
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: Colors.grey.shade400)),
                                ],
                              ),
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
                  if (_evaluating)
                    Container(
                      color: Colors.white.withOpacity(0.85),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32, height: 32,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: AppColors.primary),
                            ),
                            const SizedBox(height: 12),
                            Text('Analysing...',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  if (_done)
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFF5E3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 14, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 4),
                            Text('Submitted',
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E7D32))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (!_submitted)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _hasDrawing ? _submit : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text('Submit Answer',
                  style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.textHint,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          _isLast ? 'Finish Practice 🎉' : 'Next Question →',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}