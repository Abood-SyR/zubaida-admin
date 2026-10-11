import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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

  final Map<String, String> _fetchedProductNames = {};
  final Map<String, bool> _loadingProducts = {};
  final Set<int> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _fetchMissingProductNames();
  }

  void _fetchMissingProductNames() async {
    final items = (_currentOrder['items'] as List?) 
        ?? (_currentOrder['items_details'] as List?) 
        ?? (_currentOrder['order_items'] as List?) 
        ?? [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rawName = item['product_name'] ?? item['product']?['name'] ?? item['title'];
      final productId = (item['product_id'] ?? item['product']?['id'])?.toString();

      if ((rawName == null || rawName.toString().isEmpty) && productId != null) {
        if (!_fetchedProductNames.containsKey(productId) && !(_loadingProducts[productId] ?? false)) {
          setState(() {
            _loadingProducts[productId] = true;
          });
          try {
            Response response = await _apiService.dio.get('/products/$productId');
            if (response.statusCode == 200 && response.data != null) {
              final prodData = response.data;
              String name = 'منتج #$productId';
              if (prodData is Map) {
                final n = prodData['name'];
                if (n is String) {
                  name = n;
                } else if (n is Map) {
                  name = n['ar'] ?? n['en'] ?? n.values.first.toString();
                }
              }
              setState(() {
                _fetchedProductNames[productId] = name;
                _loadingProducts[productId] = false;
              });
            }
          } catch (e) {
            setState(() {
              _loadingProducts[productId] = false;
            });
          }
        }
      }
    }
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
          const SnackBar(content: Text('تم تحديث حالة الطلب بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحديث حالة الطلب، تأكد من الاتصال'), backgroundColor: Colors.red),
      );
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'processing': return 'بحاجة لتجهيز';
      case 'shipped': return 'تم الشحن';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'processing': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final orderId = (_currentOrder['order_id'] ?? _currentOrder['id'] ?? '').toString();
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final status = _currentOrder['status'] ?? 'pending';
    
    final addressData = _currentOrder['shipping_address'];
    String addressText = 'غير متوفر';
    String customerName = _currentOrder['customer_name'] ?? 'غير محدد';
    String customerPhone = '-';

    if (addressData is Map) {
      addressText = addressData['address_text'] ?? addressData['address'] ?? addressData.toString();
      customerName = addressData['name'] ?? customerName;
      customerPhone = addressData['phone'] ?? '-';
    } else if (addressData != null) {
      addressText = addressData.toString();
    }

    final items = (_currentOrder['items'] as List?) 
        ?? (_currentOrder['items_details'] as List?) 
        ?? (_currentOrder['order_items'] as List?) 
        ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('تفاصيل الطلب #$shortId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. بطاقة الحالة والإجراءات
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('حالة الطلب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_translateStatus(status), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 13)),
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
                                  onPressed: () => _updateOrderStatus('processing'),
                                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                  label: const Text('تأكيد للتجهيز', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              if (status == 'processing')
                                ElevatedButton.icon(
                                  onPressed: () => _updateOrderStatus('shipping'), // تم التعديل لتتوافق مع الباك إند
                                  icon: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
                                  label: const Text('تم التجهيز', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: () => _updateOrderStatus('cancelled'),
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                label: const Text('إلغاء الطلب'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  backgroundColor: Colors.red.withOpacity(0.08),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. معلومات العميل والشحن
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('معلومات العميل والشحن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('اسم العميل: $customerName', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('رقم الهاتف: $customerPhone', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text('العنوان: $addressText', style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. المنتجات المطلوبة (قائمة التجهيز مع زر دائري أنيق)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المنتجات المطلوبة (قائمة التجهيز)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  'تم تجهيز: ${_checkedItems.length} من ${items.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('لا توجد منتجات مسجلة في هذا الطلب', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isChecked = _checkedItems.contains(index);
                      
                      final productId = (item['product_id'] ?? item['product']?['id'])?.toString();
                      
                      String productName = 'منتج';
                      final rawName = item['product_name'] ?? item['product']?['name'] ?? item['title'];
                      
                      if (rawName is String && rawName.isNotEmpty) {
                        productName = rawName;
                      } else if (rawName is Map) {
                        productName = rawName['ar'] ?? rawName['en'] ?? (rawName.values.isNotEmpty ? rawName.values.first.toString() : 'منتج');
                      } else if (productId != null && _fetchedProductNames.containsKey(productId)) {
                        productName = _fetchedProductNames[productId]!;
                      } else if (productId != null) {
                        productName = 'منتج (معرف: $productId)';
                      }

                      final quantity = item['quantity'] ?? 1;
                      final unitPrice = (item['unit_price'] ?? item['price'] ?? 0).toDouble();
                      final itemTotal = item['total_price'] ?? (quantity * unitPrice);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isChecked ? Colors.green.withOpacity(0.05) : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isChecked ? Colors.green.withOpacity(0.3) : Colors.transparent,
                            width: 1.5,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              // زر التحديد الدائري مع أنيميشن هادئ
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isChecked) {
                                      _checkedItems.remove(index);
                                    } else {
                                      _checkedItems.add(index);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isChecked ? Colors.green : Colors.transparent,
                                    border: Border.all(
                                      color: isChecked ? Colors.green : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  child: isChecked
                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // تفاصيل المنتج واسمه عند النقر تفتح صفحة المنتج
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: productId != null ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductDetailsScreen(productId: productId),
                                      ),
                                    );
                                  } : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                productName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                                  color: isChecked ? Colors.grey : theme.textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                            ),
                                            if (productId != null && (_loadingProducts[productId] ?? false))
                                              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الكمية: $quantity  |  السعر: $unitPrice ل.س',
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // السعر الإجمالي للمنتج
                              Text(
                                '$itemTotal ل.س',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 16),

            // 4. الملخص المالي
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('طريقة الدفع', style: TextStyle(color: Colors.grey)),
                      Text(_currentOrder['payment_method'] ?? 'نقداً', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('حالة الدفع', style: TextStyle(color: Colors.grey)),
                      Text(_currentOrder['payment_status'] ?? 'غير مدفوع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المبلغ الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${_currentOrder['total_amount'] ?? 0} ل.س',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
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