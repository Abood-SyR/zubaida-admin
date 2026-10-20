import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/api_service.dart';

class QrSessionsScreen extends StatefulWidget {
  const QrSessionsScreen({super.key});

  @override
  State<QrSessionsScreen> createState() => _QrSessionsScreenState();
}

class _QrSessionsScreenState extends State<QrSessionsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _sessions = [];
  bool _isLoading = true;
  bool _isCreatingNew = false;
  WebSocketChannel? _wsChannel;

  final TextEditingController _nameController = TextEditingController();
  late DateTime _selectedExpiresAt;
  
  bool _isFullAccess = false;
  bool _canViewStats = false;
  bool _canManageProducts = false;
  bool _canChangePriceStock = false;
  bool _canManageOffers = false;
  bool _canManageDiscounts = false;
  bool _canManageCategories = false;
  bool _canManageSessions = false;

  bool _allowPending = true;
  bool _allowProcessing = true;
  bool _allowShipping = true;
  bool _allowCompleted = true;

  @override
  void initState() {
    super.initState();
    _selectedExpiresAt = DateTime.now().add(const Duration(hours: 2));
    _fetchSessions();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _nameController.dispose();
    super.dispose();
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _fetchSessions() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.dio.get('/auth/admin/sessions');
      if (response.statusCode == 200) {
        setState(() {
          _sessions = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل جلب الجلسات'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickExpirationDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedExpiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedExpiresAt),
    );
    if (time == null) return;

    setState(() {
      _selectedExpiresAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submitGenerateSession() async {
    String rawName = _nameController.text.trim();
    if (rawName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم الجلسة'), backgroundColor: Colors.orange),
      );
      return;
    }

    // الاسم المخزن في السيرفر مع إضافة البقرة تلقائياً للتحقق
    String finalSessionName = rawName;
    final lowerName = rawName.toLowerCase();
    if (lowerName.contains('تيماء') || 
        lowerName.contains('تيومة') || 
        lowerName.contains('تيما') || 
        lowerName.contains('تيومى') || 
        lowerName.contains('تيوم') || 
        lowerName.contains('تامي') || 
        lowerName.contains('taymaa') || 
        lowerName.contains('بنتي') || 
        lowerName.contains('يزن') || 
        lowerName.contains('يزون') || 
        lowerName.contains('يزوني') || 
        lowerName.contains('يزونتي') || 
        lowerName.contains('الزيك') || 
        lowerName.contains('توما') || 
        lowerName.contains('تيم')) {
      finalSessionName = '$rawName البقرة';
    }

    List<String> allowedStatuses = [];
    if (_isFullAccess || _allowPending) allowedStatuses.add('pending');
    if (_isFullAccess || _allowProcessing) allowedStatuses.add('processing');
    if (_isFullAccess || _allowShipping) allowedStatuses.add('shipping');
    if (_isFullAccess || _allowCompleted) allowedStatuses.add('completed');

    final differenceInMinutes = _selectedExpiresAt.difference(DateTime.now()).inMinutes;
    if (differenceInMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون وقت الانتهاء في المستقبل'), backgroundColor: Colors.orange),
      );
      return;
    }

    _showLoadingDialog('جاري التوليد...');

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fakePhone = '9${timestamp.toString().substring(timestamp.toString().length - 9)}';
      final fakePassword = 'Pass_$timestamp!';

      await _apiService.dio.post('/auth/register', data: {
        'phone_number': fakePhone,
        'username': finalSessionName,
        'password': fakePassword,
        'full_name': finalSessionName,
      });

      final response = await _apiService.dio.post('/auth/admin/sessions/generate', data: {
        'session_name': finalSessionName,
        'expires_in_minutes': differenceInMinutes,
        'is_full_access': _isFullAccess,
        'can_view_stats': _isFullAccess ? true : _canViewStats,
        'can_manage_products': _isFullAccess ? true : _canManageProducts,
        'can_change_price_stock': _isFullAccess ? true : _canChangePriceStock,
        'can_manage_offers': _isFullAccess ? true : _canManageOffers,
        'can_manage_discounts': _isFullAccess ? true : _canManageDiscounts,
        'can_manage_categories': _isFullAccess ? true : _canManageCategories,
        'can_manage_sessions': _isFullAccess ? true : _canManageSessions,
        'allowed_order_statuses': allowedStatuses,
      });

      _hideLoadingDialog();

      if (response.statusCode == 200) {
        setState(() => _isCreatingNew = false);
        _fetchSessions();

        final qrPayload = jsonEncode({
          'session_token': response.data['session_token'],
          'phone': fakePhone,
          'password': fakePassword,
        });

        // إرسال الاسم النظيف (rawName) لواجهة الـ QR حتى لا تظهر كلمة البقرة للشخص المعني
        _showQrCodeDialog(qrPayload, rawName, response.data['id']);
      }
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل توليد الجلسة'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resetAndShowQr(String sessionId, String token, String sessionName) async {
    _showLoadingDialog('جاري تجهيز الرمز...');
    try {
      await _apiService.dio.patch('/auth/admin/sessions/$sessionId/control', queryParameters: {'action': 'activate'});
      _hideLoadingDialog();
      
      final qrPayload = jsonEncode({
        'session_token': token,
      });

      // تنظيف الاسم المعروض في نافذة الـ QR في حال كان يحتوي على كلمة البقرة المخزنة
      String cleanDisplayName = sessionName.replaceAll(' البقرة', '').replaceAll('البقرة', '').trim();

      _showQrCodeDialog(qrPayload, cleanDisplayName, sessionId);
      _fetchSessions();
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إعادة توليد الرمز'), backgroundColor: Colors.red),
      );
    }
  }

  void _showQrCodeDialog(String qrDataString, String sessionName, [String? sessionId]) {
    _wsChannel?.sink.close();

    String tokenToTrack = '';
    try {
      final decoded = jsonDecode(qrDataString);
      tokenToTrack = decoded['session_token'] ?? '';
    } catch (_) {
      tokenToTrack = qrDataString;
    }

    final baseUrl = _apiService.dio.options.baseUrl;
    final wsUri = '${baseUrl.replaceFirst('http', 'ws').replaceAll('/api', '')}/auth/ws/admin/sessions/$tokenToTrack';

    _wsChannel = WebSocketChannel.connect(Uri.parse(wsUri));
    bool isDialogDismissed = false;

    _wsChannel!.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['status'] == 'scanned' && !isDialogDismissed) {
          isDialogDismissed = true;
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          _fetchSessions();
        }
      } catch (_) {}
    }, onDone: () {
      _wsChannel = null;
    }, onError: (_) {
      _wsChannel = null;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  Expanded(
                    child: Text(
                      sessionName, // سيظهر الاسم بدون كلمة البقرة حصراً
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'امحُ الرمز عبر التطبيق للمتابعة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: QrImageView(
                    data: qrDataString,
                    version: QrVersions.auto,
                    size: 220.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: qrDataString));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ الرمز بنجاح'), duration: Duration(seconds: 2)),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('نسخ الرمز بالكامل', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      isDialogDismissed = true;
      _wsChannel?.sink.close();
      _wsChannel = null;
    });
  }

  Future<void> _controlSession(String sessionId, String action) async {
    _showLoadingDialog('جاري التحديث...');
    try {
      await _apiService.dio.patch('/auth/admin/sessions/$sessionId/control', queryParameters: {'action': action});
      _hideLoadingDialog();
      _fetchSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل التنفيذ'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isCreatingNew
          ? _buildCreateSessionView(theme, isDesktop)
          : _buildSessionsListView(theme, isDesktop),
      floatingActionButton: !_isCreatingNew
          ? FloatingActionButton.extended(
              elevation: 2,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              onPressed: () => setState(() => _isCreatingNew = true),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('جلسة جديدة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            )
          : null,
    );
  }

  Widget _buildCreateSessionView(ThemeData theme, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    onPressed: () => setState(() => _isCreatingNew = false),
                  ),
                  const SizedBox(width: 8),
                  const Text('إعداد جلسة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم الجلسة',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickExpirationDateTime,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'انتهاء الصلاحية',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_selectedExpiresAt.year}-${_selectedExpiresAt.month.toString().padLeft(2, '0')}-${_selectedExpiresAt.day.toString().padLeft(2, '0')}  ${_selectedExpiresAt.hour.toString().padLeft(2, '0')}:${_selectedExpiresAt.minute.toString().padLeft(2, '0')}'),
                            const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('صلاحيات كاملة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      value: _isFullAccess,
                      onChanged: (val) => setState(() => _isFullAccess = val),
                    ),
                    if (!_isFullAccess) ...[
                      const Divider(height: 24),
                      const Text('الأذونات المخصصة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 8),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('الإحصائيات'), value: _canViewStats, onChanged: (val) => setState(() => _canViewStats = val ?? false)),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('المنتجات'), value: _canManageProducts, onChanged: (val) => setState(() => _canManageProducts = val ?? false)),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('الأسعار والمخزون'), value: _canChangePriceStock, onChanged: (val) => setState(() => _canChangePriceStock = val ?? false)),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('العروض'), value: _canManageOffers, onChanged: (val) => setState(() => _canManageOffers = val ?? false)),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('الخصومات'), value: _canManageDiscounts, onChanged: (val) => setState(() => _canManageDiscounts = val ?? false)),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('الفئات'), value: _canManageCategories, onChanged: (val) => setState(() => _canManageCategories = val ?? false)),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('الجلسات'), value: _canManageSessions, onChanged: (val) => setState(() => _canManageSessions = val ?? false)),
                      const SizedBox(height: 16),
                      const Text('حالات الطلبات المتاحة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(label: const Text('انتظار'), selected: _allowPending, onSelected: (val) => setState(() => _allowPending = val)),
                          FilterChip(label: const Text('تجهيز'), selected: _allowProcessing, onSelected: (val) => setState(() => _allowProcessing = val)),
                          FilterChip(label: const Text('شحن'), selected: _allowShipping, onSelected: (val) => setState(() => _allowShipping = val)),
                          FilterChip(label: const Text('إنجاز'), selected: _allowCompleted, onSelected: (val) => setState(() => _allowCompleted = val)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitGenerateSession,
                  child: const Text('إنشاء الرمز', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsListView(ThemeData theme, bool isDesktop) {
    final isDark = theme.brightness == Brightness.dark;

    return _isLoading
        ? ListView.builder(
            padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
            itemCount: 4,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Shimmer.fromColors(
                baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          )
        : _sessions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text('لا توجد جلسات حالياً', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final isActive = session['is_active'] ?? true;
                  final isScanned = session['is_scanned'] ?? false;
                  final token = session['session_token'] ?? '';
                  final sessionId = session['id'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Slidable(
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          extentRatio: 0.4,
                          children: [
                            SlidableAction(
                              onPressed: (_) {
                                _resetAndShowQr(sessionId, token, session['session_name']);
                              },
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.blue,
                              icon: Icons.qr_code_rounded,
                            ),
                            SlidableAction(
                              onPressed: (_) => _controlSession(sessionId, isActive ? 'suspend' : 'activate'),
                              backgroundColor: Colors.transparent,
                              foregroundColor: isActive ? Colors.orange : Colors.green,
                              icon: isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            ),
                            SlidableAction(
                              onPressed: (_) => _controlSession(sessionId, 'delete'),
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.red,
                              icon: Icons.delete_outline_rounded,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (isScanned ? Colors.grey : Colors.green).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isScanned ? Icons.check_rounded : Icons.qr_code_rounded,
                                color: isScanned ? Colors.grey : Colors.green,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              session['session_name'],
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              isScanned ? 'تم الاستخدام' : 'جاهز للمسح',
                              style: TextStyle(fontSize: 12, color: isScanned ? Colors.grey : Colors.green),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
  }
}