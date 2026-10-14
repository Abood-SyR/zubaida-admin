import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart' as intl;
import '../../core/services/search_management_service.dart';
import 'ai_report_reader_screen.dart';

class AiReportsHistoryScreen extends StatefulWidget {
  const AiReportsHistoryScreen({super.key});

  @override
  State<AiReportsHistoryScreen> createState() => _AiReportsHistoryScreenState();
}

class _AiReportsHistoryScreenState extends State<AiReportsHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _reportsHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await SearchManagementService.getAiReportsHistory();
    setState(() {
      _reportsHistory = history;
      _isLoading = false;
    });
  }

  Future<void> _deleteReport(String id) async {
    await SearchManagementService.deleteAiReportFromHistory(id);
    await _loadHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف التقرير من الأرشيف'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشيف تقارير الذكاء الاصطناعي'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportsHistory.isEmpty
              ? const Center(child: Text('لا توجد تقارير محفوظة في الأرشيف'))
              : ListView.builder(
                  padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                  itemCount: _reportsHistory.length,
                  itemBuilder: (context, index) {
                    final item = _reportsHistory[index];
                    final id = item['id']?.toString() ?? '';
                    final dateStr = item['date']?.toString() ?? '';
                    final count = item['cleared_count'] ?? 0;
                    final previewText = item['report']?.toString() ?? '';

                    String formattedDate = dateStr;
                    try {
                      final dt = DateTime.parse(dateStr);
                      formattedDate = intl.DateFormat('yyyy-MM-dd – hh:mm a').format(dt);
                    } catch (_) {}

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        // استخدام Slidable لإخفاء زر الحذف وإظهاره عند السحب
                        child: Slidable(
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            extentRatio: 0.25,
                            children: [
                              SlidableAction(
                                onPressed: (_) => _deleteReport(id),
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.redAccent,
                                icon: Icons.delete_outline_rounded,
                                label: 'حذف',
                              ),
                            ],
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              leading: const CircleAvatar(
                                backgroundColor: Colors.purple,
                                child: Icon(Icons.analytics, color: Colors.white, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text('تقرير تحليل ($count سجل)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  previewText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AiReportReaderScreen(
                                      reportItem: item,
                                      onDelete: () => _deleteReport(id),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}