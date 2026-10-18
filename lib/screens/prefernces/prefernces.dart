import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/api_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isCreatingNew = false; // نفس فكرة الـ Slider/View Toggle الموجودة في شاشة الجلسات
  List<String> _preferences = [];
  String? _errorMessage;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initDataCache();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    final cachedPrefs = prefs.getString('cached_preferences_list');

    setState(() {
      if (cachedPrefs != null) {
        try {
          _preferences = List<String>.from(jsonDecode(cachedPrefs));
        } catch (_) {}
      }
      if (_preferences.isNotEmpty) {
        _isLoading = false;
      }
    });

    await _fetchPreferencesInBackground();

    if (_isLoading) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPreferencesInBackground() async {
    try {
      Response response = await _apiService.dio.get('/preferences/');
      final data = response.data['available_preferences'] as List<dynamic>;
      final prefsList = data.map((e) => e.toString()).toList();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_preferences_list', jsonEncode(prefsList));

      if (mounted) {
        setState(() {
          _preferences = prefsList;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (_preferences.isEmpty) {
        setState(() {
          _errorMessage = 'فشل تحميل التفضيلات، تأكد من الاتصال بالسيرفر';
        });
      }
    }
  }

  Future<void> _submitSavePreference({String? oldName}) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم التفضيل'), backgroundColor: Colors.orange),
      );
      return;
    }

    final isEditing = oldName != null;
    _showLoadingDialog(isEditing ? 'جاري تعديل التفضيل...' : 'جاري إضافة التفضيل...');

    try {
      if (isEditing) {
        await _apiService.dio.put('/preferences/', data: {
          "old_name": oldName,
          "new_name": name,
        });
      } else {
        await _apiService.dio.post('/preferences/', data: {
          "name": name,
        });
      }

      _hideLoadingDialog();
      setState(() {
        _isCreatingNew = false;
        _nameController.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'تم تعديل التفضيل بنجاح' : 'تم إضافة التفضيل بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchPreferencesInBackground();
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل حفظ التفضيل، تأكد من الصلاحيات أو تكرار الاسم'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddEditModal({String? prefName}) {
    if (prefName != null) {
      _nameController.text = prefName;
    } else {
      _nameController.clear();
    }

    // يمكننا استخدام نافذة منسدلة أو الانتقال لنموذج الإدخال تماماً مثل الـ QR Screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(prefName != null ? 'تعديل التفضيل' : 'إضافة تفضيل جديد', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم التفضيل أو الاهتمام', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitSavePreference(oldName: prefName);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePreference(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف التفضيل'),
        content: Text('هل أنت متأكد من حذف تفضيل "$name"؟'),
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

    _showLoadingDialog('جاري الحذف...');

    try {
      await _apiService.dio.delete('/preferences/', queryParameters: {'name': name});
      
      setState(() {
        _preferences.remove(name);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_preferences_list', jsonEncode(_preferences));

      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف التفضيل بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حذف التفضيل'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      body: _isCreatingNew
          ? _buildCreatePreferenceView(theme, isDesktop)
          : _buildPreferencesListView(theme, isDesktop),
      floatingActionButton: !_isCreatingNew
          ? FloatingActionButton.extended(
              onPressed: () {
                _nameController.clear();
                setState(() => _isCreatingNew = true);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة تفضيل جديد'),
            )
          : null,
    );
  }

  Widget _buildCreatePreferenceView(ThemeData theme, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _isCreatingNew = false),
                  ),
                  const SizedBox(width: 8),
                  const Text('إضافة أو تعديل تفضيل العملاء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم التفضيل (مثال: العناية بالبشرة والحساسية)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _submitSavePreference(),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ التفضيل في النظام', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesListView(ThemeData theme, bool isDesktop) {
    final isDark = theme.brightness == Brightness.dark;

    return _isLoading && _preferences.isEmpty
        ? ListView.builder(
            padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
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
        : _errorMessage != null && _preferences.isEmpty
            ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
            : _preferences.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('لا توجد تفضيلات مضافة حالياً', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                    itemCount: _preferences.length,
                    itemBuilder: (context, index) {
                      final prefName = _preferences[index];

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
                                  onPressed: (_) => _showAddEditModal(prefName: prefName),
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: theme.colorScheme.primary,
                                  icon: Icons.edit_outlined,
                                ),
                                SlidableAction(
                                  onPressed: (_) => _deletePreference(prefName),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                  child: Icon(Icons.favorite_rounded, color: theme.colorScheme.primary, size: 20),
                                ),
                                title: Text(
                                  prefName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: const Text(
                                  'تفضيل متاح لاختيارات العملاء',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
  }
}