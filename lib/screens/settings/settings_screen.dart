import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/theme_provider.dart';
import 'manage_categories_screen.dart'; // استيراد صفحة إدارة الفئات
import 'qr_sessions_screen.dart'; // استيراد صفحة جلسات QR

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userRole = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'admin';
      _userEmail = prefs.getString('user_email') ?? 'admin@zubaida.com';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان الرئيسي
              Text(
                'إعدادات النظام',
                style: TextStyle(
                  fontSize: isDesktop ? 26 : 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تخصيص المظهر، إدارة الحساب، والتحكم في تفضيلات لوحة التحكم',
                style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
              ),
              const SizedBox(height: 24),

              // قسم إدارة المتجر (الفئات وجلسات QR)
              _buildSectionCard(
                context,
                title: 'إدارة المتجر والربط',
                icon: Icons.store_outlined,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.category_outlined, color: theme.colorScheme.primary),
                      title: const Text('إدارة الفئات والأقسام'),
                      subtitle: const Text('إضافة وتعديل وحذف فئات المنتجات'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.qr_code_scanner_outlined, color: theme.colorScheme.primary),
                      title: const Text('جلسات QR والاتصال'),
                      subtitle: const Text('عرض وإدارة جلسات الأجهزة المرتبطة'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const QrSessionsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // قسم مظهر التطبيق (الثيمات الثلاثة)
              _buildSectionCard(
                context,
                title: 'مظهر التطبيق (الثيمات)',
                icon: Icons.palette_outlined,
                child: Column(
                  children: [
                    _buildThemeTile(
                      context,
                      title: 'الوضع الفاتح',
                      subtitle: 'مظهر كلاسيكي ساطع ومناسب للعمل النهارى',
                      icon: Icons.light_mode_outlined,
                      isSelected: themeProvider.currentThemeMode == AppThemeMode.light,
                      onTap: () => themeProvider.setThemeMode(AppThemeMode.light),
                    ),
                    const Divider(height: 1),
                    _buildThemeTile(
                      context,
                      title: 'الوضع الليلي',
                      subtitle: 'مظهر داكن مريح للإضاءة المنخفضة',
                      icon: Icons.dark_mode_outlined,
                      isSelected: themeProvider.currentThemeMode == AppThemeMode.dark,
                      onTap: () => themeProvider.setThemeMode(AppThemeMode.dark),
                    ),
                    const Divider(height: 1),
                    _buildThemeTile(
                      context,
                      title: 'الوضع البنكي / المهني',
                      subtitle: 'ألوان رسمية عميقة مصممة للاستخدام الطويل والمكثف',
                      icon: Icons.account_balance_outlined,
                      isSelected: themeProvider.currentThemeMode == AppThemeMode.banking,
                      onTap: () => themeProvider.setThemeMode(AppThemeMode.banking),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // قسم معلومات الحساب والأمان
              _buildSectionCard(
                context,
                title: 'معلومات الحساب',
                icon: Icons.security_outlined,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                      title: const Text('نوع الصلاحية الحالية'),
                      trailing: Chip(
                        label: Text(_userRole.toUpperCase()),
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                      title: const Text('البريد الإلكتروني'),
                      subtitle: Text(_userEmail),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isSelected ? theme.colorScheme.primary : Colors.grey),
      ),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Radio<bool>(
        value: true,
        groupValue: isSelected,
        onChanged: (_) => onTap(),
        activeColor: theme.colorScheme.primary,
      ),
    );
  }
}