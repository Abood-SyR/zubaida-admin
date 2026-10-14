import 'package:dashboard/screens/search/zero_results_logs_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/search_management_service.dart';

class SearchManagementScreen extends StatefulWidget {
  const SearchManagementScreen({super.key});

  @override
  State<SearchManagementScreen> createState() => _SearchManagementScreenState();
}

class _SearchManagementScreenState extends State<SearchManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _zeroLogSearchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _settings = [];
  List<dynamic> _synonyms = [];
  List<dynamic> _zeroResultsLogs = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _zeroLogSearchController.dispose();
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
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator.adaptive(strokeWidth: 3)),
                  const SizedBox(width: 20),
                  Expanded(child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
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

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final cachedSettings = await SearchManagementService.getSearchSettings(forceRefresh: false);
      final cachedSynonyms = await SearchManagementService.getSynonyms(forceRefresh: false);
      final cachedLogs = await SearchManagementService.getZeroResultsLogs(forceRefresh: false);

      if (mounted && (cachedSettings.isNotEmpty || cachedSynonyms.isNotEmpty)) {
        setState(() {
          _settings = cachedSettings;
          _synonyms = cachedSynonyms;
          _zeroResultsLogs = cachedLogs;
          _isLoading = false;
        });
      }

      final freshSettings = await SearchManagementService.getSearchSettings(forceRefresh: true);
      final freshSynonyms = await SearchManagementService.getSynonyms(forceRefresh: true);
      final freshLogs = await SearchManagementService.getZeroResultsLogs(forceRefresh: true);

      if (mounted) {
        setState(() {
          _settings = freshSettings;
          _synonyms = freshSynonyms;
          _zeroResultsLogs = freshLogs;
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

  String _translateSettingKey(String key) {
    switch (key) {
      case 'enable_description_search':
        return 'البحث داخل وصف المنتجات';
      case 'enable_ingredients_search':
        return 'البحث داخل مكونات المنتجات';
      case 'enable_synonyms':
        return 'تفعيل محرك الكلمات المرادفة';
      case 'enable_fuzzy_search':
        return 'تفعيل البحث الضبابي لتصحيح الأخطاء الإملائية';
      default:
        return key;
    }
  }

  Future<void> _toggleSetting(String key, bool currentVal) async {
    _showLoadingDialog('جاري تحديث إعدادات البحث...');
    bool success = await SearchManagementService.updateSetting(key, !currentVal);
    _hideLoadingDialog();

    if (success) {
      setState(() {
        for (var s in _settings) {
          if (s['setting_key'] == key) {
            s['is_enabled'] = !currentVal;
          }
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الإعداد بنجاح'), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحديث الإعداد'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteSynonym(String id) async {
    _showLoadingDialog('جاري حذف المرادف...');
    bool success = await SearchManagementService.deleteSynonym(id);
    _hideLoadingDialog();

    if (success) {
      setState(() {
        _synonyms.removeWhere((s) => s['id']?.toString() == id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المرادف بنجاح'), backgroundColor: Colors.green),
      );
    }
  }

  void _showAddSynonymDialog() {
    final targetController = TextEditingController();
    final synonymController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة كلمة مرادفة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: targetController,
              decoration: const InputDecoration(labelText: 'الكلمة الأصلية (مثال: كريم)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: synonymController,
              decoration: const InputDecoration(labelText: 'الكلمة المرادفة (مثال: مرطب)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final target = targetController.text.trim();
              final synonym = synonymController.text.trim();
              if (target.isEmpty || synonym.isEmpty) return;

              Navigator.pop(context);
              _showLoadingDialog('جاري حفظ المرادف...');
              bool success = await SearchManagementService.createSynonym(target, synonym);
              _hideLoadingDialog();

              if (success) {
                final updated = await SearchManagementService.getSynonyms(forceRefresh: true);
                setState(() => _synonyms = updated);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة المرادف بنجاح'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('حفظ'),
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
    final searchFieldColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'إعدادات البحث', icon: Icon(Icons.settings_suggest, size: 20)),
                Tab(text: 'الكلمات المرادفة', icon: Icon(Icons.compare_arrows, size: 20)),
                Tab(text: 'سجل بلا نتائج', icon: Icon(Icons.analytics_outlined, size: 20)),
              ],
            ),
          ),
          
          if (_tabController.index == 1)
            Padding(
              padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(color: searchFieldColor, borderRadius: BorderRadius.circular(14)),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: 'ابحث في المرادفات...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
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
                      onPressed: _showAddSynonymDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة مرادف', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading && _settings.isEmpty
                ? ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
                    itemCount: 4,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(height: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSettingsList(theme, isDesktop),
                      _buildSynonymsList(theme, isDesktop),
                      ZeroResultsLogsTab(
                        zeroResultsLogs: _zeroResultsLogs,
                        onLogsUpdated: (updatedLogs) {
                          setState(() => _zeroResultsLogs = updatedLogs);
                        },
                        showLoadingDialog: _showLoadingDialog,
                        hideLoadingDialog: _hideLoadingDialog,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(ThemeData theme, bool isDesktop) {
    if (_settings.isEmpty) return const Center(child: Text('لا توجد إعدادات متاحة'));

    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      itemCount: _settings.length,
      itemBuilder: (context, index) {
        final item = _settings[index];
        final key = item['setting_key']?.toString() ?? '';
        final isEnabled = item['is_enabled'] == true;
        final arabicTitle = _translateSettingKey(key);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.08)),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(arabicTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('حالة التشغيل: ${isEnabled ? "مفعل" : "معطل"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              value: isEnabled,
              onChanged: (_) => _toggleSetting(key, isEnabled),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSynonymsList(ThemeData theme, bool isDesktop) {
    final filtered = _synonyms.where((s) {
      if (_searchQuery.isEmpty) return true;
      final target = (s['target_word'] ?? '').toLowerCase();
      final synonym = (s['synonym_word'] ?? '').toLowerCase();
      return target.contains(_searchQuery.toLowerCase()) || synonym.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) return const Center(child: Text('لا توجد كلمات مرادفة مضافة'));

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final id = item['id']?.toString() ?? '';
        final target = item['target_word']?.toString() ?? '';
        final synonym = item['synonym_word']?.toString() ?? '';

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
                    onPressed: (_) => _deleteSynonym(id),
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
                  leading: const CircleAvatar(child: Icon(Icons.compare_arrows, size: 20)),
                  title: Text('$target  ⬅️  $synonym', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('مرادف بحث ذكي', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}