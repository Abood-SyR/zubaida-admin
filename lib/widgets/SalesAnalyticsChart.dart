import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesAnalyticsChart extends StatelessWidget {
  const SalesAnalyticsChart({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إحصائيات الأرباح والقطع المباعة أسبوعياً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(days[value.toInt()], style: const TextStyle(fontSize: 11));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, 30, 50),
                  _makeBarGroup(1, 45, 70),
                  _makeBarGroup(2, 20, 40),
                  _makeBarGroup(3, 60, 90),
                  _makeBarGroup(4, 50, 65),
                  _makeBarGroup(5, 80, 100),
                  _makeBarGroup(6, 40, 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double soldPieces, double profits) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: soldPieces, color: Colors.orange, width: 7, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: profits, color: Colors.green, width: 7, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }
}