import 'package:dashboard/core/utils/image_helper.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/api_service.dart';
import 'edit_product_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _product;
  String? _errorMessage;
  
  bool _isThumbnailSelected = true;
  int _selectedSubImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
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

  Future<void> _fetchProductDetails() async {
    try {
      Response response = await _apiService.dio.get('/products/${widget.productId}');
      setState(() {
        _product = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل تحميل تفاصيل المنتج';
        _isLoading = false;
      });
    }
  }

  String _getText(dynamic field) {
    if (field is Map) {
      return field['ar']?.toString() ?? field.values.first?.toString() ?? 'غير متوفر';
    }
    return field?.toString() ?? 'غير متوفر';
  }

  Future<void> _toggleProductStatus() async {
    if (_product == null) return;
    final bool currentStatus = _product!['is_active'] ?? true;
    final bool newStatus = !currentStatus;

    _showLoadingDialog(newStatus ? 'جاري تفعيل المنتج...' : 'جاري إيقاف المنتج...');
    
    try {
      await _apiService.dio.patch(
        '/products/${widget.productId}/status',
        data: {"is_active": newStatus},
      );
      setState(() {
        _product!['is_active'] = newStatus;
      });

      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'تم تفعيل المنتج بنجاح' : 'تم إيقاف/تعطيل المنتج بنجاح'),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحديث حالة المنتج'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج نهائياً من السيرفر؟'),
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
      await _apiService.dio.delete('/products/${widget.productId}');
      
      _hideLoadingDialog();
      if (!mounted) return;
      Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isActive = _product?['is_active'] ?? true;

    final String? thumbnailUrl = _product?['thumbnail_url'];
    final List subImages = _product?['images'] ?? [];

    String activeDisplayImage = '';
    if (_isThumbnailSelected && thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      activeDisplayImage = thumbnailUrl;
    } else if (subImages.isNotEmpty) {
      if (_selectedSubImageIndex >= subImages.length) {
        _selectedSubImageIndex = 0;
      }
      activeDisplayImage = subImages[_selectedSubImageIndex]?.toString() ?? '';
    } else if (thumbnailUrl != null) {
      activeDisplayImage = thumbnailUrl;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'تفاصيل وتحليلات المنتج',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
        ),
        iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color),
        actions: [
          if (_product != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  isActive ? 'نشط' : 'متوقف',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.red),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 280,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(
                            4,
                            (index) => Container(
                              width: 70,
                              height: 75,
                              margin: const EdgeInsets.only(left: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(width: 220, height: 28, color: Colors.white),
                        const SizedBox(height: 10),
                        Container(width: double.infinity, height: 45, color: Colors.white),
                        const SizedBox(height: 20),
                        Row(
                          children: List.generate(
                            4,
                            (index) => Expanded(
                              child: Container(
                                height: 75,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
              : _product == null
                  ? const Center(child: Text('المنتج غير موجود'))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 850),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (activeDisplayImage.isNotEmpty) ...[
                                Hero(
                                  tag: 'product_image_${widget.productId}',
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 280,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey[900] : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(24),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        // تقييد الصورة داخل حاوية مؤمنة بـ SizedBox و optimizedNetworkImage
                                        child: SizedBox(
                                          height: 280,
                                          width: double.infinity,
                                          child: optimizedNetworkImage(
                                            imageUrl: activeDisplayImage,
                                            width: double.infinity,
                                            height: 280,
                                            fit: BoxFit.contain,
                                            cacheWidth: 800,
                                            cacheHeight: 800,
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _isThumbnailSelected ? 'الصورة الرئيسية' : 'صورة فرعية (${_selectedSubImageIndex + 1})',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                SizedBox(
                                  height: 75,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                                        GestureDetector(
                                          onTap: () => setState(() => _isThumbnailSelected = true),
                                          child: Container(
                                            width: 70,
                                            height: 75,
                                            margin: const EdgeInsets.only(left: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[900] : Colors.grey[100],
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: _isThumbnailSelected ? theme.colorScheme.primary : Colors.transparent,
                                                width: 2.5,
                                              ),
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                optimizedNetworkImage(
                                                  imageUrl: thumbnailUrl,
                                                  width: 70,
                                                  height: 75,
                                                  fit: BoxFit.contain,
                                                  cacheWidth: 200,
                                                  cacheHeight: 200,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                Align(
                                                  alignment: Alignment.bottomCenter,
                                                  child: Container(
                                                    width: double.infinity,
                                                    color: Colors.black45,
                                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                                    child: const Text('الرئيسية', style: TextStyle(color: Colors.white, fontSize: 9), textAlign: TextAlign.center),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      
                                      ...subImages.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final imgUrl = entry.value.toString();
                                        final isSelected = !_isThumbnailSelected && _selectedSubImageIndex == index;
                                        
                                        return GestureDetector(
                                          onTap: () => setState(() {
                                            _isThumbnailSelected = false;
                                            _selectedSubImageIndex = index;
                                          }),
                                          child: Container(
                                            width: 70,
                                            height: 75,
                                            margin: const EdgeInsets.only(left: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[900] : Colors.grey[100],
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                                width: 2.5,
                                              ),
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                optimizedNetworkImage(
                                                  imageUrl: imgUrl,
                                                  width: 70,
                                                  height: 75,
                                                  fit: BoxFit.contain,
                                                  cacheWidth: 200,
                                                  cacheHeight: 200,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                Align(
                                                  alignment: Alignment.bottomCenter,
                                                  child: Container(
                                                    width: double.infinity,
                                                    color: Colors.black45,
                                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                                    child: Text('فرعية ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 9), textAlign: TextAlign.center),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              Text(
                                _getText(_product!['name']),
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getText(_product!['description']),
                                style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  _buildModernInfoCard('سعر البيع', '${_product!['price']} ل.س', Icons.payments_rounded, Colors.green),
                                  const SizedBox(width: 8),
                                  _buildModernInfoCard('سعر التكلفة', '${_product!['cost_price'] ?? 0} ل.س', Icons.account_balance_wallet_rounded, Colors.purple),
                                  const SizedBox(width: 8),
                                  _buildModernInfoCard('المخزون', '${_product!['stock_quantity']} قطع', Icons.inventory_2_rounded, Colors.orange),
                                  const SizedBox(width: 8),
                                  _buildModernInfoCard('المباع', '${_product!['sold_count'] ?? 0} قطعة', Icons.trending_up_rounded, Colors.blue),
                                ],
                              ),
                              const SizedBox(height: 24),

                              _buildRealAnalyticsCard(theme, isDark),
                              const SizedBox(height: 24),

                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.list_alt_rounded, color: theme.colorScheme.primary, size: 20),
                                        const SizedBox(width: 8),
                                        const Text('الخصائص والمواصفات الشاملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDetailRow(Icons.spa_rounded, 'نوع الاستخدام', (_product!['skin_hair_type'] as List?)?.join(', ') ?? 'غير محدد'),
                                    
                                    _buildSizesRow(_product!['sizes']),

                                    _buildDetailRow(Icons.menu_book_rounded, 'طريقة الاستعمال', _getText(_product!['usage_instructions'])),
                                    _buildDetailRow(Icons.science_rounded, 'المكونات الأساسية', _getText(_product!['ingredients'])),
                                    _buildDetailRow(Icons.check_circle_outline_rounded, 'توافق البشرة/الشعر', _getText(_product!['compatibility'])),
                                    
                                    if (_product!['attributes'] is Map && (_product!['attributes'] as Map).isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(),
                                      ),
                                      const Text('خصائص مخصصة إضافية:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      const SizedBox(height: 8),
                                      ...(_product!['attributes'] as Map<String, dynamic>).entries.map(
                                        (entry) => _buildDetailRow(Icons.extension_rounded, entry.key, entry.value.toString()),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 90),
                            ],
                          ),
                        ),
                      ),
                    ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: theme.scaffoldBackgroundColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditProductScreen(product: _product!)),
                    );
                    if (result == true) _fetchProductDetails();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isActive ? Colors.orange : Colors.green,
                    side: BorderSide(color: isActive ? Colors.orange : Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _toggleProductStatus,
                  icon: Icon(isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 18),
                  label: Text(isActive ? 'إيقاف' : 'تفعيل', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  fixedSize: const Size(50, 50),
                ),
                onPressed: _isLoading ? null : _deleteProduct,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'حذف المنتج',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600], fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizesRow(dynamic sizesData) {
    List<String> sizesList = [];
    if (sizesData is List) {
      sizesList = sizesData.map((e) => e.toString()).toList();
    } else if (sizesData != null && sizesData.toString().isNotEmpty) {
      sizesList = [sizesData.toString()];
    }

    if (sizesList.isEmpty) sizesList = ['قياسي (Standard)'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.straighten_rounded, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text('الأحجام المتاحة', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600], fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sizesList.map((size) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    size,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealAnalyticsCard(ThemeData theme, bool isDark) {
    final int stock = _product!['stock_quantity'] ?? 0;
    final int sold = _product!['sold_count'] ?? 0;
    final double price = double.tryParse(_product!['price'].toString()) ?? 0.0;
    final double costPrice = double.tryParse(_product!['cost_price']?.toString() ?? '0') ?? 0.0;
    
    final double totalProfit = sold * (price - costPrice);
    final int totalUnits = stock + sold;
    final double salesPercentage = totalUnits > 0 ? (sold / totalUnits) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_rounded, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('التحليل المالي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'معدل المبيعات: ${salesPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('صافي الأرباح الفعلية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('$totalProfit ل.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                  ],
                ),
                Container(height: 25, width: 1, color: Colors.grey.withOpacity(0.3)),
                Column(
                  children: [
                    const Text('إجمالي الكمية (المخزون + المباع)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('$totalUnits قطعة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (totalUnits > 0 ? totalUnits.toDouble() : 10),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('القطع المباعة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold));
                          case 1:
                            return const Text('المخزون المتبقي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: sold.toDouble(), 
                        color: Colors.blueAccent, 
                        width: 24, 
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: stock.toDouble(), 
                        color: Colors.orangeAccent, 
                        width: 24, 
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}