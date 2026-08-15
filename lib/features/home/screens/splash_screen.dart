import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/screens/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Twitter (X) Stili Tam Ekran Ortasında Kompakt Scale (0.75 -> 1.15 -> Zoom Out)
    _scaleAnimation = TweenSequence<double>([
      // 0ms - 450ms: Kibar büyüme (0.75 -> 1.15)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.75, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      // 450ms - 750ms: Kısa yaylanma / Esneme (1.15 -> 1.05)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 20,
      ),
      // 750ms - 1400ms: Ekranı delip geçme (1.05 -> 35.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 35.0)
            .chain(CurveTween(curve: const Cubic(0.7, 0.0, 1.0, 0.5))),
        weight: 45,
      ),
    ]).animate(_controller);

    // Opaklık Geçişi
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 35,
      ),
    ]).animate(_controller);

    // Neon Işıma Darbesi
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 8.0, end: 30.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 30.0, end: 60.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 55,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              );
            },
          ),
        );
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
    return Scaffold(
      backgroundColor: const Color(0xFF08080C),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value.clamp(0.0, 1.0),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.6),
                        blurRadius: _glowAnimation.value,
                        spreadRadius: _glowAnimation.value * 0.2,
                      ),
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.4),
                        blurRadius: _glowAnimation.value * 1.2,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.confirmation_number_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


