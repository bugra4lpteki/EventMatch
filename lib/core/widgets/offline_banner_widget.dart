import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class OfflineBannerWidget extends StatelessWidget {
  final bool isOffline;
  final VoidCallback? onRetry;

  const OfflineBannerWidget({
    super.key,
    required this.isOffline,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'İnternet bağlantısı kesildi. Çevrimdışı moddasınız.',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Yenile',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
