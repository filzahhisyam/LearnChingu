import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/difficulty_level.dart';


class DiagnosticResults extends StatefulWidget {
  final DifficultyLevel level;
  const DiagnosticResults({super.key, this.level = DifficultyLevel.beginner});

  @override
  State<DiagnosticResults> createState() => _DiagnosticResultsState();
}

class _DiagnosticResultsState extends State<DiagnosticResults>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    Future.delayed(const Duration(milliseconds: 150), () {
    _contentController.forward();
  });
        
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(
        parent: _contentController, 
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
        
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _contentController, 
            curve: const Interval(0.1, 0.7, curve: Curves.easeOutBack)));
            
    _scaleAnim = Tween<double>(
        begin: 0.92,
        end: 1.0,
      ).animate(
        CurvedAnimation(parent: _contentController, curve: Curves.easeOutBack),
      );

       _pulseAnim = Tween<double>(
        begin: 1.0,
        end: 1.04,
      ).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ),
      );

    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Maps difficulty levels to your custom theme colors
  Map<String, Color> get _levelColors {
    switch (widget.level) {
      case DifficultyLevel.beginner:
        return {
          'bg': AppColors.greenSurface,
          'text': AppColors.greenDark,
          'border': AppColors.green.withOpacity(0.4),
        };
      case DifficultyLevel.intermediate:
        return {
          'bg': AppColors.purpleSurface,
          'text': AppColors.purple,
          'border': AppColors.purple.withOpacity(0.3),
        };
      case DifficultyLevel.advanced:
        return {
          'bg': AppColors.primaryLight,
          'text': AppColors.primaryDark,
          'border': AppColors.primarySurface.withOpacity(0.4),
        };
    }
  }

  String get _levelLabel {
    switch (widget.level) {
      case DifficultyLevel.beginner: return 'Beginner';
      case DifficultyLevel.intermediate: return 'Intermediate';
      case DifficultyLevel.advanced: return 'Advanced';
    }
  }

  String get _levelEmoji {
    switch (widget.level) {
      case DifficultyLevel.beginner: return '🌱';
      case DifficultyLevel.intermediate: return '⚡';
      case DifficultyLevel.advanced: return '🔥';
    }
  }

 @override
Widget build(BuildContext context) {
  final colors = _levelColors;
  final textTheme = Theme.of(context).textTheme;

  return FadeTransition(
    opacity: _fadeAnim,
    child: Scaffold(
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                const Spacer(),

                ScaleTransition(
                  scale: _scaleAnim,
                  child: Center(
                    child: Image.asset(
                      AppAssets.chinguIcon,
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Your Learning Level',
                  style: textTheme.displayMedium,
                ),

                const SizedBox(height: 28),

                ScaleTransition(
                  scale: _scaleAnim,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) =>
                        Transform.scale(scale: _pulseAnim.value, child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 44, vertical: 20),
                      decoration: BoxDecoration(
                        color: colors['bg'],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colors['border']!,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _levelEmoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _levelLabel,
                            style: textTheme.displaySmall?.copyWith(
                              color: colors['text'],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/home'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Start Learning'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
    }