import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../order_detail_screen.dart';

class CompletedOrdersScreen extends StatefulWidget {
  const CompletedOrdersScreen({super.key});

  @override
  State<CompletedOrdersScreen> createState() => _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState extends State<CompletedOrdersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    _fetchCompletedOrders();
    _searchController.addListener(_filterAndSortOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompletedOrders() async {
    setState(() => _isLoading = true);
    try {
      Response response = await _apiService.dio.get('/orders/completed-logs');
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
      final orderId = (order['order_id'] ?? order['id']).toString().toLowerCase();
      final customerName = (order['customer_name'] ?? '').toString().toLowerCase();
      return orderId.contains(query) || customerName.contains(query);
    }).toList();

    if (_sortBy == 'newest') {
      temp.sort((a, b) => DateTime.parse(b['delivered_at'] ?? b['created_at'] ?? '').compareTo(DateTime.parse(a['delivered_at'] ?? a['created_at'] ?? '')));
    } else if (_sortBy == 'oldest') {
      temp.sort((a, b) => DateTime.parse(a['delivered_at'] ?? a['created_at'] ?? '').compareTo(DateTime.parse(b['delivered_at'] ?? b['created_at'] ?? '')));
    } else if (_sortBy == 'highest_price') {
      temp.sort((a, b) => (b['total_amount'] ?? 0.0).compareTo(a['total_amount'] ?? 0.0));
    } else if (_sortBy == 'lowest_price') {
      temp.sort((a, b) => (a['total_amount'] ?? 0.0).compareTo(b['total_amount'] ?? 0.0));
    }

    setState(() {
      _filteredOrders = temp;
    });
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
                            Icon(Icons.task_alt_rounded, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('لا توجد طلبات منجزة مطابقة', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          final String orderId = (order['order_id'] ?? order['id']).toString();
                          final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
                          final amount = order['total_amount'] ?? 0;
                          final customerName = order['customer_name'] ?? 'زائر';

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
                                onTap: () {
                                  final Map<String, dynamic> adaptedOrder = {
                                    ...Map<String, dynamic>.from(order),
                                    'status': 'completed',
                                    'items': (order['items_details'] as List? ?? []).map((item) {
                                      var pName = item['product_name'];
                                      if (pName is Map) {
                                        pName = pName['additionalProp1'] ?? 'منتج';
                                      }
                                      return {
                                        'quantity': item['quantity'],
                                        'unit_price': item['unit_price'],
                                        'product': {
                                          'name': pName ?? 'منتج',
                                        }
                                      };
                                    }).toList(),
                                  };

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => OrderDetailScreen(order: adaptedOrder)),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('طلب منجز #$shortId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(height: 4),
                                            Text('الزبون: $customerName', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                            const SizedBox(height: 2),
                                            Text('المبلغ الإجمالي: $amount ل.س', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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