import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:dio/dio.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/image_helper.dart';
import 'products_screen.dart';

class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  List<dynamic> _products = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProductsWithFallback();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// محاولة الجلب من الذاكرة أولاً، وإذا كانت فارغة يتم جلبها تلقائياً من السيرفر
  Future<void> _loadProductsWithFallback() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedProducts = prefs.getString('cached_products_list');

    if (cachedProducts != null) {
      try {
        final List<dynamic> data = jsonDecode(cachedProducts);
        if (data.isNotEmpty) {
          setState(() {
            _products = data;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}
    }

    // إذا كانت الذاكرة فارغة، نقوم بجلب البيانات من السيرفر مباشرة
    await _fetchProductsFromServer();
  }

  Future<void> _fetchProductsFromServer() async {
    try {
      Response response = await _apiService.dio.get('/products/?include_inactive=true');
      final data = response.data as List<dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_products_list', jsonEncode(data));

      if (mounted) {
        setState(() {
          _products = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getProductName(dynamic nameField) {
    if (nameField is Map) {
      return nameField['ar']?.toString() ??
          nameField['additionalProp1']?.toString() ??
          (nameField.isNotEmpty ? nameField.values.first?.toString() : null) ??
          'بدون اسم';
    }
    return nameField?.toString() ?? 'بدون اسم';
  }

  List<dynamic> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) {
      final name = _getProductName(product['name']).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final searchFieldColor = isDark ? Colors.grey[900]! : Colors.grey[100]!

    ;
    final displayedProducts = _filteredProducts;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'توليد رمز QR للمنتجات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: searchFieldColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج لتوليد الرمز...',
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
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
                    itemCount: 6,
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
                  )
                : displayedProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'لا توجد منتجات محفوظة أو متاحة حالياً',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ProductsScreen()),
                                );
                              },
                              icon: const Icon(Icons.storefront_rounded),
                              label: const Text('الذهاب إلى إدارة المنتجات', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
                        itemCount: displayedProducts.length,
                        itemBuilder: (context, index) {
                          final product = displayedProducts[index];
                          final productName = _getProductName(product['name']);
                          final imageUrl = product['thumbnail_url']?.toString();
                          final productId = product['id']?.toString() ?? '';
                          final productUrl = "https://www.zubaida-beauty.sy/product/$productId";

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
                                      onPressed: (_) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => QrGeneratorDetailScreen(
                                              productName: productName,
                                              productUrl: productUrl,
                                              imageUrl: imageUrl,
                                            ),
                                          ),
                                        );
                                      },
                                      backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                                      foregroundColor: theme.colorScheme.primary,
                                      icon: Icons.qr_code_2_rounded,
                                      label: 'رمز QR',
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
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey.withOpacity(0.1),
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? optimizedNetworkImage(
                                              imageUrl: imageUrl,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.contain,
                                              cacheWidth: 150,
                                              cacheHeight: 150,
                                              borderRadius: BorderRadius.circular(12),
                                            )
                                          : const Icon(Icons.image, color: Colors.grey),
                                    ),
                                    title: Text(
                                      productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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

/// واجهة كاملة (Full Screen) لتوليد وحفظ رمز الـ QR بنفس الشعار البارز في الأعلى ونمط البكسلات
class QrGeneratorDetailScreen extends StatefulWidget {
  final String productName;
  final String productUrl;
  final String? imageUrl;

  const QrGeneratorDetailScreen({
    super.key,
    required this.productName,
    required this.productUrl,
    this.imageUrl,
  });

  @override
  State<QrGeneratorDetailScreen> createState() => _QrGeneratorDetailScreenState();
}

class _QrGeneratorDetailScreenState extends State<QrGeneratorDetailScreen> {
  final GlobalKey _qrKey = GlobalKey();

  Future<Uint8List?> _captureQrPngBytes() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveOrShareImage() async {
  try {
    await Future.delayed(const Duration(milliseconds: 100));

    RenderRepaintBoundary? boundary =
        _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    
    if (boundary == null) return;

    ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) return;
    
    Uint8List imageBytes = byteData.buffer.asUint8List();

    // الطريقة الحديثة المتوافقة مع package:web للتعامل مع تحميل الملفات على الويب
    final blob = web.Blob(
      [imageBytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final url = web.URL.createObjectURL(blob);
    
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = 'qr_${widget.productName}.png';
    
    web.document.body?.appendChild(anchor);
    anchor.click();
    web.document.body?.removeChild(anchor);
    
    web.URL.revokeObjectURL(url);

  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ الصورة: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

  Future<void> _exportPdf() async {
    final imageBytes = await _captureQrPngBytes();
    if (imageBytes == null) return;

    final pdf = pw.Document();
    final qrImage = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(qrImage, width: 250, height: 250),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryColor = Color(0xFF1E293B); // لون كحلي داكن شبيق بالصورة

    return Scaffold(
      appBar: AppBar(
        title: const Text('رمز QR للمنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: optimizedNetworkImage(
                      imageUrl: widget.imageUrl!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  widget.productName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // حاوية الـ QR مع "اللسان" البارز للأعلى للشعار مثل الصورة بالضبط
                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    color: Colors.transparent, // خلفية شفافة عند التقاط الصورة
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // اللسان العلوي الذي يحمل الشعار
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Container(
                            width: 68,
                            height: 48,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.store,
                                  size: 26,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // صندوق الـ QR الرئيسي بحواف دائرية ونقاط بكسلات كحلي
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: widget.productUrl,
                            version: QrVersions.auto,
                            size: 240.0,
                            backgroundColor: Colors.white,
                            // تلوين البكسلات والمربعات بلون موحد داكن مثل الصورة
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: primaryColor,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  widget.productUrl,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _saveOrShareImage,
                          icon: const Icon(Icons.image_rounded, size: 20),
                          label: const Text('حفظ كصورة', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(color: theme.colorScheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _exportPdf,
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                          label: const Text('حفظ كـ PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}