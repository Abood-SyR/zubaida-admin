import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../order_detail_screen.dart';

class ShippingOrdersScreen extends StatefulWidget {
  const ShippingOrdersScreen({super.key});

  @override
  State<ShippingOrdersScreen> createState() => _ShippingOrdersScreenState();
}

class _ShippingOrdersScreenState extends State<ShippingOrdersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    _fetchShippingOrders();
    _searchController.addListener(_filterAndSortOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchShippingOrders() async {
    setState(() => _isLoading = true);
    try {
      Response response = await _apiService.dio.get('/orders/', queryParameters: {'status': 'shipping'});
      setState(() {
        _orders = response.data;
        _filterAndSortOrders();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterAndSortOrders() {
    final query = _searchController.text.toLowerCase();
    
    List<dynamic> temp = _orders.where((order) {
      final orderId = order['id'].toString().toLowerCase();
      final addressData = order['shipping_address'];
      String customerName = '';
      if (addressData is Map) {
        customerName = (addressData['name'] ?? '').toString().toLowerCase();
      }
      return orderId.contains(query) || customerName.contains(query);
    }).toList();

    if (_sortBy == 'newest') {
      temp.sort((a, b) => DateTime.parse(b['created_at'] ?? '').compareTo(DateTime.parse(a['created_at'] ?? '')));
    } else if (_sortBy == 'oldest') {
      temp.sort((a, b) => DateTime.parse(a['created_at'] ?? '').compareTo(DateTime.parse(b['created_at'] ?? '')));
    } else if (_sortBy == 'highest_price') {
      temp.sort((a, b) => (b['total_amount'] ?? 0.0).compareTo(a['total_amount'] ?? 0.0));
    } else if (_sortBy == 'lowest_price') {
      temp.sort((a, b) => (a['total_amount'] ?? 0.0).compareTo(b['total_amount'] ?? 0.0));
    }

    setState(() {
      _filteredOrders = temp;
    });
  }

  Future<void> _completeDelivery(String orderId) async {
    try {
      await _apiService.dio.patch('/orders/$orderId/status', queryParameters: {'new_status': 'completed'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد توصيل وإنجاز الطلب بنجاح وتسجيل البيانات للتحليل'), backgroundColor: Colors.green),
      );
      _fetchShippingOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تأكيد التوصيل'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'ابحث برقم الطلب أو اسم الزبون...',
                        border: InputBorder.none,
                        icon: Icon(Icons.search_rounded, color: Colors.blueGrey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: const Icon(Icons.sort_rounded, color: Colors.blueGrey),
                      items: const [
                        DropdownMenuItem(value: 'newest', child: Text('الأحدث', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'oldest', child: Text('الأقدم', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'highest_price', child: Text('الأعلى سعراً', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'lowest_price', child: Text('الأقل سعراً', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sortBy = value;
                            _filterAndSortOrders();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('لا توجد طلبات قيد التوصيل مطابقة', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          final String orderId = order['id'].toString();
                          final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
                          
                          final addressData = order['shipping_address'];
                          String customerName = 'زائر';
                          String addressText = 'عنوان غير محدد';
                          String phone = '-';

                          if (addressData is Map) {
                            customerName = addressData['name'] ?? 'زائر';
                            addressText = addressData['address_text'] ?? addressData['address'] ?? 'عنوان غير محدد';
                            phone = addressData['phone'] ?? '-';
                          }

                          final amount = order['total_amount'] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order)),
                                  );
                                  _fetchShippingOrders();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('طلب توصيل #$shortId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          Text('$amount ل.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 14, color: Colors.blueGrey),
                                          const SizedBox(width: 4),
                                          Text('الزبون: $customerName', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(addressText, style: const TextStyle(color: Colors.grey, fontSize: 13))),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () => _completeDelivery(orderId),
                                          icon: const Icon(Icons.check_circle_outline, size: 16),
                                          label: const Text('تأكيد التوصيل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}