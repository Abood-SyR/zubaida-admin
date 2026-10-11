import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/api_service.dart';
// تأكد من استيراد صفحة تفاصيل الطلب لديك
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required String statusFilter});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20; // عدد الطلبات في كل جلب لتستوعب آلاف الطلبات بسلاسة
  List<dynamic> _orders = [];
  String? _errorMessage;
  
  // نظام الفلاتر العلوي
  String? _selectedStatusFilter;
  final List<Map<String, String>> _statusFilters = [
    {'key': '', 'label': 'الكل'},
    {'key': 'pending', 'label': 'قيد المراجعة'},
    {'key': 'processing', 'label': 'قيد التجهيز'},
    {'key': 'shipped', 'label': 'تم الشحن'},
    {'key': 'completed', 'label': 'مكتمل'},
    {'key': 'cancelled', 'label': 'ملغي'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchOrders(loadMore: true);
    }
  }

  Future<void> _fetchOrders({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
      });
    }

    try {
      Map<String, dynamic> queryParams = {'limit': _limit, 'offset': _offset};
      if (_selectedStatusFilter != null && _selectedStatusFilter!.isNotEmpty) {
        queryParams['status'] = _selectedStatusFilter;
      }

      Response response = await _apiService.dio.get(
        '/orders/',
        queryParameters: queryParams,
      );
      
      final List<dynamic> newOrders = response.data;
      setState(() {
        if (loadMore) {
          _orders.addAll(newOrders);
        } else {
          _orders = newOrders;
        }
        if (newOrders.length < _limit) {
          _hasMore = false;
        }
        _offset += _limit;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل تحميل الطلبات. تأكد من تسجيل الدخول.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'processing': return 'قيد التجهيز';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // شريط الفلاتر الأفقي العلوي
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedStatusFilter == filter['key'] || 
                    (filter['key'] == '' && _selectedStatusFilter == null);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatusFilter = filter['key'] == '' ? null : filter['key'];
                      });
                      _fetchOrders();
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // قائمة الطلبات المدمجة (Compact) لتتحمل آلاف الطلبات بسلاسة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _orders.isEmpty
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _orders.isEmpty
                        ? const Center(child: Text('لا توجد طلبات مطابقة', style: TextStyle(color: Colors.grey)))
                        : RefreshIndicator(
                            onRefresh: () => _fetchOrders(),
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _orders.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _orders.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                final order = _orders[index];
                                final String orderId = order['id'].toString();
                                final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
                                final status = order['status'] ?? 'pending';
                                
                                // استخراج بيانات العميل وعنوانه بمرونة
                                final address = order['shipping_address'];
                                String name = 'زائر / غير محدد';
                                String phone = '-';
                                if (address is Map) {
                                  name = address['name'] ?? 'بدون اسم';
                                  phone = address['phone'] ?? '-';
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  elevation: 1,
                                  child: ListTile(
                                    dense: true, // تصغير حجم العنصر لملء الشاشة بطلبkات كثيرة
                                    leading: CircleAvatar(
                                      backgroundColor: _getStatusColor(status).withOpacity(0.2),
                                      child: Text(
                                        '#$shortId',
                                        style: TextStyle(fontSize: 10, color: _getStatusColor(status), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      'العميل: $name | الهاتف: $phone',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      'المبلغ: ${order['total_amount']} ل.س | الدفع: ${order['payment_method']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        _translateStatus(status),
                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                      backgroundColor: _getStatusColor(status),
                                    ),
                                    // النقر سينقلك حصرياً إلى صفحة تفاصيل الطلب المخصصة
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => OrderDetailScreen(order: order),
                                        ),
                                      ).then((_) {
                                        // إعادة تحميل القائمة عند العودة في حال تم تعديل حالة الطلب في صفحة التفاصيل
                                        _fetchOrders();
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}