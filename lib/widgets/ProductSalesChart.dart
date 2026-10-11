import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProductSalesChart extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductSalesChart({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int stock = product['stock_quantity'] ?? 0;
    final int sold = product['sold_count'] ?? 0;
    final double price = product['price']?.toDouble() ?? 0.0;
    final double totalRevenue = sold * price;

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
          Text(
            'تحليل أداء المنتج (المبيعات والأرباح)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'إجمالي الدخل المتوقع من المبيعات الحالية: $totalRevenue د.أ',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (stock + sold > 0 ? (stock + sold).toDouble() : 10),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('القطع المباعة', style: TextStyle(fontSize: 12));
                          case 1:
                            return const Text('المخزون المتبقي', style: TextStyle(fontSize: 12));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(toY: sold.toDouble(), color: Colors.blue, width: 16, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(toY: stock.toDouble(), color: Colors.orange, width: 16, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}