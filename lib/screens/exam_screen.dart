import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../models/difficulty_level.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────

class ExamQuestion {
  final String id;
  final String imageUrl;
  final String topic;
  final int difficulty;
  final int marksAvailable;
  final DifficultyLevel level;

  ExamQuestion({
    required this.id,
    required this.imageUrl,
    required this.topic,
    required this.difficulty,
    required this.marksAvailable,
    required this.level,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final int rawDiff = int.tryParse(json['difficulty'].toString()) ?? 1;
    final int diff = (rawDiff - 1).clamp(0, 2);
    return ExamQuestion(
      id: json['id'].toString(),
      imageUrl: json['question_image_url'] ?? '',
      topic: json['topic'] ?? '',
      difficulty: rawDiff,
      marksAvailable: json['marks_available'] ?? 1,
      level: DifficultyLevel.values[diff],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WHITEBOARD
// ─────────────────────────────────────────────────────────────

class _ExamStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _ExamStroke({required this.points, required this.color, required this.width});
}

class _ExamWhiteboardPainter extends CustomPainter {
  final List<_ExamStroke> strokes;
  final _ExamStroke? current;
  _ExamWhiteboardPainter({required this.strokes, this.current});

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
  bool shouldRepaint(_ExamWhiteboardPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
// EXAM SCREEN
// ─────────────────────────────────────────────────────────────

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen>
    with TickerProviderStateMixin {

  final _supabase = Supabase.instance.client;
  final GlobalKey _whiteboardKey = GlobalKey();
  final TextEditingController _answerController = TextEditingController();

  List<ExamQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitted = false;
  bool _evaluating = false;
  bool _done = false;

  // Score tracking
  int _totalAnswered = 0;
  int _totalCorrect = 0;
  int _totalMarks = 0;

  // Timer — 1 hour
  static const int _examDuration = 3600; // seconds
  int _secondsRemaining = _examDuration;
  Timer? _timer;
  bool _timeUp = false;

  // Drawing
  bool _isErasing = false;
  Color _strokeColor = Colors.black87;
  Color _savedColor = Colors.black;
  final List<_ExamStroke> _strokes = [];
  _ExamStroke? _currentStroke;
  double _strokeWidth = 3.0;
  int _retryAttempts = 0;

  // OCR
  String _recognizedText = '';

  // Animation
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
    _startTimer();

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
    _timer?.cancel();
    _slideController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        setState(() => _timeUp = true);
        _showTimeUpDialog();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _formattedTime {
    final h = _secondsRemaining ~/ 3600;
    final m = (_secondsRemaining % 3600) ~/ 60;
    final s = _secondsRemaining % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _isWarning => _secondsRemaining <= 300; // last 5 mins

  // ── Fetch from trial_questions ────────────────────────────────────────────

  Future<void> _fetchQuestions() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('trial_questions') // ← different table
          .select();

      final data = List<Map<String, dynamic>>.from(response);
      data.shuffle();

      setState(() {
        _questions = data.map((e) => ExamQuestion.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      print('Fetch error: $e');
      setState(() => _loading = false);
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  ExamQuestion get _current => _questions[_currentIndex];
  bool get _isLast => _currentIndex == _questions.length - 1;
  double get _progress => (_currentIndex + 1) / _questions.length;
  bool get _hasDrawing => _strokes.isNotEmpty;

  // ── Pointer handlers ──────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (_submitted) return;
    setState(() {
      _currentStroke = _ExamStroke(
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

    // TEMPORARY: simulate OCR
    await Future.delayed(const Duration(seconds: 1));
    _recognizedText = "x = 5";

    setState(() => _evaluating = false);

    await _showAnswerConfirmationDialog();

    setState(() => _evaluating = true);

    // TEMPORARY: simulate marking
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _totalAnswered++;
      _totalCorrect++; // placeholder
      _totalMarks += _current.marksAvailable; // placeholder
      _evaluating = false;
      _done = true;
    });

    // ── REAL backend call (uncomment when ready) ──
    // try {
    //   final base64Image = base64Encode(pngBytes!);
    //   final translateRes = await http.post(
    //     Uri.parse('https://YOUR_BACKEND_URL/api/evaluate/translate'),
    //     headers: {
    //       'Content-Type': 'application/json',
    //       'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
    //     },
    //     body: jsonEncode({'image': base64Image}),
    //   );
    //   _recognizedText = jsonDecode(translateRes.body)['extracted_text'] ?? '';
    //   setState(() => _evaluating = false);
    //   await _showAnswerConfirmationDialog();
    //   setState(() => _evaluating = true);
    //   final markRes = await http.post(
    //     Uri.parse('https://YOUR_BACKEND_URL/api/evaluate/mark'),
    //     headers: {
    //       'Content-Type': 'application/json',
    //       'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
    //     },
    //     body: jsonEncode({
    //       'question_id': _current.id,
    //       'image': base64Image,
    //       'extracted_text': _recognizedText,
    //     }),
    //   );
    //   final result = jsonDecode(markRes.body);
    //   setState(() {
    //     _totalAnswered++;
    //     if (result['is_correct']) _totalCorrect++;
    //     _totalMarks += result['marks_awarded'] as int;
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

  Future<void> _showAnswerConfirmationDialog() async {
    _answerController.text = _recognizedText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Confirm Your Answer"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "We extracted this text from your handwriting. "
                "Edit if needed, then tap Confirm.",
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
            ElevatedButton(
              onPressed: () {
                setState(() => _recognizedText = _answerController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  void _next() {
    if (_isLast) {
      _timer?.cancel();
      _showExamComplete();
      return;
    }
    _slideController.reset();
    setState(() {
      _currentIndex++;
      _submitted = false;
      _evaluating = false;
      _done = false;
      _strokes.clear();
      _currentStroke = null;
      _retryAttempts = 0;
      _isErasing = false;
      _strokeColor = Colors.black87;
      _strokeWidth = 3.0;
    });
    _slideController.forward();
  }

  void _showTimeUpDialog() {
    _timer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏰', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Time\'s Up!',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'You answered $_totalAnswered questions\n$_totalMarks marks collected',
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

  void _showExamComplete() {
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
            Text('Exam Complete!',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '$_totalCorrect correct out of $_totalAnswered\n$_totalMarks marks collected',
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

  // ── Helpers ───────────────────────────────────────────────────────────────

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
                      _buildLevelBadge(),
                      const SizedBox(height: 20),
                      _buildQuestionCard(),
                      const SizedBox(height: 28),
                      _buildWhiteboard(),
                      if (_done) ...[
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

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _timer?.cancel();
              Navigator.pop(context);
            },
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
            child: Text('Exam Mode',
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ),
          // Timer display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isWarning
                  ? Colors.redAccent.withOpacity(0.12)
                  : AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_rounded,
                  size: 14,
                  color: _isWarning ? Colors.redAccent : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formattedTime,
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isWarning ? Colors.redAccent : AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Question counter
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

  Widget _buildLevelBadge() {
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
              height: 200,
              width: double.infinity,
              child: Image.network(
                _current.imageUrl,
                fit: BoxFit.contain,
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
                errorBuilder: (context, error, stackTrace) => Container(
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                      painter: _ExamWhiteboardPainter(
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
              onPressed: _hasDrawing && !_timeUp ? _submit : null,
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
          _isLast ? 'Finish Exam 🎉' : 'Next Question →',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}