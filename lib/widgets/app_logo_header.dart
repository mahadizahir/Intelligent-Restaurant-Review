import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.restaurant,
            color: AppColors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Intelligent Restaurant Review System',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in to explore restaurants or manage your business',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.grey,
          ),
        ),
      ],
    );
  }
}