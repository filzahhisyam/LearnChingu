import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── ChinguButton ─────────────────────────────────────────────────────────────

class ChinguButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? shadowColor;

  const ChinguButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    final shadow = shadowColor ?? AppColors.primaryDark;
    final isDisabled = onPressed == null;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isDisabled ? AppColors.border : bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: shadow,
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDisabled ? AppColors.textHint : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── ChinguTextField ───────────────────────────────────────────────────────────

class ChinguTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscure;
  final TextEditingController controller;

  const ChinguTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
  });

   @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),

        const SizedBox(height: 6),

        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }
}

// ── TopicProgressBar ──────────────────────────────────────────────────────────

class TopicProgressBar extends StatelessWidget {
  final double progress; // 0.0 → 1.0

  const TopicProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ── OnboardingProgress ────────────────────────────────────────────────────────

class OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;

  const OnboardingProgress({
    super.key,
    required this.step,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i + 1 == step;
        final isDone = i + 1 < step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive || isDone ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
