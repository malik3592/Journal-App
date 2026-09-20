import 'package:flutter/material.dart';
import 'package:journal/app/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, color: AppColors.gold, size: 48),
            SizedBox(height: 12),
            Text(
              'Trading Journal',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Track · Analyze · Improve',
              style: TextStyle(color: AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
