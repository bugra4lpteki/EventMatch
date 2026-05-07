import 'package:flutter/material.dart';

class CustomAppBackground extends StatelessWidget {
  final Widget child;

  const CustomAppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // En alt zemin rengi (Koyu Sıcak Siyah)
        Container(
          color: const Color(0xFF0A0500), // Çok koyu kahve/siyah
        ),
        
        // Işık çizimleri
        Positioned.fill(
          child: CustomPaint(
            painter: SpotlightPainter(),
          ),
        ),

        // Ana içerik
        child,
      ],
    );
  }
}

class SpotlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. IŞIK HÜZMELERİ (BEAMS)
    void drawSpotlight(double topX, double topWidth, double bottomX, double bottomWidth, double opacity) {
      final path = Path()
        ..moveTo(topX - topWidth / 2, -20)
        ..lineTo(topX + topWidth / 2, -20)
        ..lineTo(bottomX + bottomWidth / 2, size.height * 0.85)
        ..lineTo(bottomX - bottomWidth / 2, size.height * 0.85)
        ..close();

      // Işığın yukarıdan aşağıya doğru sönümlenmesi
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFEF3C7).withOpacity(opacity), // Merkez: Sıcak beyaz çekirdek
          const Color(0xFFFDE047).withOpacity(opacity * 0.8), // Orta: Parlak altın sarısı
          const Color(0xFFD97706).withOpacity(opacity * 0.4), // Alt: Amber yayılım
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        // KENAR YUMUŞATMA: Bu sayede keskin üçgenler değil, gerçekçi dağınık bir ışık konisi oluşur
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35); 

      canvas.drawPath(path, paint);
    }

    // Sol Işık
    drawSpotlight(size.width * 0.20, 35, size.width * 0.05, size.width * 0.8, 0.65);
    // Merkez Işık (En Güçlü)
    drawSpotlight(size.width * 0.50, 55, size.width * 0.50, size.width * 1.0, 0.95);
    // Sağ Işık
    drawSpotlight(size.width * 0.80, 35, size.width * 0.95, size.width * 0.8, 0.65);

    // 2. YERDEKİ YAYILAN IŞIK (FLOOR REFLECTION)
    void drawFloorLight(double centerX, double width, double height, double opacity) {
      final rect = Rect.fromCenter(center: Offset(centerX, size.height * 0.85), width: width, height: height);
      final gradient = RadialGradient(
        colors: [
          const Color(0xFFF59E0B).withOpacity(opacity),
          const Color(0xFFB45309).withOpacity(opacity * 0.6),
          Colors.transparent,
        ],
      );
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      
      canvas.drawOval(rect, paint);
    }

    // Yerdeki devasa orta parlaklık (daha geniş ve belirgin)
    drawFloorLight(size.width * 0.5, size.width * 1.2, 160, 0.7);

    // 3. YERDEKİ MİNİK SPOT NOKTALARI (Görseldeki gibi)
    void drawSmallSpot(double x) {
      final rect = Rect.fromCenter(center: Offset(x, size.height * 0.85), width: 30, height: 12);
      final gradient = RadialGradient(
        colors: [
          const Color(0xFFFEF3C7).withOpacity(0.95),
          const Color(0xFFF59E0B).withOpacity(0.6),
          Colors.transparent,
        ],
      );
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawOval(rect, paint);
      
      // Çok minik çekirdek
      final coreRect = Rect.fromCenter(center: Offset(x, size.height * 0.85), width: 8, height: 4);
      final corePaint = Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawOval(coreRect, corePaint);
    }

    // Soldan sağa minik spotlar
    drawSmallSpot(size.width * 0.1);
    drawSmallSpot(size.width * 0.25);
    drawSmallSpot(size.width * 0.4);
    drawSmallSpot(size.width * 0.6);
    drawSmallSpot(size.width * 0.75);
    drawSmallSpot(size.width * 0.9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
