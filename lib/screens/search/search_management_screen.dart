import 'package:flutter/material.dart';

class SearchManagementScreen extends StatefulWidget {
  const SearchManagementScreen({super.key});

  @override
  State<SearchManagementScreen> createState() => _SearchManagementScreenState();
}

class _SearchManagementScreenState extends State<SearchManagementScreen> {
  bool _enableSmartSearch = true;
  bool _searchInDescription = true;
  bool _searchInIngredients = false;
  final TextEditingController _synonymController = TextEditingController();
  final List<String> _synonymsList = ['مكياج = تجميل', 'كريم = مرطب', 'شامبو = غسول شعر'];

  void _addSynonym() {
    if (_synonymController.text.trim().isNotEmpty) {
      setState(() {
        _synonymsList.add(_synonymController.text.trim());
        _synonymController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة الكلمة المرادفة بنجاح (محلياً)'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
        children: [
          const Text(
            'إعدادات محرك البحث',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'التحكم في خيارات البحث المتقدم والكلمات المرادفة (قريباً سيتم ربطها بالسيرفر)',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('تفعيل البحث الذكي المطابق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('تجاهل الأخطاء الإملائية البسيطة أثناء البحث', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _enableSmartSearch,
                  onChanged: (val) => setState(() => _enableSmartSearch = val),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('البحث في وصف المنتجات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('ضم الوصف التفصيلي ضمن نتائج البحث', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _searchInDescription,
                  onChanged: (val) => setState(() => _searchInDescription = val),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('البحث في المكونات (Ingredients)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('البحث داخل قائمة المكونات الخاصة بالمنتجات', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _searchInIngredients,
                  onChanged: (val) => setState(() => _searchInIngredients = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'إدارة الكلمات المرادفة (Synonyms)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _synonymController,
                  decoration: const InputDecoration(
                    labelText: 'أدخل الكلمة وما يطابقها (مثلاً: عطور = برفيوم)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _addSynonym,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.08)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _synonymsList.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_synonymsList[index], style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        _synonymsList.removeAt(index);
                      });
                    },
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