import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/services/offer_service.dart';
import 'add_offer_form_screen.dart';
import '../products/product_details_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  late Future<List<dynamic>> _bundlesFuture;
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
      _bundlesFuture = OfferService.getBundles(forceRefresh: forceRefresh);
    });
  }

  // الحذف في الخلفية بدون عرض Progress Bar يمنع المستخدم من المتابعة
  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحزمة'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذه الحزمة؟'),
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

  void _showBundleDetails(Map<String, dynamic> bundle) {
    var titleData = bundle['title'];
    String bundleTitle = _extractName(titleData);

    final price = bundle['final_price'] ?? bundle['total_price'] ?? 0.0;
    final initialPrice = bundle['initial_price'];
    final endDate = bundle['end_date']?.toString().split('T').first ?? 'غير محدد';
    
    final products = bundle['products'] as List? ?? [];
    dynamic freeProductData = bundle['free_product'];
    String? freeProductId = bundle['free_product_id']?.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bundleTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    const Text('السعر النهائي:', style: TextStyle(color: Colors.grey)),
                    Text('$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
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
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تاريخ الانتهاء:', style: TextStyle(color: Colors.grey)),
                    Text(endDate, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                const Divider(height: 28),
                const Text('المنتجات الأساسية المشمولة (اضغط لعرض تفاصيل المنتج):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                const Divider(height: 28),
                const Text('المنتج الهدية المجاني:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (freeProductData != null && freeProductData is Map)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.card_giftcard, size: 18, color: Colors.blueGrey),
                    title: Text(_extractName(freeProductData['name']), style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                    onTap: () => _navigateToProductDetails(freeProductData['id']?.toString()),
                  )
                else if (freeProductId != null && freeProductId.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.card_giftcard, size: 18, color: Colors.blueGrey),
                    title: Text(_getProductNameById(freeProductId), style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                    onTap: () => _navigateToProductDetails(freeProductId),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('لا يوجد منتج هدية لهذه الحزمة', style: TextStyle(color: Colors.grey)),
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
                  future: _bundlesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('خطأ في الاتصال بالسيرفر: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('لا توجد عروض حزم مسجلة حالياً', style: TextStyle(color: Colors.grey)));
                    }

                    final bundles = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: bundles.length,
                      itemBuilder: (context, index) {
                        final bundle = bundles[index];
                        final bundleId = bundle['id']?.toString() ?? '';
                        String bundleTitle = _extractName(bundle['title']);
                        final price = bundle['final_price'] ?? bundle['total_price'] ?? 0.0;
                        final productsCount = (bundle['products'] as List?)?.length ?? 0;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: ListTile(
                            onTap: () => _showBundleDetails(bundle),
                            title: Text(bundleTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('السعر: $price | عدد المنتجات: $productsCount'),
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
                                          isBundle: true,
                                          offerData: bundle,
                                        ),
                                      ),
                                    );
                                    if (result == true) _loadData(forceRefresh: true);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _confirmDelete(bundleId),
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
                isBundle: true,
              ),
            ),
          );
          if (result == true) _loadData(forceRefresh: true);
        },
        icon: const Icon(Icons.library_add_rounded),
        label: const Text('إضافة حزمة'),
      ),
    );
  }
}
