import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../order_detail_screen.dart';

class ProcessingOrdersScreen extends StatefulWidget {
  const ProcessingOrdersScreen({super.key});

  @override
  State<ProcessingOrdersScreen> createState() => _ProcessingOrdersScreenState();
}

class _ProcessingOrdersScreenState extends State<ProcessingOrdersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'newest'; // خيار الفرز الافتراضي

  @override
  void initState() {
    super.initState();
    _fetchProcessingOrders();
    _searchController.addListener(_filterAndSortOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProcessingOrders() async {
    setState(() => _isLoading = true);
    try {
      Response response = await _apiService.dio.get('/orders/', queryParameters: {'status': 'processing'});
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
    
    // فلترة حسب البحث
    List<dynamic> temp = _orders.where((order) {
      final orderId = order['id'].toString().toLowerCase();
      return orderId.contains(query);
    }).toList();

    // تطبيق الفرز (الترتيب)
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

  Future<void> _moveToShipping(String orderId) async {
    try {
      await _apiService.dio.patch('/orders/$orderId/status', queryParameters: {'new_status': 'shipping'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز الطلب ونقله لقائمة الشحن'), backgroundColor: Colors.blue),
      );
      _fetchProcessingOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل نقل الطلب'), backgroundColor: Colors.red),
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
          // شريط البحث والفرز العلوي
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
                        hintText: 'ابحث برقم الطلب...',
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

          // القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('لا توجد طلبات قيد التجهيز مطابقة', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                                  _fetchProcessingOrders();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('تجهيز طلب #$shortId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(height: 4),
                                            Text('المبلغ: $amount ل.س', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _moveToShipping(orderId),
                                        child: const Text('تحويل للشحن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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