import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/screens/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 1.5 saniye bekleyip su gibi dökülme animasyonuyla AuthWrapper'a geç
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          LiquidPageRoute(page: const AuthWrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Başlangıçta tam ekran splash görünüyor
      body: LiquidPageRoute.buildSplashContent(context),
    );
  }
}

class LiquidPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  LiquidPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 2000),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation, 
              // Su akışına benzemesi için yavaşça hızlanan ve yavaşlayan bir curve
              curve: Curves.easeInOutSine, 
            );

            return Stack(
              children: [
                child, // Arka planda açılan asıl sayfa (HomeScreen)

                // Yukarıdan aşağıya su gibi eriyen / dökülen Splash Ekranı
                AnimatedBuilder(
                  animation: curvedAnimation,
                  builder: (context, child) {
                    if (curvedAnimation.isCompleted) return const SizedBox.shrink();
                    return ClipPath(
                      clipper: LiquidClipper(curvedAnimation.value),
                      child: child,
                    );
                  },
                  child: buildSplashContent(context),
                ),
              ],
            );
          },
        );

  static Widget buildSplashContent(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration, color: AppColors.primary, size: 48),
            const SizedBox(height: 24),
            Text(
              'EventMatch',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: AppColors.primary.withOpacity(0.8),
                    blurRadius: 25,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'En iyi etkinlikleri keşfet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiquidClipper extends CustomClipper<Path> {
  final double value; // 0.0'dan 1.0'a gider

  LiquidClipper(this.value);

  @override
  Path getClip(Size size) {
    final path = Path();
    
    double waveHeight = 25.0; // Dalga yüksekliği
    // value=0 iken ekranın tamamen üstünde (-), value=1 iken tamamen altında (+)
    double top = -waveHeight * 2 + (size.height + waveHeight * 4) * value;

    path.moveTo(0, top);
    
    // Su dalgası şeklini çizen döngü
    for (double i = 0; i <= size.width; i += 2) {
      // Değer (value) ile dalganın sağa doğru kaymasını da sağlıyoruz
      double waveOffset = math.sin((i / size.width * 2 * math.pi) + (value * 15 * math.pi)) * waveHeight;
      path.lineTo(i, top + waveOffset);
    }
    
    // Dalganın altındaki her şeyi (splash ekranını) tut, üsttekileri (ana sayfayı gösterecek kısmı) kes
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant LiquidClipper oldClipper) {
    return oldClipper.value != value;
  }
}
