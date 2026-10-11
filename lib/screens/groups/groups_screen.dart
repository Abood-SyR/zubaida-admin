import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/services/group_service.dart'; // خدمة المجموعات الجديدة
import '../offers/add_offer_form_screen.dart';
import '../products/product_details_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<List<dynamic>> _groupsFuture;
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
      _groupsFuture = GroupService.getGroups(forceRefresh: forceRefresh);
    });
  }

  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المجموعة'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذه المجموعة؟'),
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
      GroupService.deleteGroup(id).then((success) {
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

  void _showGroupDetails(Map<String, dynamic> group) {
    String groupTitle = _extractName(group['name']);
    final finalPrice = group['final_price'] ?? group['calculated_price'] ?? 0.0;
    final customPrice = group['custom_price'];
    final description = _extractName(group['description'] ?? '');
    final features = _extractName(group['features'] ?? '');
    final usages = _extractName(group['usages'] ?? '');
    final compatibility = _extractName(group['compatibility'] ?? '');
    final products = group['products'] as List? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(groupTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    const Text('السعر النهائي المعتمد:', style: TextStyle(color: Colors.grey)),
                    Text('$finalPrice ل.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  ],
                ),
                if (customPrice != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('السعر الاختياري (المخصص):', style: TextStyle(color: Colors.grey)),
                      Text('$customPrice ل.س', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
                if (description.isNotEmpty && description != 'بدون اسم') ...[
                  const SizedBox(height: 8),
                  Text('الوصف: $description', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
                if (features.isNotEmpty && features != 'بدون اسم') ...[
                  const SizedBox(height: 4),
                  Text('المميزات: $features', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
                if (usages.isNotEmpty && usages != 'بدون اسم') ...[
                  const SizedBox(height: 4),
                  Text('الاستخدامات: $usages', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
                if (compatibility.isNotEmpty && compatibility != 'بدون اسم') ...[
                  const SizedBox(height: 4),
                  Text('التوافق: $compatibility', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
                const Divider(height: 28),
                const Text('المنتجات بداخل المجموعة (اضغط لعرض التفاصيل):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                products.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('لا توجد منتجات مضافة', style: TextStyle(color: Colors.grey)),
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
                  future: _groupsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('خطأ في الاتصال بالسيرفر: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('لا توجد مجموعات مسجلة حالياً', style: TextStyle(color: Colors.grey)));
                    }

                    final groups = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final groupId = group['id']?.toString() ?? '';
                        String groupTitle = _extractName(group['name']);
                        final price = group['final_price'] ?? group['calculated_price'] ?? 0.0;
                        final productsCount = (group['products'] as List?)?.length ?? 0;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: ListTile(
                            onTap: () => _showGroupDetails(group),
                            title: Text(groupTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('السعر: $price ل.س | عدد المنتجات: $productsCount'),
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
                                          isGroup: true,
                                          offerData: group,
                                        ),
                                      ),
                                    );
                                    if (result == true) _loadData(forceRefresh: true);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _confirmDelete(groupId),
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
                isGroup: true,
              ),
            ),
          );
          if (result == true) _loadData(forceRefresh: true);
        },
        icon: const Icon(Icons.library_add_rounded),
        label: const Text('إضافة مجموعة'),
      ),
    );
  }
}