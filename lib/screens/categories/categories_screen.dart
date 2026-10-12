import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/services/api_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _categories = [];
  String? _errorMessage;
  String _searchQuery = '';
  bool? _filterIsActive;

  @override
  void initState() {
    super.initState();
    _initDataCache();
  }

  @override
  void dispose() {
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

  Future<void> _initDataCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCategories = prefs.getString('cached_categories_list');

    setState(() {
      if (cachedCategories != null) {
        try {
          _categories = jsonDecode(cachedCategories) as List<dynamic>;
        } catch (_) {}
      }
      if (_categories.isNotEmpty) {
        _isLoading = false;
      }
    });

    await _fetchCategoriesInBackground();

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
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (_categories.isEmpty) {
        setState(() {
          _errorMessage = 'فشل تحميل الفئات، تأكد من الاتصال بالسيرفر';
        });
      }
    }
  }

  String _getCategoryName(dynamic nameField) {
    if (nameField is Map) {
      return nameField['ar']?.toString() ?? 
             nameField['additionalProp1']?.toString() ?? 
             (nameField.isNotEmpty ? nameField.values.first?.toString() : null) ?? 
             'بدون اسم';
    }
    return nameField?.toString() ?? 'بدون اسم';
  }

  List<dynamic> get _filteredCategories {
    return _categories.where((cat) {
      if (_filterIsActive != null) {
        final isActive = cat['is_active'] == true;
        if (isActive != _filterIsActive) return false;
      }
      if (_searchQuery.isEmpty) return true;
      final name = _getCategoryName(cat['name']).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _toggleCategoryStatus(Map<String, dynamic> category) async {
    final categoryId = category['id']?.toString() ?? '';
    final currentStatus = category['is_active'] == true;
    final newStatus = !currentStatus;

    _showLoadingDialog(newStatus ? 'جاري تفعيل القسم...' : 'جاري إيقاف القسم...');

    try {
      FormData formData = FormData.fromMap({
        "name": jsonEncode(category['name']),
        "is_active": newStatus.toString(),
      });

      await _apiService.dio.put(
        '/categories/$categoryId', 
        data: formData,
      );
      
      setState(() {
        category['is_active'] = newStatus;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_categories_list', jsonEncode(_categories));

      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'تم تفعيل القسم بنجاح' : 'تم وقف القسم بنجاح'), 
          backgroundColor: newStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تغيير حالة القسم'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القسم'),
        content: const Text('هل أنت متأكد من حذف هذا القسم نهائياً؟'),
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

    _showLoadingDialog('جاري حذف القسم...');

    try {
      await _apiService.dio.delete('/categories/$categoryId'); 
      setState(() {
        _categories.removeWhere((c) => c['id']?.toString() == categoryId);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_categories_list', jsonEncode(_categories));

      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف القسم بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حذف القسم (قد يتطلب صلاحيات مشرف عام Admin)'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddOrEditCategoryDialog({Map<String, dynamic>? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final nameArController = TextEditingController(
      text: isEditing ? _getCategoryName(categoryToEdit['name']) : '',
    );
    bool isActive = isEditing ? (categoryToEdit['is_active'] ?? true) : true;
    String? existingImageUrl = isEditing ? categoryToEdit['image_url']?.toString() : null;
    XFile? selectedImageFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'تعديل القسم' : 'إضافة قسم جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameArController,
                  decoration: const InputDecoration(
                    labelText: 'اسم القسم (عربي)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // معاينة واختيار الصورة من الملفات
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setDialogState(() {
                        selectedImageFile = pickedFile;
                      });
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: selectedImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: kIsWeb
                                ? Image.network(selectedImageFile!.path, fit: BoxFit.cover)
                                : Image.file(File(selectedImageFile!.path), fit: BoxFit.cover),
                          )
                        : existingImageUrl != null && existingImageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  existingImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40, color: Colors.grey),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('اضغط لاختيار صورة من الجهاز', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('حالة النشاط'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final nameText = nameArController.text.trim();
                if (nameText.isEmpty) return;

                Navigator.pop(context);
                _showLoadingDialog(isEditing ? 'جاري تعديل القسم...' : 'جاري إضافة القسم...');

                try {
                  FormData formData = FormData.fromMap({
                    "name": jsonEncode({"ar": nameText}),
                    "is_active": isActive.toString(),
                  });

                  if (selectedImageFile != null) {
                    String fileName = selectedImageFile!.name;
                    if (kIsWeb) {
                      var bytes = await selectedImageFile!.readAsBytes();
                      formData.files.add(MapEntry(
                        "file",
                        MultipartFile.fromBytes(bytes, filename: fileName),
                      ));
                    } else {
                      formData.files.add(MapEntry(
                        "file",
                        await MultipartFile.fromFile(selectedImageFile!.path, filename: fileName),
                      ));
                    }
                  }

                  if (isEditing) {
                    await _apiService.dio.put(
                      '/categories/${categoryToEdit['id']}',
                      data: formData,
                    ); 
                  } else {
                    await _apiService.dio.post(
                      '/categories/',
                      data: formData,
                    ); 
                  }

                  _hideLoadingDialog();
                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditing ? 'تم تعديل القسم بنجاح' : 'تم إضافة القسم بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _fetchCategoriesInBackground();
                } catch (e) {
                  _hideLoadingDialog();
                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشل حفظ القسم، تأكد من الاتصال'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayedCategories = _filteredCategories;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final searchFieldColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
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
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن قسم...',
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
                    onPressed: () => _showAddOrEditCategoryDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة قسم', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _categories.isEmpty
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
                : _errorMessage != null && _categories.isEmpty
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : displayedCategories.isEmpty
                        ? const Center(child: Text('لا توجد فئات مطابقة'))
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
                            itemCount: displayedCategories.length,
                            itemBuilder: (context, index) {
                              final cat = displayedCategories[index];
                              final catName = _getCategoryName(cat['name']);
                              final imageUrl = cat['image_url']?.toString();
                              final categoryId = cat['id']?.toString() ?? '';
                              final isActive = cat['is_active'] == true;
                              final imageVersion = cat['image_version'] ?? 1;

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
                                          onPressed: (_) => _showAddOrEditCategoryDialog(categoryToEdit: cat),
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: theme.colorScheme.primary,
                                          icon: Icons.edit_outlined,
                                        ),
                                        SlidableAction(
                                          onPressed: (_) => _toggleCategoryStatus(cat),
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: isActive ? Colors.orange : Colors.green,
                                          icon: isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                        ),
                                        SlidableAction(
                                          onPressed: (_) => _deleteCategory(categoryId),
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
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Icon(Icons.image_not_supported, color: Colors.grey),
                                                  )
                                                : const Icon(Icons.category, color: Colors.grey),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                catName,
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
                                          child: Text('إصدار الصورة: $imageVersion', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
    );
  }
}