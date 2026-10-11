import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/api_service.dart';

class ProductSelectionScreen extends StatefulWidget {
  final List<String> initialSelectedIds;
  final bool isMultiSelect;

  const ProductSelectionScreen({
    super.key,
    required this.initialSelectedIds,
    this.isMultiSelect = true,
  });

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  static List<dynamic>? _cachedProducts; // التخزين المؤقت لعدم إعادة جلب المنتجات كل مرة
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  List<dynamic> _products = [];
  late List<String> _selectedIds;
  String _searchQuery = '';
  String _sortBy = 'name'; // خيارات الفلترة: name, price_high, price_low, stock

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelectedIds);
    _loadProducts();
  }

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProducts != null) {
      setState(() {
        _products = _cachedProducts!;
        _isLoading = false;
      });
      return;
    }

    try {
      Response response = await _apiService.dio.get('/products/');
      _cachedProducts = response.data as List<dynamic>;
      setState(() {
        _products = _cachedProducts!;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحميل المنتجات'), backgroundColor: Colors.red),
      );
    }
  }

  String _getProductName(dynamic nameField) {
    if (nameField is Map) {
      return nameField['ar']?.toString() ?? nameField.values.first?.toString() ?? 'بدون اسم';
    }
    return nameField?.toString() ?? 'بدون اسم';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // تصفية المنتجات بالبحث
    var filteredProducts = _products.where((product) {
      if (_searchQuery.isEmpty) return true;
      final name = _getProductName(product['name']).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    // تطبيق الفلترة والترتيب
    filteredProducts.sort((a, b) {
      if (_sortBy == 'price_high') {
        final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return priceB.compareTo(priceA);
      } else if (_sortBy == 'price_low') {
        final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return priceA.compareTo(priceB);
      } else if (_sortBy == 'stock') {
        final stockA = int.tryParse(a['stock']?.toString() ?? '0') ?? 0;
        final stockB = int.tryParse(b['stock']?.toString() ?? '0') ?? 0;
        return stockA.compareTo(stockB);
      } else {
        return _getProductName(a['name']).compareTo(_getProductName(b['name']));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMultiSelect ? 'اختر منتجات الحزمة' : 'اختر المنتج', style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadProducts(forceRefresh: true);
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                '(${_selectedIds.length})',
                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث وفلتر الترتيب
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'ابحث في المنتجات...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: const Icon(Icons.sort, size: 20),
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('الاسم', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'price_high', child: Text('الأغلى سعراً', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'price_low', child: Text('الأرخص سعراً', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'stock', child: Text('الأقل مخزوناً', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setState(() => _sortBy = val ?? 'name'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : filteredProducts.isEmpty
                    ? const Center(child: Text('لا توجد منتجات مطابقة للبحث'))
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          final id = product['id']?.toString() ?? '';
                          final name = _getProductName(product['name']);
                          final price = product['price']?.toString() ?? '0';
                          final stock = product['stock']?.toString() ?? '0';
                          final imageUrl = product['thumbnail_url']?.toString();
                          final isSelected = _selectedIds.contains(id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (widget.isMultiSelect) {
                                  if (value == true) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                } else {
                                  _selectedIds = value == true ? [id] : [];
                                }
                              });
                            },
                            secondary: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 45,
                                height: 45,
                                color: Colors.grey.withOpacity(0.1),
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image))
                                    : const Icon(Icons.image, size: 20, color: Colors.grey),
                              ),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('السعر: $price ل.س | المخزون: $stock', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          );
                        },
                      ),
          ),

          // زر الموافقة في الأسفل (يُرجع تفاصيل المنتجات كاملة مع أسعارها)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // تصفية وإرجاع كائنات المنتجات الكاملة التي تتضمن الأسعار
                  final selectedProductsData = _products.where((p) => _selectedIds.contains(p['id']?.toString())).toList();
                  Navigator.pop(context, selectedProductsData);
                },
                child: Text('موافق (${_selectedIds.length} منتج مختار)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}