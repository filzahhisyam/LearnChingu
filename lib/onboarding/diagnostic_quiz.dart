import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

enum DifficultyLevel { beginner, intermediate, advanced }

class DiagnosticQuestion {
  final String question;
  final DifficultyLevel level;

  const DiagnosticQuestion({
    required this.question,
    required this.level,
  });
}

const List<DiagnosticQuestion> _questions = [
  DiagnosticQuestion(
    question: 'What is 12 × 8?',
    level: DifficultyLevel.beginner,
  ),
  DiagnosticQuestion(
    question: 'Solve for x: 3x + 7 = 22',
    level: DifficultyLevel.intermediate,
  ),
  DiagnosticQuestion(
    question: 'What is the area of a circle with radius 5? (Use π ≈ 3.14)',
    level: DifficultyLevel.intermediate,
  ),
  DiagnosticQuestion(
    question: 'What is the slope of the line passing through (2, 3) and (4, 7)?',
    level: DifficultyLevel.intermediate,
  ),
  DiagnosticQuestion(
    question: 'What is the derivative of f(x) = 3x² + 5x − 2?',
    level: DifficultyLevel.advanced,
  ),
];

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
  int _currentIndex = 0;
  bool _submitted = false;
  bool _evaluating = false;
  bool _done = false;

  // Background tracking (sent to backend, not shown to user)
  DateTime? _questionStartTime;
  int _retryAttempts = 0;
  int _hesitationCount = 0;
  DateTime? _lastStrokeTime;

  // Drawing
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;
  double _strokeWidth = 3.0;
  Color _strokeColor = Colors.black87;

  // Animation
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _questionStartTime = DateTime.now();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

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

    // TODO: Replace delay with real API call
    // Send to backend:
    // - whiteboard image (base64)
    // - question string
    // - response_time_seconds
    // - hesitation_count
    // - retry_attempts
    // - stroke_count
    await Future.delayed(const Duration(milliseconds: 1800));

    setState(() {
      _evaluating = false;
      _done = true;
    });
  }

  void _next() {
    if (_isLast) {
      Navigator.pushReplacementNamed(context, '/dashboard');
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
            child: Text('Math Diagnostic',
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
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
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
          const SizedBox(height: 8),
          Text(_current.question,
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.4)),
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
        Text('Show your full working — AI will read and evaluate it',
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
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),

        // Canvas
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _done
                  ? const Color(0xFF4CAF50)
                  : _submitted
                      ? AppColors.border
                      : AppColors.primary,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
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
                // Evaluating overlay
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
                // Done overlay
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
                                  color: Color(0xFF2E7D32))),
                        ],
                      ),
                    ),
                  ),
              ],
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
        onPressed: () {
          if (_isLast) {
        Navigator.pushNamed(
          context,
          '/onboarding/diagnostic_results',
        );
      } else {
        _next(); // go to next question
      }
    },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          _isLast ? 'Finish Quiz 🎉' : 'Next Question →',
          style: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
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
      onTap: () => setState(() => _strokeColor = color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24, height: 24,
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
