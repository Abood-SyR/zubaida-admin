import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/api_service.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import 'product_details_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  String? _errorMessage;

  // متغيرات التصفح التدريجي (Pagination)
  int _displayedLimit = 10;
  bool _hasMore = true;

  bool _isSearchOverlayOpen = false;
  late AnimationController _animController;
  late Animation<double> _slideAnimation;

  String _searchQuery = '';
  String _sortBy = 'newest';
  double _maxPriceFilter = 5000.0;
  
  bool? _filterIsActive;
  String? _filterSkinHairType;
  String? _filterCategoryId;
  bool _filterInStockOnly = false;

  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );

    _scrollController.addListener(_onScroll);

    _loadRecentSearches();
    _initDataCache();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _loadMoreProducts() {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    // محاكاة تحميل المزيد تدريجياً من القائمة المحلية
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _displayedLimit += 10;
        if (_displayedLimit >= _filteredAndSortedProducts.length) {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    });
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 3),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  Future<void> _initDataCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedProducts = prefs.getString('cached_products_list');
    final cachedCategories = prefs.getString('cached_categories_list');

    setState(() {
      if (cachedProducts != null) {
        try {
          _products = jsonDecode(cachedProducts) as List<dynamic>;
        } catch (_) {}
      }
      if (cachedCategories != null) {
        try {
          _categories = jsonDecode(cachedCategories) as List<dynamic>;
        } catch (_) {}
      }
      if (_products.isNotEmpty) {
        _isLoading = false;
      }
    });

    await Future.wait([
      _fetchCategoriesInBackground(),
      _fetchProductsInBackground(),
    ]);

    if (_isLoading) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCategoriesInBackground() async {
    try {
      Response response = await _apiService.dio.get('/categories/?include_inactive=true');
      final data = response.data as List<dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_categories_list', jsonEncode(data));

      if (mounted) {
        setState(() {
          _categories = data;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchProductsInBackground() async {
    try {
      Response response = await _apiService.dio.get('/products/?include_inactive=true');
      final data = response.data as List<dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_products_list', jsonEncode(data));

      if (mounted) {
        setState(() {
          _products = data;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (_products.isEmpty) {
        setState(() {
          _errorMessage = 'فشل تحميل المنتجات، تأكد من الاتصال بالسيرفر';
        });
      }
    }
  }

  // دالة لجلب منتج معين عبر الإنترنت في حال لم يُوجد محلياً أثناء البحث
  Future<void> _searchProductFromApi(String query) async {
    _showLoadingDialog('جاري البحث في السيرفر...');
    try {
      // افتراضية للبحث عبر الـ API إذا كان السيرفر يدعم استعلام بالاسم، أو جلب المنتج مباشرة برقم معرّف إذا كان مدخلاً كـ ID
      Response response = await _apiService.dio.get('/products/search', queryParameters: {'q': query});
      final List<dynamic> searchResults = response.data is List ? response.data : [response.data];
      
      _hideLoadingDialog();
      if (searchResults.isNotEmpty) {
        setState(() {
          // دمج النتائج الجديدة مع القائمة الحالية تفادياً للتكرار
          for (var p in searchResults) {
            if (!_products.any((existing) => existing['id'].toString() == p['id'].toString())) {
              _products.insert(0, p);
            }
          }
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على المنتج في السيرفر')),
        );
      }
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، فشل جلب المنتج من الإنترنت'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 3) {
        _recentSearches = _recentSearches.sublist(0, 3);
      }
    });
    await prefs.setStringList('recent_searches', _recentSearches);
  }

  void _toggleSearchOverlay() {
    setState(() {
      _isSearchOverlayOpen = !_isSearchOverlayOpen;
      if (_isSearchOverlayOpen) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  String _getProductName(dynamic nameField) {
    if (nameField is Map) {
      return nameField['ar']?.toString() ?? 
             nameField['additionalProp1']?.toString() ?? 
             (nameField.isNotEmpty ? nameField.values.first?.toString() : null) ?? 
             'بدون اسم';
    }
    return nameField?.toString() ?? 'بدون اسم';
  }

  List<dynamic> get _filteredAndSortedProducts {
    List<dynamic> list = _products.where((product) {
      final price = double.tryParse(product['price'].toString()) ?? 0.0;
      if (price > _maxPriceFilter) return false;

      if (_filterIsActive != null) {
        final isActive = product['is_active'] == true;
        if (isActive != _filterIsActive) return false;
      }

      if (_filterInStockOnly) {
        final stock = int.tryParse(product['stock_quantity'].toString()) ?? 0;
        if (stock <= 0) return false;
      }

      if (_filterSkinHairType != null && _filterSkinHairType!.isNotEmpty) {
        final skinHairTypes = product['skin_hair_type'];
        if (skinHairTypes is List) {
          if (!skinHairTypes.contains(_filterSkinHairType)) return false;
        } else {
          return false;
        }
      }

      if (_filterCategoryId != null && _filterCategoryId!.isNotEmpty) {
        if (product['category_id']?.toString() != _filterCategoryId) return false;
      }

      if (_searchQuery.isEmpty) return true;
      final name = _getProductName(product['name']).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    list.sort((a, b) {
      if (_sortBy == 'price_desc') {
        return (double.tryParse(b['price'].toString()) ?? 0.0)
            .compareTo(double.tryParse(a['price'].toString()) ?? 0.0);
      } else if (_sortBy == 'price_asc') {
        return (double.tryParse(a['price'].toString()) ?? 0.0)
            .compareTo(double.tryParse(b['price'].toString()) ?? 0.0);
      } else if (_sortBy == 'stock') {
        return (int.tryParse(b['stock_quantity'].toString()) ?? 0)
            .compareTo(int.tryParse(a['stock_quantity'].toString()) ?? 0);
      } else if (_sortBy == 'sold') {
        return (int.tryParse(b['sold_count'].toString()) ?? 0)
            .compareTo(int.tryParse(a['sold_count'].toString()) ?? 0);
      }
      return 0;
    });

    return list;
  }

  Future<void> _toggleProductStatus(Map<String, dynamic> product) async {
    final productId = product['id']?.toString() ?? '';
    final currentStatus = product['is_active'] == true;
    final newStatus = !currentStatus;

    _showLoadingDialog(newStatus ? 'جاري تفعيل المنتج...' : 'جاري إيقاف المنتج...');

    try {
      await _apiService.dio.patch(
        '/products/$productId/status',
        data: {"is_active": newStatus},
      );
      
      setState(() {
        product['is_active'] = newStatus;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_products_list', jsonEncode(_products));

      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'تم تفعيل المنتج بنجاح' : 'تم وقف المنتج بنجاح'), 
          backgroundColor: newStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تغيير حالة المنتج'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج نهائياً وصوره من السيرفر؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog('جاري حذف المنتج وصوره...');

    try {
      await _apiService.dio.delete('/products/$productId');
      setState(() {
        _products.removeWhere((p) => p['id']?.toString() == productId);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_products_list', jsonEncode(_products));

      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المنتج بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حذف المنتج'), backgroundColor: Colors.red),
      );
    }
  }

  void _showQuickUpdatePriceDialog(Map<String, dynamic> product) {
    final priceController = TextEditingController(text: product['price']?.toString() ?? '0');
    final costController = TextEditingController(text: product['cost_price']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل سعر: ${_getProductName(product['name'])}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سعر البيع الجديد', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سعر التكلفة الجديد', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showLoadingDialog('جاري تحديث السعر...');

              try {
                final newPrice = double.tryParse(priceController.text) ?? 0.0;
                final newCost = double.tryParse(costController.text);

                await _apiService.dio.patch(
                  '/products/${product['id']}/price',
                  data: {"price": newPrice, "cost_price": newCost},
                );

                _hideLoadingDialog();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث السعر بنجاح'), backgroundColor: Colors.green),
                );
                _fetchProductsInBackground();
              } catch (e) {
                _hideLoadingDialog();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فشل تحديث السعر'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showQuickUpdateStockDialog(Map<String, dynamic> product) {
    final stockController = TextEditingController(text: product['stock_quantity']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل مخزون: ${_getProductName(product['name'])}'),
        content: TextField(
          controller: stockController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الكمية الجديدة للمخزون', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showLoadingDialog('جاري تحديث المخزون...');

              try {
                final newStock = int.tryParse(stockController.text) ?? 0;

                await _apiService.dio.patch(
                  '/products/${product['id']}/stock',
                  data: {"stock_quantity": newStock},
                );

                _hideLoadingDialog();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث المخزون بنجاح'), backgroundColor: Colors.green),
                );
                _fetchProductsInBackground();
              } catch (e) {
                _hideLoadingDialog();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فشل تحديث المخزون'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allFiltered = _filteredAndSortedProducts;
    final displayedProducts = allFiltered.take(_displayedLimit).toList();
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final searchFieldColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: searchFieldColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onTap: () {
                            if (!_isSearchOverlayOpen) _toggleSearchOverlay();
                          },
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                              _displayedLimit = 10; // إعادة ضبط العداد عند البحث
                              if (_isSearchOverlayOpen) {
                                _isSearchOverlayOpen = false;
                                _animController.reverse();
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'ابحث عن منتج...',
                            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.cloud_download_rounded, size: 18),
                                        tooltip: 'البحث عبر السيرفر',
                                        onPressed: () => _searchProductFromApi(_searchQuery),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _searchQuery = '';
                                            _searchController.clear();
                                          });
                                        },
                                      ),
                                    ],
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: searchFieldColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isSearchOverlayOpen ? Icons.close_rounded : Icons.tune_rounded,
                          color: theme.iconTheme.color,
                          size: 20,
                        ),
                        onPressed: _toggleSearchOverlay,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddProductScreen()),
                          );
                          if (result == true) _fetchProductsInBackground();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading && _products.isEmpty
                    ? ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
                        itemCount: 6,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Shimmer.fromColors(
                            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      )
                    : _errorMessage != null && _products.isEmpty
                        ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                        : displayedProducts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('لا توجد منتجات مطابقة محلياً'),
                                    const SizedBox(height: 12),
                                    if (_searchQuery.isNotEmpty)
                                      ElevatedButton.icon(
                                        onPressed: () => _searchProductFromApi(_searchQuery),
                                        icon: const Icon(Icons.cloud_download),
                                        label: const Text('البحث عنها عبر الإنترنت'),
                                      ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
                                itemCount: displayedProducts.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == displayedProducts.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: Shimmer.fromColors(
                                          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                                          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                                          child: Container(
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final product = displayedProducts[index];
                                  final productName = _getProductName(product['name']);
                                  final price = product['price']?.toString() ?? '0';
                                  final stock = product['stock_quantity']?.toString() ?? '0';
                                  final imageUrl = product['thumbnail_url']?.toString();
                                  final productId = product['id']?.toString() ?? '';
                                  final isActive = product['is_active'] == true;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Slidable(
                                        endActionPane: ActionPane(
                                          motion: const ScrollMotion(),
                                          extentRatio: 0.45,
                                          children: [
                                            SlidableAction(
                                              onPressed: (_) async {
                                                final result = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => EditProductScreen(product: product),
                                                  ),
                                                );
                                                if (result == true) _fetchProductsInBackground();
                                              },
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: theme.colorScheme.primary,
                                              icon: Icons.edit_outlined,
                                            ),
                                            SlidableAction(
                                              onPressed: (_) => _toggleProductStatus(product),
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: isActive ? Colors.orange : Colors.green,
                                              icon: isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                            ),
                                            SlidableAction(
                                              onPressed: (_) => _deleteProduct(productId),
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: Colors.redAccent,
                                              icon: Icons.delete_outline_rounded,
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: theme.cardColor,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.grey.withOpacity(0.08)),
                                          ),
                                          child: ListTile(
                                            onTap: () {
                                              if (productId.isNotEmpty) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ProductDetailsScreen(productId: productId),
                                                  ),
                                                );
                                              }
                                            },
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            leading: Hero(
                                              tag: 'product_image_$productId',
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  width: 50,
                                                  height: 50,
                                                  color: Colors.grey.withOpacity(0.1),
                                                  child: imageUrl != null && imageUrl.isNotEmpty
                                                      ? Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) =>
                                                              const Icon(Icons.image_not_supported, color: Colors.grey),
                                                        )
                                                      : const Icon(Icons.image, color: Colors.grey),
                                                ),
                                              ),
                                            ),
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    productName,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isActive ? null : Colors.grey,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (!isActive)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text('متوقف', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                                  ),
                                              ],
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Row(
                                                children: [
                                                  InkWell(
                                                    onTap: () => _showQuickUpdatePriceDialog(product),
                                                    child: Text('السعر: $price ⟳', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                                                  ),
                                                  const Text('  •  ', style: TextStyle(color: Colors.grey)),
                                                  InkWell(
                                                    onTap: () => _showQuickUpdateStockDialog(product),
                                                    child: Text('المخزون: $stock ⟳', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 12)),
                                                  ),
                                                ],
                                              ),
                                            ),
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

          if (_isSearchOverlayOpen)
            Positioned.fill(
              top: isDesktop ? 88 : 72,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _toggleSearchOverlay,
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(_slideAnimation),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: searchFieldColor,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_recentSearches.isNotEmpty) ...[
                              const Text('عمليات البحث الأخيرة',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _recentSearches.map((term) => ActionChip(
                                      label: Text(term, style: const TextStyle(fontSize: 12)),
                                      backgroundColor: theme.cardColor,
                                      side: BorderSide.none,
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery = term;
                                          _searchController.text = term;
                                          _displayedLimit = 10;
                                        });
                                        _toggleSearchOverlay();
                                      },
                                    )).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],

                            const Text('التصنيف (الفئات)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildUniformChip('الكل', null, _filterCategoryId == null, () => setState(() => _filterCategoryId = null)),
                                ..._categories.map((cat) {
                                  final catId = cat['id']?.toString() ?? '';
                                  final catName = _getProductName(cat['name']);
                                  return _buildUniformChip(catName, catId, _filterCategoryId == catId, () => setState(() => _filterCategoryId = catId));
                                }),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text('ترتيب النتائج', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildUniformChip('الأحدث', 'newest', _sortBy == 'newest', () => setState(() => _sortBy = 'newest')),
                                _buildUniformChip('الأقدم', 'oldest', _sortBy == 'oldest', () => setState(() => _sortBy = 'oldest')),
                                _buildUniformChip('الأعلى سعراً', 'price_desc', _sortBy == 'price_desc', () => setState(() => _sortBy = 'price_desc')),
                                _buildUniformChip('الأقل سعراً', 'price_asc', _sortBy == 'price_asc', () => setState(() => _sortBy = 'price_asc')),
                                _buildUniformChip('الأعلى مخزوناً', 'stock', _sortBy == 'stock', () => setState(() => _sortBy = 'stock')),
                                _buildUniformChip('الأكثر مبيعاً', 'sold', _sortBy == 'sold', () => setState(() => _sortBy = 'sold')),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text('حالة التوفر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildUniformChip('الكل', 'all_stock', !_filterInStockOnly, () => setState(() => _filterInStockOnly = false)),
                                _buildUniformChip('المتوفر بالمخزون فقط', 'in_stock', _filterInStockOnly, () => setState(() => _filterInStockOnly = true)),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text('حالة النشاط', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildUniformChip('الكل', null, _filterIsActive == null, () => setState(() => _filterIsActive = null)),
                                _buildUniformChip('نشط', true, _filterIsActive == true, () => setState(() => _filterIsActive = true)),
                                _buildUniformChip('متوقف', false, _filterIsActive == false, () => setState(() => _filterIsActive = false)),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text('نوع الاستخدام', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildUniformChip('الكل', null, _filterSkinHairType == null, () => setState(() => _filterSkinHairType = null)),
                                _buildUniformChip('شعر (Hair)', 'hair', _filterSkinHairType == 'hair', () => setState(() => _filterSkinHairType = 'hair')),
                                _buildUniformChip('بشرة (Skin)', 'skin', _filterSkinHairType == 'skin', () => setState(() => _filterSkinHairType = 'skin')),
                                _buildUniformChip('جسم (Body)', 'body', _filterSkinHairType == 'body', () => setState(() => _filterSkinHairType = 'body')),
                              ],
                            ),
                            const SizedBox(height: 24),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الحد الأقصى للسعر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text('${_maxPriceFilter.toInt()} ل.س', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Slider(
                              value: _maxPriceFilter,
                              min: 10,
                              max: 10000,
                              divisions: 100,
                              onChanged: (val) => setState(() => _maxPriceFilter = val),
                            ),
                            const SizedBox(height: 30),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  _saveSearchQuery(_searchQuery);
                                  setState(() => _displayedLimit = 10);
                                  _toggleSearchOverlay();
                                },
                                child: const Text('تطبيق الفلاتر والبحث', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUniformChip(String label, dynamic value, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final selectedBg = theme.brightness == Brightness.dark 
        ? Colors.white.withOpacity(0.15) 
        : Colors.black.withOpacity(0.08);

    return ChoiceChip(
      label: Text(
        label, 
        style: TextStyle(
          fontSize: 12, 
          color: isSelected ? theme.textTheme.bodyLarge?.color : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      // selectedCardColor: selectedBg,
      selectedColor: selectedBg,
      backgroundColor: theme.cardColor,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (val) => onTap(),
      showCheckmark: false,
    );
  }
}