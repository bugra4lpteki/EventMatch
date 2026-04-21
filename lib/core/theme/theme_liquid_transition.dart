import 'dart:math' as math;
import 'package:flutter/material.dart';

class ThemeLiquidTransition extends StatefulWidget {
  final Color color;
  final VoidCallback onMidpoint;
  final VoidCallback onComplete;

  const ThemeLiquidTransition({
    super.key,
    required this.color,
    required this.onMidpoint,
    required this.onComplete,
  });

  @override
  State<ThemeLiquidTransition> createState() => _ThemeLiquidTransitionState();
}

class _ThemeLiquidTransitionState extends State<ThemeLiquidTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _midpointReached = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _controller.addListener(() {
      if (!_midpointReached && _controller.value >= 0.5) {
        _midpointReached = true;
        widget.onMidpoint();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Phase 1 (0.0 → 0.5): Liquid pours DOWN — covering screen
        // Phase 2 (0.5 → 1.0): Liquid drains UP — revealing new theme
        final double rawProgress = _controller.value;
        final double liquidLevel = rawProgress <= 0.5
            ? rawProgress * 2 // 0.0 → 1.0
            : 1.0 - (rawProgress - 0.5) * 2; // 1.0 → 0.0

        // Wave oscillates continuously throughout the animation
        final double wavePhase = rawProgress * 4 * math.pi;

        return ClipPath(
          clipper: _WavyClipper(level: liquidLevel, phase: wavePhase),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.color,
                  widget.color.withOpacity(0.85),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavyClipper extends CustomClipper<Path> {
  final double level; // 0.0 = empty top, 1.0 = full screen
  final double phase; // wave phase offset

  _WavyClipper({required this.level, required this.phase});

  @override
  Path getClip(Size size) {
    final path = Path();
    final liquidY = level * size.height;

    if (liquidY <= 0) return Path();

    path.moveTo(0, 0);
    path.lineTo(0, liquidY);

    // Draw sinusoidal wave edge
    for (double x = 0; x <= size.width; x += 1) {
      final y = liquidY + 18 * math.sin((x / size.width * 2 * math.pi) + phase);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_WavyClipper oldClipper) {
    return oldClipper.level != level || oldClipper.phase != phase;
  }
}
