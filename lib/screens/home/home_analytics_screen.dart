import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'package:dashboard/core/services/api_service.dart';

class HomeAnalyticsScreen extends StatefulWidget {
  const HomeAnalyticsScreen({super.key});

  @override
  State<HomeAnalyticsScreen> createState() => _HomeAnalyticsScreenState();
}

class _HomeAnalyticsScreenState extends State<HomeAnalyticsScreen> {
  String _selectedReportType = 'monthly';
  bool _isLoading = true;
  List<dynamic> _revenueTimeline = [];
  Map<String, dynamic> _statsData = {};
  List<dynamic> _savedReports = [];
  List<dynamic> _categoriesAnalytics = [];
  Map<String, dynamic> _paymentMethods = {};
  List<dynamic> _topProducts = [];
  List<dynamic> _lowStockProducts = [];

  final ApiService _apiService = ApiService();
  
  static const String _cacheKeyDashboard = 'cached_dashboard_data';
  static const String _cacheKeyReports = 'cached_reports_data';

  @override
  void initState() {
    super.initState();
    _loadCachedDataOrFetch();
  }

  Future<void> _loadCachedDataOrFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDashboard = prefs.getString(_cacheKeyDashboard);
    final cachedReports = prefs.getString(_cacheKeyReports);

    if (cachedDashboard != null && cachedReports != null) {
      try {
        final data = jsonDecode(cachedDashboard);
        setState(() {
          _revenueTimeline = data['revenue_timeline'] ?? [];
          _statsData = data['overview'] ?? {};
          _categoriesAnalytics = data['categories_breakdown'] ?? [];
          _paymentMethods = data['payment_methods_distribution'] ?? {};
          _topProducts = data['top_performing_products'] ?? [];
          _lowStockProducts = data['low_stock_alert'] ?? [];
          _savedReports = jsonDecode(cachedReports);
          _isLoading = false;
        });
        return;
      } catch (_) {}
    }

    await _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() {
      _isLoading = true;
      
    });

    try {
      final response = await _apiService.dio.get('/analytics/dashboard-pro');
      final reportsResponse = await _apiService.dio.get('/analytics/periodic-reports/history');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyDashboard, jsonEncode(response.data));
      await prefs.setString(_cacheKeyReports, jsonEncode(reportsResponse.data));

      setState(() {
        final data = response.data ?? {};
        _revenueTimeline = data['revenue_timeline'] ?? [];
        _statsData = data['overview'] ?? {};
        _categoriesAnalytics = data['categories_breakdown'] ?? [];
        _paymentMethods = data['payment_methods_distribution'] ?? {};
        _topProducts = data['top_performing_products'] ?? [];
        _lowStockProducts = data['low_stock_alert'] ?? [];
        _savedReports = reportsResponse.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحديث البيانات، تأكد من الاتصال')),
      );
    }
  }

  String _getLocalizedText(dynamic field) {
    if (field is Map) {
      return field['ar'] ?? field.values.firstOrNull?.toString() ?? 'بدون اسم';
    }
    return field?.toString() ?? 'بدون اسم';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? _buildShimmerLoading(isDesktop)
          : RefreshIndicator(
              onRefresh: _fetchAnalyticsData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // العنوان الرئيسي وزر تحديث البيانات
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'لوحة التحكم',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 24 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: _fetchAnalyticsData,
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('تحديث البيانات', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'متابعة أداء النظام، المبيعات، والأرباح الحية',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        ToggleButtons(
                          isSelected: [_selectedReportType == 'weekly', _selectedReportType == 'monthly'],
                          onPressed: (index) {
                            setState(() {
                              _selectedReportType = index == 0 ? 'weekly' : 'monthly';
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          children: const [
                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('أسبوعي')),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('شهري')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 1. شبكة البطاقات المالية والإحصائية
                    GridView.count(
                      crossAxisCount: isDesktop ? 3 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(context, 'المستخدمين المسجلين', '${_statsData['total_users'] ?? 0} مستخدم', Icons.people_outline, Colors.teal),
                        _buildStatCard(context, 'إجمالي المنتجات', '${_statsData['total_products'] ?? 0} منتج', Icons.inventory_2_outlined, Colors.indigo),
                        _buildStatCard(context, 'الطلبات الكلية', '${_statsData['total_orders'] ?? 0} طلب', Icons.shopping_bag_outlined, Colors.orange),
                        _buildStatCard(context, 'إجمالي الإيرادات', '${_statsData['total_revenue'] ?? 0} ل.س', Icons.trending_up, Colors.green),
                        _buildStatCard(context, 'صافي الأرباح', '${_statsData['total_profit'] ?? 0} ل.س', Icons.account_balance_wallet_outlined, Colors.blue),
                        _buildStatCard(context, 'متوسط السلة', '${_statsData['average_order_value'] ?? 0} ل.س', Icons.analytics_outlined, Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 2. الرسوم البيانية وتوزيع طرق الدفع
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildRevenueLineChart(context)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildPaymentMethodsCard(context)),
                        ],
                      )
                    else ...[
                      _buildRevenueLineChart(context),
                      const SizedBox(height: 20),
                      _buildPaymentMethodsCard(context),
                    ],

                    const SizedBox(height: 24),

                    // 3. المنتجات الأكثر مبيعاً وأداء الأقسام (بحد أقصى 10)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildTopProductsCard(context)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildCategoriesPerformanceCard(context)),
                        ],
                      )
                    else ...[
                      _buildTopProductsCard(context),
                      const SizedBox(height: 20),
                      _buildCategoriesPerformanceCard(context),
                    ],

                    const SizedBox(height: 24),

                    // 4. تنبيهات المخزون وأرشيف التقارير (بحد أقصى 10)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildLowStockAlertCard(context)),
                          const SizedBox(width: 24),
                          Expanded(flex: 3, child: _buildSavedPeriodicReportsSection(context)),
                        ],
                      )
                    else ...[
                      _buildLowStockAlertCard(context),
                      const SizedBox(height: 20),
                      _buildSavedPeriodicReportsSection(context),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRevenueLineChart(BuildContext context) {
    final theme = Theme.of(context);
    final List<dynamic> revenueTimeline = _revenueTimeline; // تم التعديل هنا
    List<FlSpot> spots = [];
    double maxRevenue = 0;

    for (int i = 0; i < revenueTimeline.length; i++) {
      final item = revenueTimeline[i];
      final revenue = double.tryParse(item['revenue']?.toString() ?? '0') ?? 0.0;
      if (revenue > maxRevenue) maxRevenue = revenue;
      spots.add(FlSpot(i.toDouble(), revenue));
    }

    if (spots.isEmpty) {
      spots = [const FlSpot(0, 0), const FlSpot(1, 0)];
    }

    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('منحنى تدفق الإيرادات اليومية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('تطور الإيرادات خلال الأيام الأخيرة', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: revenueTimeline.isNotEmpty ? (revenueTimeline.length - 1).toDouble() : 1.0,
                minY: 0,
                maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 1000.0,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < revenueTimeline.length) {
                          String dateStr = revenueTimeline[index]['date'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(dateStr, style: const TextStyle(fontSize: 9)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('توزيع طرق الدفع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('بحسب العمليات المسجلة في النظام', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Expanded(
            child: _paymentMethods.isEmpty
                ? const Center(child: Text('لا توجد بيانات دفع مسجلة', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _paymentMethods.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Chip(
                              label: Text('${entry.value} طلب', style: const TextStyle(fontSize: 11)),
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(BuildContext context) {
    final theme = Theme.of(context);
    final limitedProducts = _topProducts.take(10).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المنتجات الأكثر مبيعاً وإيراداً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('أعلى المنتجات تحقيقيًا للمبيعات (أقصى 10)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Expanded(
            child: limitedProducts.isEmpty
                ? const Center(child: Text('لا توجد مبيعات مسجلة للمنتجات بعد', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: limitedProducts.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final p = limitedProducts[index];
                      final productName = _getLocalizedText(p['name']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            ),
                            Text('${p['sold_count']} مبيعات', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(width: 12),
                            Text('${p['total_product_revenue']} ل.س', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesPerformanceCard(BuildContext context) {
    final theme = Theme.of(context);
    final limitedCategories = _categoriesAnalytics.take(10).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أداء الأقسام الرئيسية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: limitedCategories.isEmpty
                ? const Center(child: Text('لا توجد أقسام مسجلة', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: limitedCategories.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final cat = limitedCategories[index];
                      final catName = _getLocalizedText(cat['category_name']);
                      final productsCount = cat['products_count'] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(catName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('$productsCount منتج', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: productsCount > 0 ? 0.6 : 0.0, minHeight: 5, borderRadius: BorderRadius.circular(4)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlertCard(BuildContext context) {
    final theme = Theme.of(context);
    final limitedLowStock = _lowStockProducts.take(10).toList();

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('تنبيهات المخزون المنخفض', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 4),
          Text('منتجات اقتربت على النفاد (<= 5 قطع)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Expanded(
            child: limitedLowStock.isEmpty
                ? const Center(child: Text('المخزون بحالة ممتازة ولا توجد نواقص', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: limitedLowStock.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = limitedLowStock[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Chip(
                              label: Text('${item['stock_quantity']} متبقي', style: const TextStyle(fontSize: 10, color: Colors.red)),
                              backgroundColor: Colors.red.withOpacity(0.1),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPeriodicReportsSection(BuildContext context) {
    final theme = Theme.of(context);
    final limitedReports = _savedReports.take(10).toList();

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('أرشيف التقارير', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await _apiService.dio.post(
                          '/analytics/periodic-reports/generate-and-save',
                          queryParameters: {'report_type': _selectedReportType},
                        );
                        _fetchAnalyticsData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم توليد التقرير بنجاح وحفظه في الأرشيف')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('خطأ أثناء توليد التقرير')),
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('توليد تقرير', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: الانتقال لصفحة كافة التقارير ReportsListScreen
                    },
                    child: const Text('عرض الكل', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: limitedReports.isEmpty
                ? const Center(child: Text('لا توجد تقارير محفوظة حالياً', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: limitedReports.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final report = limitedReports[index];
                      return InkWell(
                        onTap: () {
                          // TODO: توجيه المستخدم لتفاصيل التقرير
                        },
                        child: _buildReportHistoryItem(
                          report['period_name'] ?? 'تقرير دوري',
                          'مكتمل الأرشيف (${report['report_type'] ?? ''})',
                          report['created_at']?.toString().substring(0, 10) ?? '',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHistoryItem(String title, String subtitle, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 1),
              Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
          Text(date, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // مظهر التحميل باستخدام Shimmer
  Widget _buildShimmerLoading(bool isDesktop) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 200, height: 24, color: Colors.white),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: isDesktop ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: List.generate(6, (index) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
            ),
            const SizedBox(height: 24),
            Container(height: 300, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          ],
        ),
      ),
    );
  }
}