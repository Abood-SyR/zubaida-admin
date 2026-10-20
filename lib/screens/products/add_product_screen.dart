import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:dio/dio.dart';
import '../../core/services/api_service.dart';
import '../../core/services/category_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _usageController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _compatibilityController = TextEditingController();

  final List<TextEditingController> _sizeControllers = [TextEditingController()];
  final List<Map<String, TextEditingController>> _attributesList = [];
  
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  String _selectedSkinHairType = 'hair';

  Uint8List? _thumbnailBytes;
  String? _thumbnailName;
  final List<Map<String, dynamic>> _additionalImages = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _usageController.dispose();
    _ingredientsController.dispose();
    _compatibilityController.dispose();
    for (var c in _sizeControllers) {
      c.dispose();
    }
    for (var attr in _attributesList) {
      attr['key']?.dispose();
      attr['value']?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService.getCategories();
      setState(() {
        _categories = categories;
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories[0]['id']?.toString();
        }
      });
    } catch (_) {}
  }

  Future<void> _pickImageLocally({bool isThumbnail = true}) async {
    final picker = ImagePicker();
    
    if (isThumbnail) {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      Uint8List compressedBytes = bytes;
      if (!kIsWeb) {
        compressedBytes = await FlutterImageCompress.compressWithList(
          bytes, minWidth: 900, minHeight: 900, quality: 80,
        );
      }

      setState(() {
        _thumbnailBytes = compressedBytes;
        _thumbnailName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    } else {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      for (var pickedFile in pickedFiles) {
        final bytes = await pickedFile.readAsBytes();
        Uint8List compressedBytes = bytes;
        if (!kIsWeb) {
          compressedBytes = await FlutterImageCompress.compressWithList(
            bytes, minWidth: 900, minHeight: 900, quality: 80,
          );
        }

        final fileName = 'sub_${DateTime.now().millisecondsSinceEpoch}_${_additionalImages.length}.jpg';
        _additionalImages.add({
          'bytes': compressedBytes,
          'name': fileName,
        });
      }
      setState(() {});
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_thumbnailBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد الصورة الرئيسية للمنتج أولاً'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> sizesList = _sizeControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (sizesList.isEmpty) sizesList = ['standard'];

      Map<String, dynamic> attributesMap = {};
      for (var attr in _attributesList) {
        String key = attr['key']!.text.trim();
        String val = attr['value']!.text.trim();
        if (key.isNotEmpty) {
          attributesMap[key] = val;
        }
      }

      final productData = {
        "name": {"ar": _nameController.text.trim()},
        "description": {"ar": _descController.text.trim()},
        "price": double.parse(_priceController.text),
        "cost_price": double.tryParse(_costPriceController.text) ?? 0.0,
        "stock_quantity": int.parse(_stockController.text),
        "thumbnail_url": "",
        "images": [],
        "sizes": sizesList,
        "skin_hair_type": [_selectedSkinHairType],
        "usage_instructions": {"ar": _usageController.text.trim().isNotEmpty ? _usageController.text.trim() : "استخدام عادي"},
        "ingredients": {"ar": _ingredientsController.text.trim().isNotEmpty ? _ingredientsController.text.trim() : "مكونات طبيعية"},
        "compatibility": {"ar": _compatibilityController.text.trim().isNotEmpty ? _compatibilityController.text.trim() : "مناسب لجميع الأنواع"},
        "attributes": attributesMap,
        "category_id": _selectedCategoryId,
        "is_active": true,
      };

      final formData = FormData();
      formData.fields.add(MapEntry('product_data_json', jsonEncode(productData)));

      formData.files.add(MapEntry(
        'thumbnail',
        MultipartFile.fromBytes(_thumbnailBytes!, filename: _thumbnailName ?? 'thumbnail.jpg'),
      ));

      for (var img in _additionalImages) {
        formData.files.add(MapEntry(
          'additional_images',
          MultipartFile.fromBytes(img['bytes'], filename: img['name']),
        ));
      }

      await _apiService.dio.post('/products/', data: formData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة المنتج بنجاح عبر السيرفر'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإضافة: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('إضافة منتج جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. الصورة الرئيسية للمنتج (إلزامي)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : () => _pickImageLocally(isThumbnail: true),
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _thumbnailBytes != null ? theme.colorScheme.primary : Colors.grey.withOpacity(0.3),
                          width: 2,
                        ),
                        image: _thumbnailBytes != null
                            ? DecorationImage(image: MemoryImage(_thumbnailBytes!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _thumbnailBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, size: 48, color: theme.colorScheme.primary),
                                const SizedBox(height: 8),
                                const Text('انقر لاختيار الصورة الرئيسية', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                              ],
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                    child: const Text('الرئيسية', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('2. الصور الفرعية الإضافية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _isLoading ? null : () => _pickImageLocally(isThumbnail: false),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('إضافة صور'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _additionalImages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return GestureDetector(
                            onTap: _isLoading ? null : () => _pickImageLocally(isThumbnail: false),
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(left: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[900] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text('إضافة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        }
                        final imgIndex = index - 1;
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(left: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  _additionalImages[imgIndex]['bytes'],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () => setState(() => _additionalImages.removeAt(imgIndex)),
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text('3. البيانات الأساسية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المنتج',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) => v!.isEmpty ? 'حقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'وصف المنتج',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.description_outlined),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'سعر البيع',
                            prefixIcon: const Icon(Icons.payments_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (v) => v!.isEmpty ? 'حقل مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'سعر التكلفة',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'المخزون',
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (v) => v!.isEmpty ? 'حقل مطلوب' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Text('4. التصنيف والأحجام والخصائص', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: 'الفئة',
                            prefixIcon: const Icon(Icons.category_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: _categories.map<DropdownMenuItem<String>>((cat) {
                            return DropdownMenuItem<String>(
                              value: cat['id']?.toString(),
                              child: Text(cat['name']?.toString() ?? ''),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSkinHairType,
                          decoration: InputDecoration(
                            labelText: 'نوع العناية',
                            prefixIcon: const Icon(Icons.spa_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'hair', child: Text('شعر')),
                            DropdownMenuItem(value: 'skin', child: Text('بشرة')),
                            DropdownMenuItem(value: 'body', child: Text('جسم')),
                            DropdownMenuItem(value: 'all', child: Text('الكل')),
                          ],
                          onChanged: (val) => setState(() => _selectedSkinHairType = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('أحجام المنتج', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _sizeControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة حجم'),
                      ),
                    ],
                  ),
                  ..._sizeControllers.asMap().entries.map((entry) {
                    int index = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sizeControllers[index],
                              decoration: InputDecoration(
                                labelText: 'الحجم ${index + 1}',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          if (_sizeControllers.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _sizeControllers[index].dispose();
                                  _sizeControllers.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('خصائص إضافية مخصصة (Attributes)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _attributesList.add({
                              'key': TextEditingController(),
                              'value': TextEditingController(),
                            });
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة خاصية'),
                      ),
                    ],
                  ),
                  ..._attributesList.asMap().entries.map((entry) {
                    int index = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _attributesList[index]['key'],
                              decoration: InputDecoration(
                                labelText: 'الخاصية',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _attributesList[index]['value'],
                              decoration: InputDecoration(
                                labelText: 'القيمة',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _attributesList[index]['key']?.dispose();
                                _attributesList[index]['value']?.dispose();
                                _attributesList.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _usageController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'طريقة الاستعمال',
                      prefixIcon: const Icon(Icons.menu_book_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ingredientsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'المكونات الأساسية',
                      prefixIcon: const Icon(Icons.science_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _compatibilityController,
                    decoration: InputDecoration(
                      labelText: 'التوافق',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 36),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator.adaptive())
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _submitProduct,
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('حفظ وإضافة المنتج عبر السيرفر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}