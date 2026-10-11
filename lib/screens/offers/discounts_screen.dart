import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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

  // الحذف في الخلفية بدون عرض Progress Bar يمنع المستخدم من المتابعة
  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الخصم'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا الخصم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // تنفيذ الحذف صامتاً في الخلفية وتحديث البيانات عند النجاح
      OfferService.deleteOffer(id).then((success) {
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
                      Text('$initialPrice', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                    ],
                  ),
                ],
                if (finalPrice != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('السعر بعد الخصم:', style: TextStyle(color: Colors.grey)),
                      Text('$finalPrice', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                const Text('المنتجات المشمولة بالخصم (اضغط لعرض تفاصيل المنتج):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
                ),
                child: FutureBuilder<List<dynamic>>(
                  future: _discountsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('خطأ في الاتصال بالسيرفر: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('لا توجد خصومات فردية سارية حالياً', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    final discounts = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: discounts.length,
                      itemBuilder: (context, index) {
                        final item = discounts[index];
                        final itemId = item['id']?.toString() ?? '';
                        String titleText = _extractName(item['title']);
                        final discountVal = item['discount_percentage'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: ListTile(
                            onTap: () => _showDiscountDetails(item),
                            title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('قيمة الخصم: $discountVal%'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddOfferFormScreen(
                                          isBundle: false,
                                          offerData: item,
                                          isSingleProductDiscount: true, // تمرير التعليمة للتعديل
                                        ),
                                      ),
                                    );
                                    if (result == true) _loadData(forceRefresh: true);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _confirmDelete(itemId),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddOfferFormScreen(
                isBundle: false,
                isSingleProductDiscount: true, // تمرير التعليمة لصفحة إضافة خصم منتج واحد
              ),
            ),
          );
          if (result == true) _loadData(forceRefresh: true);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة خصم'),
      ),
    );
  }
}