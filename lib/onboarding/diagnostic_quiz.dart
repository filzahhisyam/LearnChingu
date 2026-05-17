import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'diagnostic_results.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../models/difficulty_level.dart';
import '/screens/question_service.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class DiagnosticQuestion {
  final String id;
  final String questionText;
  final String imageUrl;
  final String topic;
  final int difficulty;
  final int marksAvailable;
  final DifficultyLevel level;

  DiagnosticQuestion({
    required this.id,
    required this.questionText,
    required this.imageUrl,
    required this.topic,
    required this.difficulty,
    required this.marksAvailable,
    required this.level,
  });

  factory DiagnosticQuestion.fromJson(Map<String, dynamic> json) {
    final int diff = (json['difficulty'] as int).clamp(0, 2);
    return DiagnosticQuestion(
      id: json['id'],
      questionText: json['question_text'] ??'',
      imageUrl: json['question_image_url']??'',
      topic: json['topic'],
      difficulty: json['difficulty'],
      marksAvailable: json['marks_available'],
      level: DifficultyLevel.values[diff],
    );
  }
}

// ── Drawing ───────────────────────────────────────────────────────────────────

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke({required this.points, required this.color, required this.width});
}

class _WhiteboardPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? current;
  _WhiteboardPainter({required this.strokes, this.current});

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
  bool shouldRepaint(_WhiteboardPainter old) => true;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen>
    with TickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────────────────

  List<DiagnosticQuestion> _questions = [];
  bool _loading = true;

  Color _strokeColor = Colors.black87;

  final GlobalKey _whiteboardKey = GlobalKey();
  String _recognizedText = '';
  final TextEditingController _answerController = TextEditingController();

  int _currentIndex = 0;
  int _score = 0;
  bool _submitted = false;
  bool _evaluating = false;
  bool _done = false;

  // Background tracking
  DateTime? _questionStartTime;
  int _retryAttempts = 0;
  int _hesitationCount = 0;
  DateTime? _lastStrokeTime;

  // Drawing
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;
  double _strokeWidth = 3.0;

  // Animation
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _questionStartTime = DateTime.now();
    _loadQuestions();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadQuestions() async {
    final service = QuestionService();
    final data = await service.fetchDiagnosticQuestions();
    setState(() {
      _questions = data.map((q) => DiagnosticQuestion.fromJson(q)).toList();;
      _loading = false;
      _questionStartTime = DateTime.now();
    });
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  DiagnosticQuestion get _current => _questions[_currentIndex];
  bool get _isLast => _currentIndex == _questions.length - 1;
  double get _progress => (_currentIndex + 1) / _questions.length;
  bool get _hasDrawing => _strokes.isNotEmpty;

  // ── Pointer handlers ──────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (_submitted) return;
    final now = DateTime.now();
    if (_lastStrokeTime != null &&
        now.difference(_lastStrokeTime!).inSeconds > 2) {
      _hesitationCount++;
    }
    _lastStrokeTime = now;
    setState(() {
      _currentStroke = _Stroke(
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

    // Fake OCR — replace with real backend call later
    await Future.delayed(const Duration(seconds: 1));
    _recognizedText = "x = 5";

    setState(() => _evaluating = false);

    await _showAnswerConfirmationDialog();

    print("FINAL CONFIRMED ANSWER: $_recognizedText");

    await Future.delayed(const Duration(milliseconds: 500));

    // Fake correctness — replace with real evaluation later
    const bool isCorrect = true;

    if (isCorrect) {
      switch (_current.level) {
        case DifficultyLevel.beginner:
          _score += 1;
          break;
        case DifficultyLevel.intermediate:
          _score += 2;
          break;
        case DifficultyLevel.advanced:
          _score += 3;
          break;
      }
    }

    print("CURRENT SCORE: $_score");

    setState(() => _done = true);
  }

  DifficultyLevel _calculateLevel() {
    if (_score <= 2) return DifficultyLevel.beginner;
    if (_score <= 6) return DifficultyLevel.intermediate;
    return DifficultyLevel.advanced;
  }

  Future<Uint8List?> _exportWhiteboardToPng() async {
    try {
      final boundary = _whiteboardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        );
      },
    );
  }

  void _next() {
    if (_isLast) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiagnosticResults(level: _calculateLevel()),
        ),
      );
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
      _hesitationCount = 0;
      _lastStrokeTime = null;
      _questionStartTime = DateTime.now();
    });
    _slideController.forward();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _levelColor(DifficultyLevel l) {
    switch (l) {
      case DifficultyLevel.beginner:
        return const Color(0xFF4CAF50);
      case DifficultyLevel.intermediate:
        return const Color(0xFFFFA726);
      case DifficultyLevel.advanced:
        return const Color(0xFFEF5350);
    }
  }

  String _levelLabel(DifficultyLevel l) {
    switch (l) {
      case DifficultyLevel.beginner:
        return 'Beginner';
      case DifficultyLevel.intermediate:
        return 'Intermediate';
      case DifficultyLevel.advanced:
        return 'Advanced';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No questions found.')),
      );
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
                        const SizedBox(height: 20),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
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
            child: Text('Math Diagnostic',
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          valueColor:
              AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
        ),
      ),
    );
  }

  Widget _buildLevelBadge() {
    final color = _levelColor(_current.level);
    final label = _levelLabel(_current.level);
    return Container(
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
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: Image.network(
            _current.imageUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            headers: const {
              'Cache-Control': 'no-cache',
            },
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
              print('Image error: $error'); // helps debug
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
                      Text(
                        'Could not load image',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
        Text(
            'Show your full working in the whiteboard below to be evaluated',
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),

        // Toolbar
        if (!_submitted)
          Row(
            children: [
              _toolBtn(Icons.edit_rounded, 'Thin',
                  () => setState(() => _strokeWidth = 2.5)),
              const SizedBox(width: 8),
              _toolBtn(Icons.brush_rounded, 'Thick',
                  () => setState(() => _strokeWidth = 5.0)),
              const SizedBox(width: 10),
              _colorDot(Colors.black87),
              const SizedBox(width: 6),
              _colorDot(const Color(0xFF1565C0)),
              const SizedBox(width: 6),
              _colorDot(const Color(0xFFB71C1C)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _strokes.clear();
                  _currentStroke = null;
                  _retryAttempts++;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
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
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ]),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),

        // Canvas
        RepaintBoundary(
          key: _whiteboardKey,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _done
                    ? const Color(0xFF4CAF50)
                    : _submitted
                        ? AppColors.border
                        : AppColors.primaryDark,
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
                      painter: _WhiteboardPainter(
                          strokes: _strokes, current: _currentStroke),
                      child: _strokes.isEmpty && _currentStroke == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.draw_rounded,
                                      color: Colors.grey.shade300,
                                      size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Write or draw your working here...',
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
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.primary),
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
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFF5E3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF4CAF50)
                                  .withOpacity(0.4)),
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

        // Submit button
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
          _isLast ? 'Finish Quiz 🎉' : 'Next Question →',
          style:
              GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _toolBtn(
      IconData icon, String tooltip, VoidCallback onTap) {
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
      onTap: () => setState(() => _strokeColor = color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
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
}