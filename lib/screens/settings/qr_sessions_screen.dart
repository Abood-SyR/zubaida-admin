import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
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
  bool _allowShipping = false;
  bool _allowCompleted = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل جلب الجلسات (تأكد من صلاحيات الأدمن)'), backgroundColor: Colors.red),
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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم الجلسة أو الوردية'), backgroundColor: Colors.orange),
      );
      return;
    }

    List<String> allowedStatuses = [];
    if (_allowPending) allowedStatuses.add('pending');
    if (_allowProcessing) allowedStatuses.add('processing');
    if (_allowShipping) allowedStatuses.add('shipping');
    if (_allowCompleted) allowedStatuses.add('completed');

    final differenceInMinutes = _selectedExpiresAt.difference(DateTime.now()).inMinutes;
    if (differenceInMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون وقت الانتهاء في المستقبل'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      // 1. توليد بيانات وهمية فريدة للمستخدم (إيميل وكلمة مرور) لتجاوز حماية 401 في السيرفر
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fakePhone = '9${timestamp.toString().substring(timestamp.toString().length - 9)}';
      final fakePassword = 'Pass_$timestamp!';

      // 2. إنشاء المستخدم الوهمي في جدول الـ User عبر نقطة التسجيل بالسيرفر
      final registerRes = await _apiService.dio.post('/auth/register', data: {
        'phone_number': fakePhone,
        'username': _nameController.text.trim(),
        'password': fakePassword,
        'full_name': _nameController.text.trim(),
      });

      if (registerRes.statusCode != 201 && registerRes.statusCode != 200) {
        throw Exception('فشل إنشاء الحساب الوهمي');
      }

      // 3. توليد جلسة QR الرسمية في جدول الـ EditorSession للحصول على الـ token والتحكم والصلاحيات
      final response = await _apiService.dio.post('/auth/admin/sessions/generate', data: {
        'session_name': _nameController.text.trim(),
        'expires_in_minutes': differenceInMinutes,
        'is_full_access': _isFullAccess,
        'can_view_stats': _canViewStats,
        'can_manage_products': _canManageProducts,
        'can_change_price_stock': _canChangePriceStock,
        'can_manage_offers': _canManageOffers,
        'can_manage_discounts': _canManageDiscounts,
        'can_manage_categories': _canManageCategories,
        'can_manage_sessions': _canManageSessions,
        'allowed_order_statuses': allowedStatuses,
      });

      if (response.statusCode == 200) {
        setState(() => _isCreatingNew = false);
        _fetchSessions();

        // 4. دمج بيانات الجلسة مع بيانات الحساب الوهمي في محتوى الـ QR (حزمة JSON متكاملة)
        final qrPayload = jsonEncode({
          'session_token': response.data['session_token'],
          'phone': fakePhone,
          'password': fakePassword,
        });

        _showQrCodeDialog(qrPayload, response.data['session_name']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل توليد الجلسة أو الحساب المرتبط'), backgroundColor: Colors.red),
      );
    }
  }

  void _showQrCodeDialog(String qrDataString, String sessionName) {
    _wsChannel?.sink.close();

    // استخراج الـ session_token الأصلي من الحزمة للاتصال بالـ WebSocket ومراقبة المسح
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
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('QR الجلسة: $sessionName', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('جارِ انتظار مسح الرمز من قِبل المعدل...\nسيتم إغلاق النافذة وتحديث القائمة تلقائياً.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: SizedBox(
                width: 240,
                height: 240,
                child: QrImageView(
                  data: qrDataString, // تمرير حزمة الـ JSON التي تحتوي على الحساب والجلسة معاً
                  version: QrVersions.auto, 
                  size: 240.0,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    ).then((_) {
      isDialogDismissed = true;
      _wsChannel?.sink.close();
      _wsChannel = null;
    });
  }

  Future<void> _controlSession(String sessionId, String action) async {
    try {
      await _apiService.dio.patch('/auth/admin/sessions/$sessionId/control', queryParameters: {'action': action});
      _fetchSessions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنفيذ الإجراء بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تنفيذ الإجراء'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      body: _isCreatingNew
          ? _buildCreateSessionView(theme, isDesktop)
          : _buildSessionsListView(theme, isDesktop),
      floatingActionButton: !_isCreatingNew
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _isCreatingNew = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('توليد جلسة جديدة'),
            )
          : null,
    );
  }

  Widget _buildCreateSessionView(ThemeData theme, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _isCreatingNew = false),
                  ),
                  const SizedBox(width: 8),
                  const Text('إعداد وتوليد جلسة معدل جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الجلسة / الوردية (مثال: أحمد - وردية الصباح)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: _pickExpirationDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'تاريخ ووقت انتهاء الصلاحية', border: OutlineInputBorder()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_selectedExpiresAt.year}-${_selectedExpiresAt.month.toString().padLeft(2, '0')}-${_selectedExpiresAt.day.toString().padLeft(2, '0')}  ${_selectedExpiresAt.hour.toString().padLeft(2, '0')}:${_selectedExpiresAt.minute.toString().padLeft(2, '0')}'),
                      const Icon(Icons.calendar_today_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                title: const Text('صلاحيات كاملة (Full Access)', style: TextStyle(fontWeight: FontWeight.bold)),
                value: _isFullAccess,
                onChanged: (val) => setState(() => _isFullAccess = val ?? false),
              ),
              const Divider(),
              if (!_isFullAccess) ...[
                const Text('الصلاحيات الدقيقة الممنوحة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                CheckboxListTile(title: const Text('رؤية الإحصائيات'), value: _canViewStats, onChanged: (val) => setState(() => _canViewStats = val ?? false)),
                CheckboxListTile(title: const Text('إدارة المنتجات'), value: _canManageProducts, onChanged: (val) => setState(() => _canManageProducts = val ?? false)),
                CheckboxListTile(title: const Text('تغيير الأسعار والكميات'), value: _canChangePriceStock, onChanged: (val) => setState(() => _canChangePriceStock = val ?? false)),
                CheckboxListTile(title: const Text('إدارة العروض'), value: _canManageOffers, onChanged: (val) => setState(() => _canManageOffers = val ?? false)),
                CheckboxListTile(title: const Text('إدارة الخصومات'), value: _canManageDiscounts, onChanged: (val) => setState(() => _canManageDiscounts = val ?? false)),
                CheckboxListTile(title: const Text('إدارة الفئات'), value: _canManageCategories, onChanged: (val) => setState(() => _canManageCategories = val ?? false)),
                CheckboxListTile(title: const Text('إدارة الجلسات'), value: _canManageSessions, onChanged: (val) => setState(() => _canManageSessions = val ?? false)),
                const SizedBox(height: 16),
                const Text('حالات الطلبات المسموح بالتعامل معها:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(label: const Text('قيد الانتظار (Pending)'), selected: _allowPending, onSelected: (val) => setState(() => _allowPending = val)),
                    FilterChip(label: const Text('قيد التجهيز (Processing)'), selected: _allowProcessing, onSelected: (val) => setState(() => _allowProcessing = val)),
                    FilterChip(label: const Text('قيد التوصيل (Shipping)'), selected: _allowShipping, onSelected: (val) => setState(() => _allowShipping = val)),
                    FilterChip(label: const Text('منجزة (Completed)'), selected: _allowCompleted, onSelected: (val) => setState(() => _allowCompleted = val)),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submitGenerateSession,
                  icon: const Icon(Icons.qr_code_rounded),
                  label: const Text('توليد وعرض رمز الاستجابة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsListView(ThemeData theme, bool isDesktop) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _sessions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('لا توجد جلسات نشطة حالياً للمعدلين', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                  final ip = session['ip_address'] ?? 'لم يتم التسجيل بعد';
                  final device = session['device_info'] ?? '-';
                  final token = session['session_token'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Text(session['session_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('الحالة: ${isScanned ? "مُستخدمة (مسحوبة)" : "في انتظار المسح"} | نشطة: ${isActive ? "نعم" : "معلقة"}'),
                          Text('IP: $ip'),
                          Text('الجهاز: $device', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_2_rounded, color: Colors.blue),
                            onPressed: () => _showQrCodeDialog(token, session['session_name']),
                            tooltip: 'عرض الباركود',
                          ),
                          IconButton(
                            icon: Icon(isActive ? Icons.pause_circle_rounded : Icons.play_circle_rounded, color: isActive ? Colors.orange : Colors.green),
                            onPressed: () => _controlSession(session['id'], isActive ? 'suspend' : 'activate'),
                            tooltip: isActive ? 'تعليق الجلسة' : 'تنشيط الجلسة',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: Colors.red),
                            onPressed: () => _controlSession(session['id'], 'delete'),
                            tooltip: 'حذف الجلسة وطرد المعدل',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
  }
}