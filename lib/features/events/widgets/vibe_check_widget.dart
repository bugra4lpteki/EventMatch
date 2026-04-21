import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class VibeCheckWidget extends StatelessWidget {
  final int score;
  final List<String> commonalities;
  final bool compact;

  const VibeCheckWidget({
    super.key,
    required this.score,
    required this.commonalities,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '%$score Vibe',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ORTAK NOKTALAR',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ],
          ),
          if (commonalities.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...commonalities.take(compact ? 1 : 3).map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.primary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
