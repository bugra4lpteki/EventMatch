import 'dart:math' as math;
import 'package:flutter/material.dart';

/// EventMatch'e özel, WhatsApp tarzı zarif doodle sohbet arka planı
class ChatWallpaperBackground extends StatelessWidget {
  const ChatWallpaperBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF090A10),
              Color(0xFF0E101A),
              Color(0xFF131524),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Yumuşak merkez mor/pembe neon ışıltısı
            Positioned(
              top: 150,
              left: 40,
              right: 40,
              height: 350,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                      const Color(0xFFEC4899).withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Tuvallenen EventMatch doodle sembolleri
            const RepaintBoundary(
              child: CustomPaint(
                painter: _EventMatchDoodlePainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMatchDoodlePainter extends CustomPainter {
  const _EventMatchDoodlePainter();

  static const List<IconData> _doodleIcons = [
    Icons.local_fire_department_rounded, // Match ateşi
    Icons.confirmation_number_outlined,  // Etkinlik bileti
    Icons.favorite_rounded,              // Kalp
    Icons.music_note_rounded,            // Müzik / Konser
    Icons.local_bar_rounded,             // İçecek / Buluşma
    Icons.location_on_outlined,          // Harita pini
    Icons.auto_awesome_rounded,          // Parıltı / Keşif
    Icons.chat_bubble_outline_rounded,   // Sohbet
    Icons.coffee_rounded,                // Kahve buluşması
    Icons.theater_comedy_rounded,        // Tiyatro / Kültür
    Icons.headphones_rounded,            // Parti / Müzik
    Icons.celebration_outlined,          // Festival / Kutlama
    Icons.camera_alt_outlined,           // Fotoğraf
    Icons.sports_basketball_rounded,     // Spor etkinliği
    Icons.star_rounded,                  // Yıldız
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    const double cellSize = 68.0;
    final int cols = (size.width / cellSize).ceil() + 1;
    final int rows = (size.height / cellSize).ceil() + 1;

    final baseColor = Colors.white.withValues(alpha: 0.038);
    final accentColor = const Color(0xFFC084FC).withValues(alpha: 0.045);

    int iconIndex = 0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Çapraz hafif kayma (WhatsApp grid stili)
        final double xOffset = (r % 2 == 1) ? cellSize * 0.5 : 0.0;
        final double cx = c * cellSize + xOffset;
        final double cy = r * cellSize;

        final icon = _doodleIcons[iconIndex % _doodleIcons.length];
        final bool isAccent = (iconIndex % 4 == 0);
        final color = isAccent ? accentColor : baseColor;

        // Hafif dinamik rotasyon (-18° ile +18° arası)
        final double rotation = ((iconIndex * 7) % 36 - 18) * (math.pi / 180);

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(rotation);

        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: 20,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );

        canvas.restore();
        iconIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
