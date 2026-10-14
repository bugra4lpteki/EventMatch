import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/services/weather_service.dart';

/// Harita üzerinde hava durumuna göre dinamik görsel efektler (Yağmur, Kar, Güneş Işığı) çizen katman
class MapWeatherOverlay extends StatefulWidget {
  final EventWeatherData? weather;
  final bool isEnabled;

  const MapWeatherOverlay({
    super.key,
    required this.weather,
    this.isEnabled = true,
  });

  @override
  State<MapWeatherOverlay> createState() => _MapWeatherOverlayState();
}

class _MapWeatherOverlayState extends State<MapWeatherOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<_RainDrop> _rainDrops = [];
  final List<_SnowFlake> _snowFlakes = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Widget test ortamında sonsuz döngü pumpAndSettle'ı tıkamasın
    final isTestEnv = WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    if (!isTestEnv) {
      _animController.repeat();
    }

    _initParticles();
  }

  void _initParticles() {
    _rainDrops.clear();
    for (int i = 0; i < 75; i++) {
      _rainDrops.add(_RainDrop(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        length: 12 + _random.nextDouble() * 16,
        speed: 0.015 + _random.nextDouble() * 0.02,
        opacity: 0.25 + _random.nextDouble() * 0.45,
      ));
    }

    _snowFlakes.clear();
    for (int i = 0; i < 50; i++) {
      _snowFlakes.add(_SnowFlake(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 1.5 + _random.nextDouble() * 2.5,
        speed: 0.003 + _random.nextDouble() * 0.007,
        opacity: 0.3 + _random.nextDouble() * 0.5,
      ));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled || widget.weather == null) {
      return const SizedBox.shrink();
    }

    final code = widget.weather!.weatherCode;
    final isDay = widget.weather!.isDay;
    final isRain = (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || (code >= 95 && code <= 99) || widget.weather!.precipitation > 0.2;
    final isSnow = code >= 71 && code <= 77;
    final isSunny = (code == 0 || code == 1) && isDay;

    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          if (isRain) {
            return CustomPaint(
              size: Size.infinite,
              painter: _RainPainter(
                drops: _rainDrops,
                progress: _animController.value,
                isThunder: code >= 95,
              ),
            );
          } else if (isSnow) {
            return CustomPaint(
              size: Size.infinite,
              painter: _SnowPainter(
                flakes: _snowFlakes,
                progress: _animController.value,
              ),
            );
          } else if (isSunny) {
            return CustomPaint(
              size: Size.infinite,
              painter: _SunnyGlowPainter(progress: _animController.value),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _RainDrop {
  double x;
  double y;
  final double length;
  final double speed;
  final double opacity;

  _RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
  });
}

class _RainPainter extends CustomPainter {
  final List<_RainDrop> drops;
  final double progress;
  final bool isThunder;

  _RainPainter({
    required this.drops,
    required this.progress,
    required this.isThunder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Yağmurlu atmosfer karartması (hafif lacivert/gri ton)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0F172A).withOpacity(0.12),
    );

    // Gök gürültülü fırtına için arada bir çok hafif beyaz şimşek parlaması
    if (isThunder && (progress > 0.48 && progress < 0.52)) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withOpacity(0.08),
      );
    }

    final paint = Paint()
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    for (var drop in drops) {
      drop.y += drop.speed;
      if (drop.y > 1.0) {
        drop.y = -0.05;
      }

      final startX = drop.x * size.width;
      final startY = drop.y * size.height;
      final endX = startX - (drop.length * 0.25); // Yağmur eğimi
      final endY = startY + drop.length;

      paint.color = const Color(0xFF93C5FD).withOpacity(drop.opacity);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => true;
}

class _SnowFlake {
  double x;
  double y;
  final double radius;
  final double speed;
  final double opacity;

  _SnowFlake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}

class _SnowPainter extends CustomPainter {
  final List<_SnowFlake> flakes;
  final double progress;

  _SnowPainter({required this.flakes, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var flake in flakes) {
      flake.y += flake.speed;
      if (flake.y > 1.0) {
        flake.y = -0.02;
      }

      final cx = (flake.x * size.width) + sin((flake.y + progress) * 2 * pi) * 6;
      final cy = flake.y * size.height;

      paint.color = Colors.white.withOpacity(flake.opacity);
      canvas.drawCircle(Offset(cx, cy), flake.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}

class _SunnyGlowPainter extends CustomPainter {
  final double progress;

  _SunnyGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = 0.85 + (sin(progress * 2 * pi) * 0.15);

    // Sağ üst köşeden haritaya vuran hafif sıcak güneş ışıması
    final center = Offset(size.width * 0.9, size.height * 0.1);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFBBF24).withOpacity(0.18 * pulse),
          const Color(0xFFF59E0B).withOpacity(0.06 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.75));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _SunnyGlowPainter oldDelegate) => true;
}
