import 'package:flutter/material.dart';

class UiManagementScreen extends StatefulWidget {
  const UiManagementScreen({super.key});

  @override
  State<UiManagementScreen> createState() => _UiManagementScreenState();
}

class _UiManagementScreenState extends State<UiManagementScreen> {
  bool _showBannerSlider = true;
  bool _showNewProductsSection = true;
  bool _showCollectionsSection = true;
  bool _showOffersSection = true;

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
            'تخصيص واجهة التطبيق الرئيسية (Home UI)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'تحكم في إظهار وإخفاء الأقسام والبنرات في الصفحة الرئيسية للعملاء',
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
                  title: const Text('شريط البنرات الإعلانية المتحركة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('عرض الصور المتحركة في أعلى الصفحة الرئيسية', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _showBannerSlider,
                  onChanged: (val) => setState(() => _showBannerSlider = val),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('قسم أحدث المنتجات (جديدنا)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('عرض أحدث 5 منتجات مضافة للمتجر', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _showNewProductsSection,
                  onChanged: (val) => setState(() => _showNewProductsSection = val),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('قسم المجموعات والبكجات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('عرض المجموعات المصممة أفقياً', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _showCollectionsSection,
                  onChanged: (val) => setState(() => _showCollectionsSection = val),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('قسم العروض والحزم الخاصة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('عرض العروض المميزة ذات المؤقت الزمني', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _showOffersSection,
                  onChanged: (val) => setState(() => _showOffersSection = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ إعدادات الواجهة بنجاح (محلياً)'), backgroundColor: Colors.green),
                );
              },
              child: const Text('حفظ التغييرات وتطبيقها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}