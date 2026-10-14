// ignore_for_file: unused_local_variable

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/offer_service.dart';
import '../../core/services/api_service.dart';
import 'product_selection_screen.dart';

class AddOfferFormScreen extends StatefulWidget {
  final bool isBundle;
  final bool isSingleProductDiscount;
  final bool isGroup;
  final Map<String, dynamic>? offerData;

  const AddOfferFormScreen({
    super.key,
    required this.isBundle,
    this.isSingleProductDiscount = false,
    this.isGroup = false,
    this.offerData,
  });

  @override
  State<AddOfferFormScreen> createState() => _AddOfferFormScreenState();
}

class _AddOfferFormScreenState extends State<AddOfferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  List<String> _selectedProductIds = [];
  String? _freeProductId;
  List<dynamic> _selectedProductsFullDetails = [];
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _discountPercentageController = TextEditingController();
  final TextEditingController _finalPriceController = TextEditingController();
  
  // حقول المجموعات
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _featuresController = TextEditingController();
  final TextEditingController _usagesController = TextEditingController();
  final TextEditingController _compatibilityController = TextEditingController();

  // متغيرات رفع الصورة الحقيقية إلى dashBucket
  Uint8List? _groupImageBytes;
  String? _groupImageName;
  String? _existingImageUrl;

  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.offerData != null) {
      final item = widget.offerData!;
      
      var titleData = item['title'] ?? item['name'];
      if (titleData is Map) {
        _nameController.text = titleData['ar'] ?? titleData.values.firstOrNull?.toString() ?? '';
      } else if (titleData is String) {
        _nameController.text = titleData;
      }

      if (widget.isGroup) {
        _finalPriceController.text = item['custom_price']?.toString() ?? '';
        _existingImageUrl = item['image_url']?.toString();
        
        var descData = item['description'];
        if (descData is Map) {
          _descriptionController.text = descData['ar'] ?? '';
        } else if (descData is String) _descriptionController.text = descData;

        var featData = item['features'];
        if (featData is Map) {
          _featuresController.text = featData['ar'] ?? '';
        } else if (featData is String) _featuresController.text = featData;

        var usageData = item['usages'];
        if (usageData is Map) {
          _usagesController.text = usageData['ar'] ?? '';
        } else if (usageData is String) _usagesController.text = usageData;

        var compData = item['compatibility'];
        if (compData is Map) {
          _compatibilityController.text = compData['ar'] ?? '';
        } else if (compData is String) _compatibilityController.text = compData;
      } else {
        if (item['discount_percentage'] != null) {
          _discountPercentageController.text = item['discount_percentage'].toString();
        }
        if (item['final_price'] != null) {
          _finalPriceController.text = item['final_price'].toString();
        } else if (item['total_price'] != null) {
          _finalPriceController.text = item['total_price'].toString();
        }
        _freeProductId = item['free_product_id']?.toString();
      }
      
      if (item['products'] != null) {
        _selectedProductIds = (item['products'] as List).map((p) => p['id'].toString()).toList();
        _selectedProductsFullDetails = List.from(item['products']);
      }
    }
  }

  Future<void> _pickGroupImage() async {
    final picker = ImagePicker();
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
      _groupImageBytes = compressedBytes;
      _groupImageName = 'group_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
  }

  Future<void> _openProductSelector() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductSelectionScreen(
          initialSelectedIds: _selectedProductIds,
          isMultiSelect: !widget.isSingleProductDiscount,
        ),
      ),
    );
    
    if (result != null) {
      setState(() {
        if (result is List && result.isNotEmpty && result.first is Map) {
          _selectedProductsFullDetails = result;
          _selectedProductIds = result.map((p) => p['id'].toString()).toList();
        } else if (result is List) {
          _selectedProductIds = result.map((id) => id.toString()).toList();
        }
      });
    }
  }

  Future<void> _openFreeProductSelector() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductSelectionScreen(
          initialSelectedIds: _freeProductId != null ? [_freeProductId!] : [],
          isMultiSelect: false,
        ),
      ),
    );
    if (result != null && result is List && result.isNotEmpty) {
      setState(() {
        if (result.first is Map) {
          _freeProductId = result.first['id']?.toString();
        } else {
          _freeProductId = result.first.toString();
        }
      });
    } else if (result != null && result is List && result.isEmpty) {
      setState(() => _freeProductId = null);
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار المنتج أو المنتجات المطلوبة'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.1;
    });

    bool success = false;

    try {
      String? uploadedImageUrl = _existingImageUrl;

      // رفع الصورة الحقيقية إلى dashBucket في حال تم اختيار صورة جديدة
      if (widget.isGroup && _groupImageBytes != null && _groupImageName != null) {
        setState(() => _uploadProgress = 0.3);
        await Supabase.instance.client.storage
            .from('dashBucket')
            .uploadBinary(_groupImageName!, _groupImageBytes!, fileOptions: const FileOptions(upsert: true));
        
        uploadedImageUrl = Supabase.instance.client.storage
            .from('dashBucket')
            .getPublicUrl(_groupImageName!);
        
        setState(() => _uploadProgress = 0.6);
      }

      if (widget.isGroup) {
        final Map<String, dynamic> groupData = {
          "name": {"ar": _nameController.text.trim()},
          "product_ids": _selectedProductIds,
          "image_url": uploadedImageUrl,
        };

        if (_finalPriceController.text.trim().isNotEmpty) {
          groupData["custom_price"] = double.tryParse(_finalPriceController.text.trim());
        }
        if (_descriptionController.text.trim().isNotEmpty) {
          groupData["description"] = {"ar": _descriptionController.text.trim()};
        }
        if (_featuresController.text.trim().isNotEmpty) {
          groupData["features"] = {"ar": _featuresController.text.trim()};
        }
        if (_usagesController.text.trim().isNotEmpty) {
          groupData["usages"] = {"ar": _usagesController.text.trim()};
        }
        if (_compatibilityController.text.trim().isNotEmpty) {
          groupData["compatibility"] = {"ar": _compatibilityController.text.trim()};
        }

        setState(() => _uploadProgress = 0.85);

        if (widget.offerData != null) {
          String id = widget.offerData!['id'].toString();
          await _apiService.dio.put('/groups/$id', data: groupData);
        } else {
          await _apiService.dio.post('/groups/', data: groupData);
        }
        success = true;
      } else {
        // منطق العروض والحزم
        double totalOriginalPrice = 0.0;
        if (_selectedProductsFullDetails.isNotEmpty) {
          totalOriginalPrice = _selectedProductsFullDetails.fold(0.0, (sum, item) {
            double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            return sum + price;
          });
        }

        double finalPriceVal = double.tryParse(_finalPriceController.text.trim()) ?? 0.0;
        double discountPercentage = double.tryParse(_discountPercentageController.text.trim()) ?? 0.0;

        if (finalPriceVal <= 0 && totalOriginalPrice > 0) {
          if (discountPercentage > 0) {
            finalPriceVal = totalOriginalPrice - (totalOriginalPrice * (discountPercentage / 100));
          } else {
            finalPriceVal = totalOriginalPrice;
          }
        } else if (finalPriceVal > 0 && discountPercentage > 0 && totalOriginalPrice <= 0) {
          finalPriceVal = finalPriceVal - (finalPriceVal * (discountPercentage / 100));
        }

        if (finalPriceVal <= 0) {
          finalPriceVal = 1.0; 
        }

        final Map<String, dynamic> data = {
          "title": {"ar": _nameController.text.trim()},
          "offer_type": widget.isBundle ? "bundle" : "single_discount",
          "end_date": DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          "product_ids": _selectedProductIds, 
          "free_product_id": _freeProductId,
          "final_price": finalPriceVal,
        };

        if (_discountPercentageController.text.trim().isNotEmpty) {
          data["discount_percentage"] = discountPercentage;
        }

        if (widget.offerData != null) {
          String id = widget.offerData!['id'].toString();
          success = await OfferService.updateOffer(id, data);
        } else {
          success = widget.isBundle ? await OfferService.addBundle(data) : await OfferService.addDiscount(data);
        }
      }

      setState(() => _uploadProgress = 1.0);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.offerData != null;

    String screenTitle = isEditing ? 'تعديل' : 'إضافة';
    if (widget.isGroup) {
      screenTitle = isEditing ? 'تعديل المجموعة' : 'إضافة مجموعة جديدة';
    } else if (widget.isSingleProductDiscount) {
      screenTitle = isEditing ? 'تعديل الخصم' : 'إضافة خصم فردي';
    } else {
      screenTitle = isEditing ? 'تعديل الحزمة' : 'إضافة حزمة جديدة';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(screenTitle),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // رفع صورة المجموعة في حال كانت الشاشة مجموعة
              if (widget.isGroup) ...[
                const Text('صورة المجموعة (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isSubmitting ? null : _pickGroupImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
                      image: _groupImageBytes != null
                          ? DecorationImage(image: MemoryImage(_groupImageBytes!), fit: BoxFit.cover)
                          : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                              ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                              : null,
                    ),
                    child: (_groupImageBytes == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty))
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey),
                              SizedBox(height: 6),
                              Text('انقر لاختيار صورة المجموعة', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // حقل الاسم
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: widget.isGroup ? 'اسم المجموعة (مطلوب)' : 'اسم العرض أو الخصم',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
              ),
              const SizedBox(height: 16),
              
              if (!widget.isGroup) ...[
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: TextFormField(
                          controller: _discountPercentageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'نسبة الخصم %',
                            hintText: 'مثال: 15',
                            prefixIcon: Icon(Icons.percent_rounded),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: TextFormField(
                          controller: _finalPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'السعر النهائي',
                            hintText: 'مثال: 50',
                            prefixIcon: Icon(Icons.attach_money_rounded),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: TextFormField(
                    controller: _finalPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'السعر الاختياري (اتركه فارغاً ليُحسب تلقائياً)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'وصف المجموعة (اختياري)',
                      prefixIcon: Icon(Icons.description_outlined),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                  child: TextFormField(
                    controller: _featuresController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'مميزات المجموعة (اختياري)',
                      prefixIcon: Icon(Icons.star_outline_rounded),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                  child: TextFormField(
                    controller: _usagesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'الاستخدامات (اختياري)',
                      prefixIcon: Icon(Icons.build_outlined),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                  child: TextFormField(
                    controller: _compatibilityController,
                    decoration: const InputDecoration(
                      labelText: 'التوافق (اختياري)',
                      prefixIcon: Icon(Icons.check_circle_outline_rounded),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              Text(
                widget.isGroup ? 'المنتجات بداخله (مطلوب)' : (widget.isSingleProductDiscount ? 'المنتج المستهدف بالخصم' : 'المنتجات الأساسية المشمولة بالحزمة'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              
              InkWell(
                onTap: _openProductSelector,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedProductIds.isEmpty 
                              ? 'انقر لاختيار المنتجات'
                              : 'تم اختيار ${_selectedProductIds.length} منتج',
                          style: TextStyle(fontWeight: FontWeight.w600, color: _selectedProductIds.isEmpty ? Colors.grey : null),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              if (_selectedProductsFullDetails.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedProductsFullDetails.length,
                    itemBuilder: (context, index) {
                      final prod = _selectedProductsFullDetails[index];
                      final name = prod['name'] is Map ? (prod['name']['ar'] ?? 'منتج') : (prod['name'] ?? 'منتج');
                      final image = prod['image'] ?? prod['thumbnail_url'];
                      
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: image != null
                                    ? Image.network(image, fit: BoxFit.cover, width: double.infinity)
                                    : const Icon(Icons.image_outlined, color: Colors.grey),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                name.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (!widget.isSingleProductDiscount && !widget.isGroup) ...[
                const SizedBox(height: 24),
                const Text('المنتج المجاني / الهدية (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _openFreeProductSelector,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _freeProductId != null ? Colors.green.withOpacity(0.5) : theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_freeProductId != null ? Colors.green : theme.colorScheme.primary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.card_giftcard_rounded, color: _freeProductId != null ? Colors.green : theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _freeProductId == null ? 'اختر منتج هدية مجاني مع الحزمة' : 'تم تحديد منتج الهدية بنجاح',
                            style: TextStyle(fontWeight: FontWeight.w600, color: _freeProductId != null ? Colors.green : Colors.grey),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 36),
              if (_isSubmitting) ...[
                LinearProgressIndicator(value: _uploadProgress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'جاري رفع الصورة وحفظ البيانات... ${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _submitData,
                    child: Text(
                      isEditing ? 'حفظ التعديلات' : 'حفظ وإضافة',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}