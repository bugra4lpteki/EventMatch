import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/user_model.dart';

class CandyMachineAvatars extends StatefulWidget {
  final List<UserModel> attendees;
  const CandyMachineAvatars({super.key, required this.attendees});

  @override
  State<CandyMachineAvatars> createState() => _CandyMachineAvatarsState();
}

class _CandyMachineAvatarsState extends State<CandyMachineAvatars> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_CandyBall> _balls = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Initialize balls with random positions and velocities
    for (int i = 0; i < widget.attendees.length.clamp(0, 15); i++) {
      _balls.add(_CandyBall(
        user: widget.attendees[i],
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        vx: (_random.nextDouble() - 0.5) * 0.01,
        vy: (_random.nextDouble() - 0.5) * 0.01,
        rotation: _random.nextDouble() * pi * 2,
      ));
    }
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
        // Update positions
        for (var ball in _balls) {
          ball.x += ball.vx;
          ball.y += ball.vy;

          // Bounce off edges
          if (ball.x <= 0 || ball.x >= 1.0) ball.vx *= -1;
          if (ball.y <= 0 || ball.y >= 1.0) ball.vy *= -1;
          
          ball.x = ball.x.clamp(0.0, 1.0);
          ball.y = ball.y.clamp(0.0, 1.0);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: _balls.map((ball) {
                return Positioned(
                  left: ball.x * (constraints.maxWidth - 34),
                  top: ball.y * (constraints.maxHeight - 34),
                  child: Transform.rotate(
                    angle: ball.rotation + (_controller.value * pi * 2 * ball.vx * 10),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 6,
                            offset: const Offset(1, 2),
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: ball.user.avatarUrl.startsWith('http')
                            ? Image.network(ball.user.avatarUrl, fit: BoxFit.cover)
                            : Image.asset(ball.user.avatarUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _CandyBall {
  final UserModel user;
  double x;
  double y;
  double vx;
  double vy;
  double rotation;

  _CandyBall({
    required this.user,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
  });
}
