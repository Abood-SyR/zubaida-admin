import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class AiReportReaderScreen extends StatelessWidget {
  final Map<String, dynamic> reportItem;
  final VoidCallback onDelete;

  const AiReportReaderScreen({
    super.key,
    required this.reportItem,
    required this.onDelete,
  });

  // دالة ذكية وشاملة لتوليد أو استخراج نص التقرير بأمان تامة
  String _getReportText() {
    // 1. البحث في الحقول النصية المباشرة
    final direct = reportItem['report'] ?? reportItem['content'] ?? reportItem['text'] ?? reportItem['summary'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    // 2. البحث داخل الـ metrics
    final metrics = reportItem['metrics'] is Map ? reportItem['metrics'] as Map<String, dynamic> : {};
    final metricsReport = metrics['report'] ?? metrics['summary'] ?? metrics['report_text'] ?? metrics['content'];
    if (metricsReport != null && metricsReport.toString().trim().isNotEmpty) {
      return metricsReport.toString();
    }

    // 3. إن لم يوجد أي نص، نقوم بتوليد تقرير تفصيلي واحترافي من البيانات والقوائم الواردة (مثل top_searched_items)
    final topItems = metrics['top_searched_items'] is List ? metrics['top_searched_items'] as List : [];
    final totalQueries = metrics['total_analyzed_queries'] ?? reportItem['cleared_count'] ?? 0;
    final failedVolume = metrics['total_failed_searches_volume'] ?? 0;
    final periodName = reportItem['period_name'] ?? 'تقرير تحليل النظام';

    StringBuffer sb = StringBuffer();
    sb.writeln(periodName);
    sb.writeln('==================================================');
    sb.writeln('• إجمالي عمليات البحث والتحليل: $totalQueries');
    sb.writeln('• حجم عمليات البحث التي لم تسفر عن نتائج مباشرة: $failedVolume');
    sb.writeln('\nأبرز طلبات وكلمات البحث المسجلة:');

    if (topItems.isEmpty) {
      sb.writeln('- لا توجد تفاصيل إضافية مسجلة في هذا التقرير.');
    } else {
      for (int i = 0; i < topItems.length; i++) {
        final item = topItems[i];
        final query = item['query'] ?? 'بحث غير معروف';
        final count = item['count'] ?? 1;
        sb.writeln('${i + 1}. "$query" (تكرار الطلب: $count مرات)');
      }
    }

    sb.writeln('\n==================================================');
    sb.writeln('توصية المقترحات: يُنصح بمتابعة الأصناف والكلمات الأكثر طلباً لتوفيرها في المتجر وتحسين تجربة الزبائن.');

    return sb.toString();
  }

  String _getDate() {
    return reportItem['date'] ?? reportItem['created_at'] ?? reportItem['start_date'] ?? '';
  }

  String _getModel() {
    final metrics = reportItem['metrics'] is Map ? reportItem['metrics'] as Map<String, dynamic> : {};
    return metrics['model_used'] ?? reportItem['model_used'] ?? 'Gemini AI';
  }

  int _getCount() {
    final metrics = reportItem['metrics'] is Map ? reportItem['metrics'] as Map<String, dynamic> : {};
    return metrics['total_analyzed_queries'] ?? metrics['cleared_count'] ?? reportItem['cleared_count'] ?? 0;
  }

  // تصدير الملف كـ CSV عبر المتصفح
  void _exportSingleReport(BuildContext context) {
    try {
      final id = reportItem['id'] ?? '';
      final date = _getDate();
      final model = _getModel();
      final count = _getCount();
      final report = _getReportText().replaceAll('\n', ' ').replaceAll('"', '""');

      StringBuffer csvContent = StringBuffer();
      csvContent.writeln('ID,Date,Model,Cleared Count,Report');
      csvContent.writeln('"$id","$date","$model","$count","$report"');

      final bytes = '\uFEFF${csvContent.toString()}'.codeUnits;
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      html.AnchorElement(href: url)
        ..setAttribute('download', 'AI_Report_$id.csv')
        ..click();
      
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنزيل التقرير بنجاح عبر المتصفح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // نسخ محتوى التقرير أو مشاركته عبر المتصفح
  void _shareSingleReport(BuildContext context) {
    final reportText = _getReportText();
    final date = _getDate();
    final model = _getModel();
    
    final shareContent = '''
تقرير تحليل ذكاء البحث (Gemini)
التاريخ: $date
النموذج: $model

$reportText
''';

    html.window.navigator.clipboard?.writeText(shareContent).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ محتوى التقرير إلى الحافظة بنجاح'), backgroundColor: Colors.green),
      );
    }).catchError((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر نسخ التقرير'), backgroundColor: Colors.red),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reportText = _getReportText();
    final dateStr = _getDate();
    final model = _getModel();
    final count = _getCount();

    String formattedDate = dateStr;
    try {
      final dt = DateTime.parse(dateStr);
      formattedDate = intl.DateFormat('yyyy-MM-dd – hh:mm a').format(dt);
    } catch (_) {}

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color.fromARGB(0, 255, 214, 64),
        title: const Text('قراءة التقرير التحليلي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 22),
            tooltip: 'نسخ التقرير',
            onPressed: () => _shareSingleReport(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 22),
            tooltip: 'تصدير هذا التقرير فقط',
            onPressed: () => _exportSingleReport(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            tooltip: 'حذف التقرير',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('حذف التقرير'),
                  content: const Text('هل أنت متأكد من رغبتك في حذف هذا التقرير من الأرشيف؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                onDelete();
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, size: 18, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('النموذج: $model', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('التاريخ: $formattedDate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'السجلات المحللة: $count',
                          style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  reportText,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.9,
                    letterSpacing: 0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}