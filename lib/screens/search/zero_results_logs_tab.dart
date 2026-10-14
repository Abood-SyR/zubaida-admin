import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/search_management_service.dart';
import 'ai_reports_history_screen.dart';

class ZeroResultsLogsTab extends StatefulWidget {
  final List<dynamic> zeroResultsLogs;
  final ValueChanged<List<dynamic>> onLogsUpdated;
  final Function(String) showLoadingDialog;
  final VoidCallback hideLoadingDialog;

  const ZeroResultsLogsTab({
    super.key,
    required this.zeroResultsLogs,
    required this.onLogsUpdated,
    required this.showLoadingDialog,
    required this.hideLoadingDialog,
  });

  @override
  State<ZeroResultsLogsTab> createState() => _ZeroResultsLogsTabState();
}

class _ZeroResultsLogsTabState extends State<ZeroResultsLogsTab> {
  final TextEditingController _zeroLogSearchQueryController = TextEditingController();
  String _zeroLogSearchQuery = '';
  
  // متغيرات خاصة بالتحميل التدريجي (Pagination) لمنع التهنيج
  final ScrollController _scrollController = ScrollController();
  int _displayLimit = 10;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _zeroLogSearchQueryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // التحقق عند الوصول إلى القاع تقريباً لتحميل المزيد تدريجياً
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // التأكد من عدم تجاوز إجمالي عدد العناصر المتاحة
      final filteredLength = widget.zeroResultsLogs.where((l) {
        if (_zeroLogSearchQuery.isEmpty) return true;
        final queryText = (l['search_query'] ?? '').toLowerCase();
        return queryText.contains(_zeroLogSearchQuery.toLowerCase());
      }).length;

      if (_displayLimit < filteredLength) {
        setState(() {
          _displayLimit += _pageSize;
        });
      }
    }
  }

  Future<void> _deleteZeroLog(String id) async {
    widget.showLoadingDialog('جاري مسح السجل...');
    bool success = await SearchManagementService.deleteZeroResultLog(id);
    widget.hideLoadingDialog();

    if (success) {
      final updated = widget.zeroResultsLogs.where((l) => l['id']?.toString() != id).toList();
      widget.onLogsUpdated(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح السجل بنجاح'), backgroundColor: Colors.green),
      );
    }
  }

  // دالة ذكية لترجمة وتحويل أخطاء الخادم والذكاء الاصطناعي إلى رسائل واضحة بالعربية
  String _translateServerErrorMessage(dynamic rawError) {
    String errStr = rawError.toString().toLowerCase();

    if (errStr.contains('quota') || errStr.contains('limit') || errStr.contains('exceeded')) {
      return 'تم تجاوز حد الاستخدام المسموح (Quota Exceeded). يجدر بك الانتظار قليلاً أو مراجعة باقة حساب جوجل جيميناي.';
    }
    if (errStr.contains('overloaded') || errStr.contains('try again') || errStr.contains('capacity')) {
      return 'النموذج مجهد حالياً أو هناك ضغط هائل على خوادم جيميناي (Model Overloaded). يرجى المحاولة بعد قليل (Try again later).';
    }
    if (errStr.contains('api_key') || errStr.contains('key not found') || errStr.contains('unauthorized')) {
      return 'مفتاح الربط (GEMINI_API_KEY) غير صحيح أو غير مفعل في إعدادات البيئة للسيرفر.';
    }
    if (errStr.contains('not found') || errStr.contains('models/')) {
      return 'اسم النموذج المدخل غير صحيح أو غير مدعوم حالياً من جوجل.';
    }
    if (errStr.contains('timeout') || errStr.contains('timed out')) {
      return 'انتهت مهلة الاتصال بالخادم، قد يكون حجم البيانات كبيراً جداً.';
    }

    return rawError.toString().replaceFirst('Exception: ', '').trim();
  }

  void _showErrorDialog(String title, dynamic error) {
    if (!mounted) return;
    String friendlyMessage = _translateServerErrorMessage(error);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(friendlyMessage, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showAiInsightsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    const String savedModelKey = 'last_used_gemini_model';
    String initialModel = prefs.getString(savedModelKey) ?? 'gemini-2.5-flash';
    
    final TextEditingController modelController = TextEditingController(text: initialModel);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple),
            SizedBox(width: 8),
            Text('تحليل Gemini'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'gemini-2.5-flash',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () async {
              String enteredModel = modelController.text.trim();
              if (enteredModel.isEmpty) {
                enteredModel = 'gemini-2.5-flash';
              }

              await prefs.setString(savedModelKey, enteredModel);

              Navigator.pop(context);
              widget.showLoadingDialog('جاري تحليل السجلات عبر Gemini وتوليد التقرير...');
              
              try {
                final result = await SearchManagementService.generateAiInsights(modelName: enteredModel);
                widget.hideLoadingDialog();

                if (result != null && result['success'] == true) {
                  final report = result['report'] ?? '';
                  final clearedCount = result['cleared_count'] ?? 0;
                  final modelUsed = result['model_used'] ?? enteredModel;

                  await SearchManagementService.saveAiReportToHistory(report, modelUsed, clearedCount);

                  final updatedLogs = await SearchManagementService.getZeroResultsLogs(forceRefresh: true);
                  widget.onLogsUpdated(updatedLogs);

                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.analytics, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('تقرير ذكاء البحث والمنتجات المطلوبة'),
                        ],
                      ),
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.75,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'تم تحليل وتفريغ $clearedCount سجل بحث بنجاح وحفظ التقرير في الأرشيف.',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const Divider(height: 24),
                              Text(report, style: const TextStyle(fontSize: 14, height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AiReportsHistoryScreen()),
                            );
                          },
                          child: const Text('عرض في الأرشيف'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('حفظ وفهم'),
                        ),
                      ],
                    ),
                  );
                } else {
                  _showErrorDialog('فشل عملية التحليل', result?['message'] ?? 'فشل الاتصال بالخدمة أو لم يتم استلام استجابة صحيحة.');
                }
              } catch (e) {
                widget.hideLoadingDialog();
                _showErrorDialog('خطأ في النظام أو الشبكة', e);
              }
            },
            label: const Text('بدء التحليل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final searchFieldColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;

    final filtered = widget.zeroResultsLogs.where((l) {
      if (_zeroLogSearchQuery.isEmpty) return true;
      final queryText = (l['search_query'] ?? '').toLowerCase();
      return queryText.contains(_zeroLogSearchQuery.toLowerCase());
    }).toList();

    final reversedList = filtered.reversed.toList();
    
    // اقتصار العناصر المعروضة بحسب الحد الحالي للتحميل التدريجي
    final displayedList = reversedList.take(_displayLimit).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: searchFieldColor, borderRadius: BorderRadius.circular(14)),
                  child: TextField(
                    controller: _zeroLogSearchQueryController,
                    onChanged: (val) {
                      setState(() {
                        _zeroLogSearchQuery = val;
                        _displayLimit = 10; // إعادة تعيين الحد عند البحث
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'ابحث في سجل الكلمات التي بلا نتائج...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              // const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Color.fromARGB(0, 155, 39, 176)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AiReportsHistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.history, size: 22),
                  label: const Text(''),
                ),
              ),
              // const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _showAiInsightsDialog,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('تحليل ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الكلمات الفريدة: ${reversedList.length}',
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تفريغ السجل بالكامل'),
                      content: const Text('هل أنت متأكد من رغبتك في مسح كافة سجلات البحث التي بلا نتائج دفعة واحدة؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('تفريغ الكل'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    widget.showLoadingDialog('جاري تفريغ السجلات...');
                    bool success = await SearchManagementService.clearAllZeroResults();
                    widget.hideLoadingDialog();
                    if (success) {
                      widget.onLogsUpdated([]);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تفريغ السجل بنجاح'), backgroundColor: Colors.green),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: const Text('تفريغ الكل'),
              ),
            ],
          ),
        ),
        Expanded(
          child: reversedList.isEmpty
              ? const Center(child: Text('لا توجد سجلات بحث بلا نتائج مطابقة'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
                  itemCount: displayedList.length + (displayedList.length < reversedList.length ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayedList.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }

                    final item = displayedList[index];
                    final id = item['id']?.toString() ?? '';
                    final queryText = item['search_query']?.toString() ?? '';
                    final count = item['search_count'] ?? 1;
                    final lastTime = item['last_searched_at']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Slidable(
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            extentRatio: 0.25,
                            children: [
                              SlidableAction(
                                onPressed: (_) => _deleteZeroLog(id),
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.redAccent,
                                icon: Icons.delete_outline_rounded,
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.withOpacity(0.08)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.withOpacity(0.15),
                                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text('"$queryText"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'تكرر $count مرة',
                                      style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text('آخر طلب بحث: $lastTime', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.grey, size: 20),
                                tooltip: 'تحديد كمقروء / مسح',
                                onPressed: () => _deleteZeroLog(id),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}