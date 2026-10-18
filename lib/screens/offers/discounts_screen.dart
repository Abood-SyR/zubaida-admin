import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/offer_service.dart';
import 'add_offer_form_screen.dart';
import '../products/product_details_screen.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  late Future<List<dynamic>> _discountsFuture;
  List<dynamic> _cachedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadLocalProductsCache();
    _loadData();
  }

  Future<void> _loadLocalProductsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedProductsStr = prefs.getString('cached_products_list');
    if (cachedProductsStr != null) {
      try {
        setState(() {
          _cachedProducts = jsonDecode(cachedProductsStr) as List<dynamic>;
        });
      } catch (_) {}
    }
  }

  String _getProductNameById(String? productId) {
    if (productId == null || productId.isEmpty) return 'غير محدد';
    for (var product in _cachedProducts) {
      if (product['id']?.toString() == productId) {
        var nameField = product['name'];
        if (nameField is Map) {
          return nameField['ar']?.toString() ?? 
                 nameField.values.firstOrNull?.toString() ?? 
                 'منتج #$productId';
        }
        return nameField?.toString() ?? 'منتج #$productId';
      }
    }
    return 'منتج #$productId';
  }

  String _extractName(dynamic nameField) {
    if (nameField is Map) {
      return nameField['ar']?.toString() ?? 
             nameField.values.firstOrNull?.toString() ?? 
             'بدون اسم';
    }
    return nameField?.toString() ?? 'بدون اسم';
  }

  void _loadData({bool forceRefresh = false}) {
    setState(() {
      _discountsFuture = OfferService.getDiscounts(forceRefresh: forceRefresh);
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

  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الخصم'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا الخصم نهائياً؟'),
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

    _showLoadingDialog('جاري حذف الخصم...');

    OfferService.deleteOffer(id).then((success) {
      _hideLoadingDialog();
      if (success) {
        _loadData(forceRefresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الحذف بنجاح'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل في عملية الحذف'), backgroundColor: Colors.red),
          );
        }
      }
    });
  }

  void _navigateToProductDetails(String? productId) {
    if (productId == null || productId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(productId: productId),
      ),
    );
  }

  void _showDiscountDetails(Map<String, dynamic> item) {
    String titleText = _extractName(item['title']);
    final discountVal = item['discount_percentage'] ?? 0;
    final finalPrice = item['final_price'] ?? item['total_price'];
    final initialPrice = item['initial_price'];
    final endDate = item['end_date']?.toString().split('T').first ?? 'غير محدد';
    final products = item['products'] as List? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('نسبة الخصم:', style: TextStyle(color: Colors.grey)),
                    Text('$discountVal%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  ],
                ),
                if (initialPrice != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('السعر الأصلي:', style: TextStyle(color: Colors.grey)),
                      Text('$initialPrice ل.س', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                    ],
                  ),
                ],
                if (finalPrice != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('السعر بعد الخصم:', style: TextStyle(color: Colors.grey)),
                      Text('$finalPrice ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تاريخ الانتهاء:', style: TextStyle(color: Colors.grey)),
                    Text(endDate, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                const Divider(height: 28),
                const Text('المنتجات المشمولة بالخصم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                products.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('لا توجد منتجات محددة', style: TextStyle(color: Colors.grey)),
                      )
                    : Column(
                        children: products.map<Widget>((p) {
                          String pName = '';
                          String? pId;
                          if (p is Map) {
                            pId = p['id']?.toString();
                            pName = p['name'] != null ? _extractName(p['name']) : _getProductNameById(pId);
                          } else {
                            pId = p.toString();
                            pName = _getProductNameById(pId);
                          }
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_outline, size: 18, color: Colors.blueGrey),
                            title: Text(pName, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                            onTap: () => _navigateToProductDetails(pId),
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FutureBuilder<List<dynamic>>(
        future: _discountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
              itemCount: 4,
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
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('خطأ في الاتصال بالسيرفر: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.discount_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('لا توجد خصومات فردية سارية حالياً', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          final discounts = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
            itemCount: discounts.length,
            itemBuilder: (context, index) {
              final item = discounts[index];
              final itemId = item['id']?.toString() ?? '';
              String titleText = _extractName(item['title']);
              final discountVal = item['discount_percentage'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Slidable(
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      extentRatio: 0.3,
                      children: [
                        SlidableAction(
                          onPressed: (_) async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddOfferFormScreen(
                                  isBundle: false,
                                  offerData: item,
                                  isSingleProductDiscount: true,
                                ),
                              ),
                            );
                            if (result == true) _loadData(forceRefresh: true);
                          },
                          backgroundColor: Colors.transparent,
                          foregroundColor: theme.colorScheme.primary,
                          icon: Icons.edit_outlined,
                        ),
                        SlidableAction(
                          onPressed: (_) => _confirmDelete(itemId),
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
                        onTap: () => _showDiscountDetails(item),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.percent_rounded, color: theme.colorScheme.primary, size: 20),
                        ),
                        title: Text(
                          titleText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'قيمة الخصم: $discountVal%',
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddOfferFormScreen(
                isBundle: false,
                isSingleProductDiscount: true,
              ),
            ),
          );
          if (result == true) _loadData(forceRefresh: true);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة خصم جديد', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}