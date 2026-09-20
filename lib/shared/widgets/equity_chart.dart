import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/shared/models/models.dart';

class EquityChart extends StatelessWidget {
  const EquityChart({
    super.key,
    required this.points,
    this.emptyLabel = 'No trades taken',
    this.lineColor = AppColors.primary,
  });
  final List<EquityPoint> points;
  final String emptyLabel;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: 180,
        child: CustomPaint(
          painter: _ChartGridPainter(),
          child: Center(
            child: Text(
              emptyLabel,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ),
        ),
      );
    }
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].equity),
    ];
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border.withValues(alpha: 0.7),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (_) => FlLine(
              color: AppColors.border.withValues(alpha: 0.45),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (items) => items
                  .map(
                    (s) => LineTooltipItem(
                      s.y.toStringAsFixed(2),
                      const TextStyle(color: AppColors.text),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var i = 1; i <= 5; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
