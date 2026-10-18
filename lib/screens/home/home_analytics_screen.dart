import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'package:dashboard/core/services/api_service.dart';

// استيراد شاشة قراءة التقرير التحليلي للذكاء الاصطناعي
import 'analytics/ai_report_reader_screen.dart';

// --- دالة عامة موحدة لفتح التقارير (خارج الكلاسات لتجنب أخطاء الـ static) ---
void _openReport(BuildContext context, Map<String, dynamic> report) {
  final metrics = report['metrics'] is Map
      ? report['metrics'] as Map<String, dynamic>
      : {};

  final String? aiReportText = metrics['report'] ??
      metrics['report_text'] ??
      metrics['summary'] ??
      metrics['ai_analysis'] ??
      report['report'] ??
      report['report_text'] ??
      report['summary'];

  // إذا كان التقرير من نوع search_insights أو يحتوي على نص ذكاء اصطناعي
  if (report['report_type'] == 'search_insights' || aiReportText != null) {
    String finalReportContent = '';
    if (aiReportText != null && aiReportText.isNotEmpty) {
      finalReportContent = aiReportText;
    } else {
      final topItems = metrics['top_searched_items'] is List ? metrics['top_searched_items'] as List : [];
      final totalQueries = metrics['total_analyzed_queries'] ?? 0;
      final failedVolume = metrics['total_failed_searches_volume'] ?? 0;
      final periodName = report['period_name'] ?? 'تقرير ذكاء البحث';

      StringBuffer sb = StringBuffer();
      sb.writeln('📋 $periodName');
      sb.writeln('==================================================');
      sb.writeln('• إجمالي عمليات البحث والتحليل: $totalQueries');
      sb.writeln('• حجم عمليات البحث التي لم تسفر عن نتائج مباشرة: $failedVolume');
      sb.writeln('\n🔍 أبرز كلمات وطلبات البحث المسجلة من الزبائن:');

      if (topItems.isEmpty) {
        sb.writeln('- لا توجد طلبات بحث مسجلة في هذه الفترة.');
      } else {
        for (int i = 0; i < topItems.length; i++) {
          final item = topItems[i];
          final query = item['query'] ?? 'غير معروف';
          final count = item['count'] ?? 1;
          sb.writeln('${i + 1}. "$query" (تكرار الطلب: $count مرات)');
        }
      }

      sb.writeln('\n==================================================');
      sb.writeln('💡 توصيات واستراتيجيات مقترحة للمتجر:');
      sb.writeln('1. توفير الأصناف والمنتجات الأكثر بحثاً والتي لم تجد نتائج لتقليل الفاقد من العملاء.');
      sb.writeln('2. تحسين الكلمات الدلالية وأسماء المنتجات الحالية لتتوافق مع المصطلحات التي يستخدمها الزبائن في البحث.');
      sb.writeln('3. دراسة إضافة أقسام وعروض مخصصة بناءً على توجهات ونشاط عمليات البحث الأخيرة.');
      
      finalReportContent = sb.toString();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiReportReaderScreen(
          reportItem: {
            'id': report['id'] ?? '',
            'date': report['created_at'] ?? report['start_date'] ?? '',
            'model_used': metrics['model_used'] ?? report['model_used'] ?? 'Gemini AI',
            'cleared_count': metrics['total_analyzed_queries'] ?? metrics['cleared_count'] ?? 0,
            'report': finalReportContent,
          },
          onDelete: () {},
        ),
      ),
    );
  } else {
    // للتقارير الشهرية والأسبوعية والدورية الأخرى، يتم فتح شاشة تفاصيل الإحصائيات والأرقام
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ReportDetailScreen(report: report)),
    );
  }
}

class AllReportsScreen extends StatelessWidget {
  final List<dynamic> reports;
  const AllReportsScreen({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar:
          AppBar(title: const Text('أرشيف التقارير الكامل'), centerTitle: true),
      body: reports.isEmpty
          ? const Center(
              child: Text('لا توجد تقارير محفوظة حالياً',
                  style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.08)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      title: Text(report['period_name'] ?? 'تقرير دوري',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            'النوع: ${report['report_type']}  •  التاريخ: ${report['created_at']?.toString().substring(0, 10)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ),
                      trailing:
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () => _openReport(context, report),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = report['metrics'] ?? {};

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
          title: Text(report['period_name'] ?? 'تفاصيل التقرير'),
          centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نوع التقرير: ${report['report_type']}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      'فترة التقرير: من ${report['start_date']?.toString().substring(0, 10)} إلى ${report['end_date']?.toString().substring(0, 10)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('الإحصائيات والقياسات المسجلة:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.08)),
              ),
              child: Column(
                children: metrics.entries.map<Widget>((e) {
                  if (e.key == 'status_breakdown' || e.key == 'report')
                    return const SizedBox.shrink();

                  String displayValue = e.value.toString();
                  if (e.value is List) {
                    final list = e.value as List;
                    displayValue = '${list.length} عناصر مسجلة';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13))),
                        const SizedBox(width: 12),
                        Text(displayValue,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 14)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  List<dynamic> _topOffers = [];
  List<dynamic> _topGroups = [];
  List<dynamic> _topSearchedItems = [];

  final ApiService _apiService = ApiService();

  static const String _cacheKeyDashboard = 'cached_dashboard_data';
  static const String _cacheKeyReports = 'cached_reports_data';
  static const String _cacheKeyInsights = 'cached_insights_data';

  @override
  void initState() {
    super.initState();
    _loadCachedDataOrFetch();
  }

  Future<void> _loadCachedDataOrFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDashboard = prefs.getString(_cacheKeyDashboard);
    final cachedReports = prefs.getString(_cacheKeyReports);
    final cachedInsights = prefs.getString(_cacheKeyInsights);

    if (cachedDashboard != null && cachedReports != null) {
      try {
        final data = jsonDecode(cachedDashboard);
        final insights =
            cachedInsights != null ? jsonDecode(cachedInsights) : {};
        setState(() {
          _revenueTimeline = data['revenue_timeline'] ?? [];
          _statsData = data['overview'] ?? {};
          _categoriesAnalytics = data['categories_breakdown'] ?? [];
          _paymentMethods = data['payment_methods_distribution'] ?? {};
          _topProducts = data['top_performing_products'] ?? [];
          _lowStockProducts = data['low_stock_alert'] ?? [];
          _savedReports = jsonDecode(cachedReports);
          _topOffers = insights['top_offers'] ?? [];
          _topGroups = insights['top_groups'] ?? [];
          _topSearchedItems = insights['top_searched_items'] ?? [];
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
      final reportsResponse =
          await _apiService.dio.get('/analytics/periodic-reports/history');
      final insightsResponse =
          await _apiService.dio.get('/analytics/offers-groups-insights');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyDashboard, jsonEncode(response.data));
      await prefs.setString(_cacheKeyReports, jsonEncode(reportsResponse.data));
      await prefs.setString(
          _cacheKeyInsights, jsonEncode(insightsResponse.data));

      setState(() {
        final data = response.data ?? {};
        final insights = insightsResponse.data ?? {};
        _revenueTimeline = data['revenue_timeline'] ?? [];
        _statsData = data['overview'] ?? {};
        _categoriesAnalytics = data['categories_breakdown'] ?? [];
        _paymentMethods = data['payment_methods_distribution'] ?? {};
        _topProducts = data['top_performing_products'] ?? [];
        _lowStockProducts = data['low_stock_alert'] ?? [];
        _savedReports = reportsResponse.data ?? [];
        _topOffers = insights['top_offers'] ?? [];
        _topGroups = insights['top_groups'] ?? [];
        _topSearchedItems = insights['top_searched_items'] ?? [];
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
                                    label: const Text('تحديث البيانات',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'متابعة أداء النظام، المبيعات، والعروض الحية',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        ToggleButtons(
                          isSelected: [
                            _selectedReportType == 'weekly',
                            _selectedReportType == 'monthly'
                          ],
                          onPressed: (index) {
                            setState(() {
                              _selectedReportType =
                                  index == 0 ? 'weekly' : 'monthly';
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          children: const [
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('أسبوعي')),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('شهري')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 1. البطاقات المالية والإحصائية
                    GridView.count(
                      crossAxisCount: isDesktop ? 3 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                            context,
                            'المستخدمين المسجلين',
                            '${_statsData['total_users'] ?? 0} مستخدم',
                            Icons.people_outline,
                            Colors.teal),
                        _buildStatCard(
                            context,
                            'إجمالي المنتجات',
                            '${_statsData['total_products'] ?? 0} منتج',
                            Icons.inventory_2_outlined,
                            Colors.indigo),
                        _buildStatCard(
                            context,
                            'الطلبات الكلية',
                            '${_statsData['total_orders'] ?? 0} طلب',
                            Icons.shopping_bag_outlined,
                            Colors.orange),
                        _buildStatCard(
                            context,
                            'إجمالي الإيرادات',
                            '${_statsData['total_revenue'] ?? 0} ل.س',
                            Icons.trending_up,
                            Colors.green),
                        _buildStatCard(
                            context,
                            'صافي الأرباح',
                            '${_statsData['total_profit'] ?? 0} ل.س',
                            Icons.account_balance_wallet_outlined,
                            Colors.blue),
                        _buildStatCard(
                            context,
                            'متوسط السلة',
                            '${_statsData['average_order_value'] ?? 0} ل.س',
                            Icons.analytics_outlined,
                            Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 2. تحليل العروض والمجموعات
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildOffersInsightsCard(context)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildGroupsInsightsCard(context)),
                        ],
                      )
                    else ...[
                      _buildOffersInsightsCard(context),
                      const SizedBox(height: 20),
                      _buildGroupsInsightsCard(context),
                    ],

                    const SizedBox(height: 24),

                    // 3. الرسم البياني للإيرادات وتوزيع طرق الدفع
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 3, child: _buildRevenueLineChart(context)),
                          const SizedBox(width: 24),
                          Expanded(
                              flex: 2,
                              child: _buildPaymentMethodsPieChart(context)),
                        ],
                      )
                    else ...[
                      _buildRevenueLineChart(context),
                      const SizedBox(height: 20),
                      _buildPaymentMethodsPieChart(context),
                    ],

                    const SizedBox(height: 24),

                    // 4. المنتجات الأكثر مبيعاً وأداء الأقسام
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 3, child: _buildTopProductsCard(context)),
                          const SizedBox(width: 24),
                          Expanded(
                              flex: 2,
                              child: _buildCategoriesPerformanceCard(context)),
                        ],
                      )
                    else ...[
                      _buildTopProductsCard(context),
                      const SizedBox(height: 20),
                      _buildCategoriesPerformanceCard(context),
                    ],

                    const SizedBox(height: 24),

                    // 5. تنبيهات المخزون، كلمات البحث بدون نتائج، وأرشيف التقارير
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 2, child: _buildLowStockAlertCard(context)),
                          const SizedBox(width: 24),
                          Expanded(
                              flex: 2,
                              child: _buildSearchInsightsCard(context)),
                          const SizedBox(width: 24),
                          Expanded(
                              flex: 3,
                              child:
                                  _buildSavedPeriodicReportsSection(context)),
                        ],
                      )
                    else ...[
                      _buildLowStockAlertCard(context),
                      const SizedBox(height: 20),
                      _buildSearchInsightsCard(context),
                      const SizedBox(height: 20),
                      _buildSavedPeriodicReportsSection(context),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
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
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildOffersInsightsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_offer_outlined, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text('أداء العروض الأكثر طلباً',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _topOffers.isEmpty
                ? const Center(
                    child: Text('لا توجد مبيعات للعروض حالياً',
                        style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: _topOffers.length > 5 ? 5 : _topOffers.length,
                    itemBuilder: (context, index) {
                      final offer = _topOffers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(_getLocalizedText(offer['name']),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis)),
                            Text('${offer['units_sold']} مبيع',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            const SizedBox(width: 8),
                            Text('${offer['total_revenue']} ل.س',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
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

  Widget _buildGroupsInsightsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group_work_outlined, color: Colors.purple, size: 20),
              SizedBox(width: 8),
              Text('أداء المجموعات الأكثر طلباً',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _topGroups.isEmpty
                ? const Center(
                    child: Text('لا توجد مبيعات للمجموعات حالياً',
                        style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: _topGroups.length > 5 ? 5 : _topGroups.length,
                    itemBuilder: (context, index) {
                      final group = _topGroups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(_getLocalizedText(group['name']),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis)),
                            Text('${group['units_sold']} مبيع',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            const SizedBox(width: 8),
                            Text('${group['total_revenue']} ل.س',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
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

  Widget _buildRevenueLineChart(BuildContext context) {
    final theme = Theme.of(context);
    List<FlSpot> spots = [];
    double maxRevenue = 0;

    for (int i = 0; i < _revenueTimeline.length; i++) {
      final item = _revenueTimeline[i];
      final revenue =
          double.tryParse(item['revenue']?.toString() ?? '0') ?? 0.0;
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
          const Text('منحنى تدفق الإيرادات اليومية',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('تطور الإيرادات خلال الأيام الأخيرة',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: _revenueTimeline.isNotEmpty
                    ? (_revenueTimeline.length - 1).toDouble()
                    : 1.0,
                minY: 0,
                maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 1000.0,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(0)}k'
                              : value.toStringAsFixed(0),
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
                        if (index >= 0 && index < _revenueTimeline.length) {
                          String dateStr =
                              _revenueTimeline[index]['date'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(dateStr,
                                style: const TextStyle(fontSize: 9)),
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

  Widget _buildPaymentMethodsPieChart(BuildContext context) {
    final theme = Theme.of(context);
    final colorsList = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink
    ];

    int i = 0;
    List<PieChartSectionData> sections = _paymentMethods.entries.map((entry) {
      final color = colorsList[i % colorsList.length];
      i++;
      double val = double.tryParse(entry.value.toString()) ?? 0;
      return PieChartSectionData(
        color: color,
        value: val > 0 ? val : 1,
        title: '${entry.value}',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

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
          const Text('توزيع طرق الدفع',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('نسبة استخدام طرق الدفع المختلفة',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Expanded(
            child: _paymentMethods.isEmpty
                ? const Center(
                    child: Text('لا توجد بيانات دفع مسجلة',
                        style: TextStyle(fontSize: 12, color: Colors.grey)))
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 35,
                            sections: sections,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _paymentMethods.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.purple)),
                                const SizedBox(width: 6),
                                Text('${e.key} (${e.value})',
                                    style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInsightsCard(BuildContext context) {
    final theme = Theme.of(context);
    final limitedSearches = _topSearchedItems.take(5).toList();

    double maxCount = 1;
    for (var item in limitedSearches) {
      double c = double.tryParse(item['count']?.toString() ?? '1') ?? 1;
      if (c > maxCount) maxCount = c;
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.search_off_rounded, color: Colors.purple, size: 20),
              SizedBox(width: 8),
              Text('أبرز كلمات البحث التي بلا نتائج',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('طلبات البحث الأكثر تكراراً المفقودة من المتجر',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Expanded(
            child: limitedSearches.isEmpty
                ? const Center(
                    child: Text('لا توجد بيانات بحث تحليلي حالياً',
                        style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: limitedSearches.length,
                    itemBuilder: (context, index) {
                      final item = limitedSearches[index];
                      final queryStr = item['query']?.toString() ?? 'غير محدد';
                      final countVal =
                          int.tryParse(item['count']?.toString() ?? '1') ?? 1;
                      final progress = (countVal / maxCount).clamp(0.05, 1.0);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    queryStr,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$countVal بحث',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.purple,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor:
                                    Colors.purple.withOpacity(0.06),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.purple),
                              ),
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
          const Text('المنتجات الأكثر مبيعاً وإيراداً',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('أعلى المنتجات تحقيقيًا للمبيعات (أقصى 10)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Expanded(
            child: limitedProducts.isEmpty
                ? const Center(
                    child: Text('لا توجد مبيعات مسجلة للمنتجات بعد',
                        style: TextStyle(fontSize: 12, color: Colors.grey)))
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
                                child: Text(productName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis)),
                            Text('${p['sold_count']} مبيعات',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(width: 12),
                            Text('${p['total_product_revenue']} ل.س',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary)),
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
          const Text('أداء الأقسام الرئيسية',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: limitedCategories.isEmpty
                ? const Center(
                    child: Text('لا توجد أقسام مسجلة',
                        style: TextStyle(fontSize: 12, color: Colors.grey)))
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
                                Text(catName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                Text('$productsCount منتج',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                                value: productsCount > 0 ? 0.6 : 0.0,
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(4)),
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
              Text('تنبيهات المخزون المنخفض',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ],
          ),
          const SizedBox(height: 4),
          Text('منتجات اقتربت على النفاد (<= 5 قطع)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Expanded(
            child: limitedLowStock.isEmpty
                ? const Center(
                    child: Text('المخزون بحالة ممتازة ولا توجد نواقص',
                        style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: limitedLowStock.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = limitedLowStock[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_getLocalizedText(item['name']),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            Chip(
                              label: Text('${item['stock_quantity']} متبقي',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.red)),
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
              const Text('أرشيف التقارير',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                          const SnackBar(
                              content: Text(
                                  'تم توليد التقرير بنجاح وحفظه في الأرشيف')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('خطأ أثناء توليد التقرير')),
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('توليد تقرير',
                        style: TextStyle(fontSize: 11)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                AllReportsScreen(reports: _savedReports)),
                      );
                    },
                    child:
                        const Text('عرض الكل', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: limitedReports.isEmpty
                ? const Center(
                    child: Text('لا توجد تقارير محفوظة حالياً',
                        style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: limitedReports.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final report = limitedReports[index];
                      return InkWell(
                        onTap: () => _openReport(context, report),
                        child: _buildReportHistoryItem(
                          report['period_name'] ?? 'تقرير دوري',
                          'مكتمل الأرشيف (${report['report_type'] ?? ''})',
                          report['created_at']?.toString().substring(0, 10) ??
                              '',
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
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 1),
              Text(subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
          Text(date, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

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
              children: List.generate(
                  6,
                  (index) => Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)))),
            ),
            const SizedBox(height: 24),
            Container(
                height: 300,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16))),
          ],
        ),
      ),
    );
  }
}