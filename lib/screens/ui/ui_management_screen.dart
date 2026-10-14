import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/ui_manage_service.dart';
import '../offers/product_selection_screen.dart';

class UiManageScreen extends StatefulWidget {
  const UiManageScreen({super.key});

  @override
  State<UiManageScreen> createState() => _UiManageScreenState();
}

class _UiManageScreenState extends State<UiManageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _trendingKeywords = [];
  List<dynamic> _suggestedProducts = [];
  List<dynamic> _gridProducts = [];
  
  bool _isGridLoaded = false;
  String? _errorMessage;
  String _searchQuery = '';
  
  static const String _savedTabKey = 'ui_manage_active_tab_index';

  @override
  void initState() {
    super.initState();
    // تهيئة TabController بـ 3 تبويبات افتراضياً لحين قراءة الحفظ
    _tabController = TabController(length: 3, vsync: this);
    _loadSavedTabAndInit();
  }

  Future<void> _loadSavedTabAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_savedTabKey) ?? 0;

    if (savedIndex >= 0 && savedIndex < 3) {
      _tabController.index = savedIndex;
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        _saveCurrentTab(_tabController.index);
        if (_tabController.index == 2 && !_isGridLoaded) {
          _fetchGridProducts();
        }
      }
    });

    // إذا كان التبويب المحفوظ هو الثالث، نقوم بتحميل بياناته مباشرة
    if (_tabController.index == 2 && !_isGridLoaded) {
      _fetchGridProducts();
    }

    _initInitialData();
  }

  Future<void> _saveCurrentTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_savedTabKey, index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _initInitialData() async {
    setState(() => _isLoading = true);
    try {
      final trending = await UiManageService.getTrendingKeywords(forceRefresh: false);
      final suggested = await UiManageService.getSuggestedProducts(forceRefresh: false);

      if (mounted) {
        setState(() {
          _trendingKeywords = trending;
          _suggestedProducts = suggested;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'فشل تحميل بيانات الواجهة، تأكد من الاتصال بالسيرفر';
        });
      }
    }
  }

  Future<void> _fetchGridProducts({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final grid = await UiManageService.getGridProducts(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _gridProducts = grid;
          _isGridLoaded = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredTrending {
    if (_searchQuery.isEmpty) return _trendingKeywords;
    return _trendingKeywords.where((item) {
      final keyword = (item['keyword'] ?? '').toString().toLowerCase();
      return keyword.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredSuggested {
    if (_searchQuery.isEmpty) return _suggestedProducts;
    return _suggestedProducts.where((item) {
      final prodName = (item['product_name'] ?? '').toString().toLowerCase();
      return prodName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredGrid {
    if (_searchQuery.isEmpty) return _gridProducts;
    return _gridProducts.where((item) {
      final name = (item['product_name'] ?? item['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _deleteTrending(String id) async {
    _showLoadingDialog('جاري حذف الكلمة الرائجة...');
    bool success = await UiManageService.deleteTrendingKeyword(id);
    _hideLoadingDialog();

    if (success) {
      setState(() {
        _trendingKeywords.removeWhere((k) => k['id']?.toString() == id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الكلمة بنجاح'), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حذف الكلمة'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteSuggested(String recordId) async {
    _showLoadingDialog('جاري حذف المنتج المقترح...');
    bool success = await UiManageService.deleteSuggestedProduct(recordId);
    _hideLoadingDialog();

    if (success) {
      setState(() {
        _suggestedProducts.removeWhere((s) => s['record_id']?.toString() == recordId);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المنتج المقترح بنجاح'), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حذف المنتج المقترح'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteFeatured(String recordId) async {
    if (recordId.isEmpty) return;
    
    _showLoadingDialog('جاري حذف المنتج...');
    bool success = await UiManageService.deleteFeaturedProduct(recordId);
    _hideLoadingDialog();

    if (success) {
      setState(() {
        _gridProducts.removeWhere((p) => p['record_id']?.toString() == recordId);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المنتج من أبرز المنتجات'), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حذف المنتج'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddTrendingDialog() {
    final keywordController = TextEditingController();
    final orderController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة كلمة رائجة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keywordController,
              decoration: const InputDecoration(labelText: 'الكلمة (مثال: واقي شمسي)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: orderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ترتيب العرض (Display Order)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final kw = keywordController.text.trim();
              final order = int.tryParse(orderController.text) ?? 0;
              if (kw.isEmpty) return;

              Navigator.pop(context);
              _showLoadingDialog('جاري الحفظ...');
              bool success = await UiManageService.addTrendingKeyword(kw, order);
              _hideLoadingDialog();

              if (success) {
                final updated = await UiManageService.getTrendingKeywords(forceRefresh: true);
                setState(() => _trendingKeywords = updated);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة الكلمة بنجاح'), backgroundColor: Colors.green),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فشل حفظ الكلمة'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddSuggestedDialog() async {
    final selectedProducts = await Navigator.push<List<dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const ProductSelectionScreen(
          initialSelectedIds: [],
          isMultiSelect: false,
        ),
      ),
    );

    if (selectedProducts == null || selectedProducts.isEmpty) return;

    final product = selectedProducts.first;
    final productId = product['id']?.toString() ?? '';
    if (productId.isEmpty) return;

    final orderController = TextEditingController(text: '0');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديد ترتيب العرض للمنتج المقترح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المنتج: ${product['name'] is Map ? product['name']['ar'] ?? '' : product['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: orderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ترتيب العرض (Display Order)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final order = int.tryParse(orderController.text) ?? 0;

              Navigator.pop(context);
              _showLoadingDialog('جاري التعيين...');
              bool success = await UiManageService.setSuggestedProduct(productId, order);
              _hideLoadingDialog();

              if (success) {
                final updated = await UiManageService.getSuggestedProducts(forceRefresh: true);
                setState(() => _suggestedProducts = updated);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تعيين المنتج المقترح بنجاح'), backgroundColor: Colors.green),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فشل تعيين المنتج'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddFeaturedDialog() async {
    final selectedProducts = await Navigator.push<List<dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const ProductSelectionScreen(
          initialSelectedIds: [],
          isMultiSelect: false,
        ),
      ),
    );

    if (selectedProducts == null || selectedProducts.isEmpty) return;

    final product = selectedProducts.first;
    final productId = product['id']?.toString() ?? '';
    if (productId.isEmpty) return;

    final orderController = TextEditingController(text: '0');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة أبرز منتج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المنتج: ${product['name'] is Map ? product['name']['ar'] ?? '' : product['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: orderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ترتيب العرض (Display Order)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final order = int.tryParse(orderController.text) ?? 0;

              Navigator.pop(context);
              _showLoadingDialog('جاري الإضافة...');
              bool success = await UiManageService.addFeaturedProduct(productId, order);
              _hideLoadingDialog();

              if (success) {
                final updated = await UiManageService.getGridProducts(forceRefresh: true);
                setState(() {
                  _gridProducts = updated;
                  _isGridLoaded = true;
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة المنتج إلى أبرز المنتجات بنجاح'), backgroundColor: Colors.green),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فشل إضافة المنتج'), backgroundColor: Colors.red),
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
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final searchFieldColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'الكلمات الرائجة', icon: Icon(Icons.trending_up, size: 20)),
                Tab(text: 'مقترحات البحث', icon: Icon(Icons.search, size: 20)),
                Tab(text: 'أبرز المنتجات', icon: Icon(Icons.star_outline, size: 20)),
              ],
            ),
          ),
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
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: _tabController.index == 0
                            ? 'ابحث في الكلمات الرائجة...'
                            : _tabController.index == 1
                                ? 'ابحث في مقترحات البحث...'
                                : 'ابحث في أبرز المنتجات...',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
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
                    onPressed: _tabController.index == 0
                        ? _showAddTrendingDialog
                        : _tabController.index == 1
                            ? _showAddSuggestedDialog
                            : _showAddFeaturedDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      _tabController.index == 0
                          ? 'إضافة كلمة'
                          : _tabController.index == 1
                              ? 'تعيين منتج'
                              : 'إضافة منتج',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _tabController.index != 2 && _trendingKeywords.isEmpty
                ? ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
                    itemCount: 4,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  )
                : _errorMessage != null && _trendingKeywords.isEmpty
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTrendingList(theme, isDesktop),
                          _buildSuggestedList(theme, isDesktop),
                          _buildGridProductsList(theme, isDesktop),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingList(ThemeData theme, bool isDesktop) {
    final list = _filteredTrending;
    if (list.isEmpty) return const Center(child: Text('لا توجد كلمات رائجة مضافة'));

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final id = item['id']?.toString() ?? '';
        final keyword = item['keyword']?.toString() ?? '';
        final order = item['display_order'] ?? 0;
        final isActive = item['is_active'] == true;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Slidable(
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.25,
                children: [
                  SlidableAction(
                    onPressed: (_) => _deleteTrending(id),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(child: Icon(Icons.trending_up, size: 20)),
                  title: Text(keyword, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('ترتيب العرض: $order', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive ? 'مفعل' : 'متوقف',
                      style: TextStyle(fontSize: 11, color: isActive ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestedList(ThemeData theme, bool isDesktop) {
    final list = _filteredSuggested;
    if (list.isEmpty) return const Center(child: Text('لا توجد منتجات مقترحة مضافة'));

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final recordId = item['record_id']?.toString() ?? '';
        final prodName = item['product_name']?.toString() ?? 'منتج غير معروف';
        final imageUrl = item['thumbnail_url']?.toString();
        final order = item['display_order'] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Slidable(
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.25,
                children: [
                  SlidableAction(
                    onPressed: (_) => _deleteSuggested(recordId),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.withOpacity(0.1),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))
                          : const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                  title: Text(prodName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('ترتيب العرض في البحث: $order', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridProductsList(ThemeData theme, bool isDesktop) {
    if (!_isGridLoaded && _isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final list = _filteredGrid;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('لا توجد بيانات لأبرز المنتجات'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _fetchGridProducts(forceRefresh: true),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final prod = list[index];
        final recordId = prod['record_id']?.toString() ?? '';
        final prodName = prod['product_name']?.toString() ?? prod['name']?.toString() ?? 'منتج';
        final imageUrl = prod['thumbnail_url']?.toString();
        final price = prod['price'] ?? 0;
        final order = prod['display_order'] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Slidable(
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.25,
                children: [
                  SlidableAction(
                    onPressed: (_) => _deleteFeatured(recordId),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.withOpacity(0.1),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))
                          : const Icon(Icons.image_not_supported),
                    ),
                  ),
                  title: Text(prodName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('السعر: $price ل.س | ترتيب العرض: $order', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.star, color: Colors.amber, size: 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}