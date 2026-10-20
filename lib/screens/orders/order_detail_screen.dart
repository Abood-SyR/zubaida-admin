import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../products/product_details_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _apiService = ApiService();
  late Map<String, dynamic> _currentOrder;
  bool _isUpdating = false;

  final Map<String, String> _fetchedItemNames = {};
  final Map<String, bool> _loadingItems = {};
  final Set<String> _checkedKeys = {};

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _fetchMissingItemNames();
  }

  void _fetchMissingItemNames() async {
    final items = (_currentOrder['items'] as List?) ??
        (_currentOrder['items_details'] as List?) ??
        (_currentOrder['order_items'] as List?) ??
        [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rawName =
          item['product_name'] ?? item['product']?['name'] ?? item['title'];
      final itemType = item['item_type'] ?? 'product';
      final sourceId =
          (item['source_id'] ?? item['product_id'] ?? item['product']?['id'])
              ?.toString();

      if ((rawName == null || rawName.toString().isEmpty) && sourceId != null) {
        if (!_fetchedItemNames.containsKey(sourceId) &&
            !(_loadingItems[sourceId] ?? false)) {
          setState(() {
            _loadingItems[sourceId] = true;
          });
          try {
            String endpoint = '/products/$sourceId';
            if (itemType == 'offer') {
              endpoint = '/offers/$sourceId';
            } else if (itemType == 'group') {
              endpoint = '/product-groups/$sourceId';
            }

            Response response = await _apiService.dio.get(endpoint);
            if (response.statusCode == 200 && response.data != null) {
              final data = response.data;
              String name = 'عنصر #$sourceId';
              if (data is Map) {
                final n = data['name'] ?? data['title'];
                if (n is String) {
                  name = n;
                } else if (n is Map) {
                  name = n['ar'] ?? n['en'] ?? n.values.first.toString();
                }
              }
              setState(() {
                _fetchedItemNames[sourceId] = name;
                _loadingItems[sourceId] = false;
              });
            }
          } catch (e) {
            setState(() {
              _loadingItems[sourceId] = false;
            });
          }
        }
      }
    }
  }

  void _showCancelConfirmationDialog() {
    final TextEditingController textController = TextEditingController();
    const requiredText = "انا مسؤول عن الغاء الطلب";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد إلغاء الطلب',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'لتأكيد عملية إلغاء الطلب وإرجاع الكميات للمخزون، يرجى كتابة النص التالي بدقة:',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: const SelectableText(
                  requiredText,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: 'اكتب النص هنا...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('تراجع', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (textController.text.trim() == requiredText) {
                  Navigator.of(context).pop();
                  _updateOrderStatus('cancelled');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('النص المدخل غير مطابق، يرجى كتابته بدقة'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('تأكيد الإلغاء',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showSlideToProcessDialog() {
    double dragExtent = 0.0;
    const double maxDrag = 220.0;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('تأكيد التجهيز',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'اسحب الزر أدناه من اليمين إلى اليسار لتأكيد بدء تجهيز الطلب:',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 20),
                  Container(
                    width: maxDrag + 50,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        const Center(
                          child: Text(
                            'اسحب للتأكيد ⟵',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        Positioned(
                          right: dragExtent,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setDialogState(() {
                                dragExtent -= details.delta.dx;
                                if (dragExtent < 0) dragExtent = 0;
                                if (dragExtent > maxDrag) dragExtent = maxDrag;
                              });
                            },
                            onHorizontalDragEnd: (details) {
                              if (dragExtent >= maxDrag * 0.85) {
                                Navigator.of(dialogContext).pop();
                                _updateOrderStatus('processing');
                              } else {
                                setDialogState(() {
                                  dragExtent = 0.0;
                                });
                              }
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                              child: const Icon(Icons.arrow_forward_ios,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child:
                      const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final orderId = _currentOrder['order_id'] ?? _currentOrder['id'];
      Response response = await _apiService.dio.patch(
        '/orders/$orderId/status',
        queryParameters: {'new_status': newStatus},
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentOrder['status'] = newStatus;
          _isUpdating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تحديث حالة الطلب بنجاح'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('فشل تحديث حالة الطلب، تأكد من الاتصال'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openProofUrl(String proofUrlOrPath) async {
    try {
      // إظهار مؤشر تحميل أثناء جلب الملف بالصلاحيات
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // استخراج اسم الملف فقط (Filename) سواء كان مساراً كاملاً أو رابطاً قديماً
      String filename = proofUrlOrPath.split('/').last;

      // ضبط مسار الـ Endpoint الآمن الجديد في السيرفر الخاص بك
      final String secureEndpoint = '/orders/htfiles/$filename';
      
      // استخدام Dio الخاص بـ ApiService لضمان إرسال توكن الأدمن/المعدل تلقائياً
      Response<List<int>> response = await _apiService.dio.get<List<int>>(
        secureEndpoint,
        options: Options(responseType: ResponseType.bytes),
      );

      Navigator.of(context).pop(); // إغلاق مؤشر التحميل

      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data!;
        
        // عرض الصورة أو الملف في نافذة منبثقة داخلية (Dialog)
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إثبات التحويل المالي الآمن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        child: Image.memory(
                          UriData.fromBytes(bytes).contentAsBytes(),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // إذا لم تكن صورة (مثل ملف PDF)، عرض رسالة نجاح التحميل
                            return const Center(
                              child: Text(
                                'تم تحميل مستند إثبات التحويل (PDF) بنجاح عبر السيرفر.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل جلب إثبات التحويل، تأكد من صلاحيات حسابك والاتصال'), backgroundColor: Colors.red),
      );
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'processing':
        return 'بحاجة لتجهيز';
      case 'shipping':
        return 'جاري الشحن';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipping':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _groupOrderItems(List<dynamic> rawItems) {
    final Map<String, List<dynamic>> groupedMap = {};
    final List<Map<String, dynamic>> finalResult = [];

    for (var item in rawItems) {
      final itemType = item['item_type'] ?? 'product';
      final sourceId =
          item['source_id']?.toString() ?? item['product_id']?.toString() ?? '';

      if (itemType == 'offer' || itemType == 'group') {
        if (!groupedMap.containsKey(sourceId)) {
          groupedMap[sourceId] = [];
        }
        groupedMap[sourceId]!.add(item);
      } else {
        finalResult.add({
          'isGrouped': false,
          'item_type': itemType,
          'item': item,
        });
      }
    }

    groupedMap.forEach((sourceId, groupItems) {
      final firstItem = groupItems.first;
      final itemType = firstItem['item_type'];
      final parentName =
          itemType == 'offer' ? 'عرض خاص (حزمة)' : 'مجموعة منتجات';

      finalResult.add({
        'isGrouped': true,
        'source_id': sourceId,
        'item_type': itemType,
        'parent_name': parentName,
        'sub_items': groupItems,
      });
    });

    return finalResult;
  }

  String _extractName(dynamic rawName, String fallback) {
    if (rawName is String && rawName.isNotEmpty) return rawName;
    if (rawName is Map) {
      return rawName['ar'] ??
          rawName['en'] ??
          (rawName.values.isNotEmpty
              ? rawName.values.first.toString()
              : fallback);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final orderId =
        (_currentOrder['order_id'] ?? _currentOrder['id'] ?? '').toString();
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final status = _currentOrder['status'] ?? 'pending';

    final addressData = _currentOrder['shipping_address'];
    String addressText = 'غير متوفر';
    String customerName = _currentOrder['customer_name'] ?? 'غير محدد';
    String customerPhone = '-';
    Map<String, dynamic>? coordinates;

    if (addressData is Map) {
      addressText = addressData['address_text'] ??
          addressData['address'] ??
          addressData.toString();
      customerName = addressData['name'] ?? customerName;
      customerPhone = addressData['phone'] ?? '-';
      coordinates = addressData['coordinates'];
    }

    final rawItems = (_currentOrder['items'] as List?) ??
        (_currentOrder['items_details'] as List?) ??
        (_currentOrder['order_items'] as List?) ??
        [];

    final groupedItems = _groupOrderItems(rawItems);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('تفاصيل الطلب #$shortId',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('حالة الطلب:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_translateStatus(status),
                            style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                  if (status != 'completed' && status != 'cancelled') ...[
                    const SizedBox(height: 16),
                    _isUpdating
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (status == 'pending')
                                ElevatedButton.icon(
                                  onPressed: _showSlideToProcessDialog,
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  label: const Text('تأكيد للتجهيز',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              if (status == 'processing')
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateOrderStatus('shipping'),
                                  icon: const Icon(Icons.local_shipping,
                                      color: Colors.white, size: 18),
                                  label: const Text('تم الشحن',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: _showCancelConfirmationDialog,
                                icon: const Icon(Icons.cancel_outlined,
                                    color: Colors.red, size: 18),
                                label: const Text('إلغاء الطلب'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  backgroundColor: Colors.red.withOpacity(0.08),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('معلومات العميل والشحن',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('اسم العميل: $customerName',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('رقم الهاتف: $customerPhone',
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('العنوان: $addressText',
                              style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                  if (coordinates != null &&
                      coordinates['lat'] != null &&
                      coordinates['lng'] != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _openMap(coordinates!['lat'], coordinates['lng']),
                        icon: const Icon(Icons.map, color: Colors.green),
                        label: const Text('عرض الموقع على الخريطة التفاعلية',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('عناصر الطلب (قائمة التجهيز)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            groupedItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('لا توجد عناصر مسجلة في هذا الطلب',
                            style: TextStyle(color: Colors.grey))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupedItems.length,
                    itemBuilder: (context, groupIndex) {
                      final group = groupedItems[groupIndex];
                      final isGrouped = group['isGrouped'] as bool;

                      if (!isGrouped) {
                        // عنصر فردي عادي (منتج أساسي)
                        final item = group['item'];
                        final productId = item['product_id']?.toString();
                        final itemName = _extractName(item['product_name'], 'منتج');
                        final quantity = item['quantity'] ?? 1;
                        final unitPrice = (item['unit_price'] ?? 0).toDouble();
                        final itemTotal = unitPrice * quantity;
                        
                        // مفتاح فريد وثابت للعنصر المفرد
                        final checkKey = item['id']?.toString() ?? 'single_$groupIndex';
                        final isChecked = _checkedKeys.contains(checkKey);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isChecked ? Colors.green.withOpacity(0.05) : theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isChecked ? Colors.green.withOpacity(0.3) : Colors.transparent, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _checkedKeys.add(checkKey);
                                    } else {
                                      _checkedKeys.remove(checkKey);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: productId != null ? () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: productId)));
                                  } : null,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                            child: const Text('منتج', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              itemName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                // يتم التشطيب فقط إذا كان isChecked صحيحاً
                                                decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                                color: isChecked ? Colors.grey : theme.textTheme.bodyLarge?.color,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('الكمية: $quantity | السعر الفردي: $unitPrice ل.س', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                              Text('$itemTotal ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        );
                      } else {
                        // عرض أو مجموعة تحتوي على عدة منتجات
                        final parentName = group['parent_name'] as String;
                        final itemType = group['item_type'] as String;
                        final subItems = group['sub_items'] as List<dynamic>;
                        final badgeColor = itemType == 'offer' ? Colors.orange : Colors.purple;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: badgeColor.withOpacity(0.3), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text(parentName, style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              ...subItems.asMap().entries.map((entry) {
                                final subIndex = entry.key;
                                final sub = entry.value;
                                final productId = sub['product_id']?.toString() ?? 'unknown';
                                final subId = sub['id']?.toString() ?? 'sub_$subIndex';
                                final subName = _extractName(sub['product_name'], 'منتج فرعي');
                                final quantity = sub['quantity'] ?? 1;
                                final unitPrice = (sub['unit_price'] ?? 0).toDouble();
                                
                                // مفتاح فريد ومستقل تماماً لكل عنصر فرعي بناءً على معرفه الفريد
                                final checkKey = 'group_${group['source_id']}_item_$subId';
                                final isChecked = _checkedKeys.contains(checkKey);

                                return Padding(
                                  padding: const EdgeInsets.only(right: 20.0, bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isChecked,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _checkedKeys.add(checkKey);
                                            } else {
                                              _checkedKeys.remove(checkKey);
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: productId != 'unknown' ? () {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: productId)));
                                          } : null,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '    $subName',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.blue.shade700,
                                                  // يتم التشطيب فقط وفقط إذا كان الـ Checkbox الخاص بهذا المنتج محدد تماماً
                                                  decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text('    الكمية: $quantity | السعر: $unitPrice ل.س', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }
                    },
                  ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('طريقة الدفع',
                          style: TextStyle(color: Colors.grey)),
                      Text(_currentOrder['payment_method'] ?? 'نقداً',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('حالة الدفع',
                          style: TextStyle(color: Colors.grey)),
                      Text(_currentOrder['payment_status'] ?? 'غير مدفوع',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                  if (_currentOrder['payment_details'] != null &&
                      _currentOrder['payment_details'] is Map) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تفاصيل الدفع (شام كاش)',
                            style: TextStyle(color: Colors.grey)),
                        if (_currentOrder['payment_details']
                                ['invoice_number'] !=
                            null)
                          Text(
                              'رقم الحوالة: ${_currentOrder['payment_details']['invoice_number']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.blue))
                        else if (_currentOrder['payment_details']
                                ['proof_url'] !=
                            null)
                          InkWell(
                            onTap: () => _openProofUrl(
                                _currentOrder['payment_details']['proof_url']),
                            child: const Text('عرض إثبات التحويل (صورة/PDF)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.indigo,
                                    decoration: TextDecoration.underline)),
                          ),
                      ],
                    ),
                  ],
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المبلغ الإجمالي',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${_currentOrder['total_amount'] ?? 0} ل.س',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
