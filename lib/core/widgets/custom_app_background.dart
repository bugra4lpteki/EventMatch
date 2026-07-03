import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomAppBackground extends StatelessWidget {
  final Widget child;

  const CustomAppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: child,
    );
  }
}
