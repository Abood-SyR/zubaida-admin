import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/category_service.dart'; // تأكد من مطابقة مسار الاستيراد

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      // جلب الفئات مع اجبار التحديث متجاوزاً الكاش القديم
      final categories = await CategoryService.getCategories(forceRefresh: true);
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل الفئات'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(
      text: isEditing ? (category['name'] is Map ? (category['name']['ar'] ?? '') : category['name'].toString()) : '',
    );
    bool isActive = isEditing ? (category['is_active'] ?? true) : true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'تعديل الفئة' : 'إضافة فئة جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم الفئة (عربي)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('نشطة'),
                value: isActive,
                onChanged: (val) => setDialogState(() => isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                
                final data = {
                  "name": {"ar": nameController.text.trim()},
                  "is_active": isActive,
                  "parent_id": null
                };

                try {
                  if (isEditing) {
                    await _apiService.dio.put('/categories/${category['id']}', data: data);
                  } else {
                    await _apiService.dio.post('/categories/', data: data);
                  }

                  // مسح الكاش المحلي لكي تنعكس التغييرات فوراً في التطبيق
                  await CategoryService.clearCache();

                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchCategories();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم الحفظ بنجاح'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حدث خطأ أثناء الحفظ'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await _apiService.dio.delete('/categories/$id');
      
      // مسح الكاش المحلي بعد الحذف
      await CategoryService.clearCache();
      
      _fetchCategories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الفئة بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل الحذف، قد تكون الفئة مرتبطة بمنتجات'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الفئات والأقسام')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('لا توجد فئات مضافة'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final name = cat['name'] is Map ? (cat['name']['ar'] ?? '') : cat['name'].toString();
                    final isActive = cat['is_active'] ?? true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isActive ? 'نشطة' : 'غير نشطة', 
                          style: TextStyle(color: isActive ? Colors.green : Colors.red),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showCategoryDialog(category: cat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCategory(cat['id'].toString()),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}