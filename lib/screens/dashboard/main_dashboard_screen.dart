import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/theme_provider.dart';
import '../home/home_analytics_screen.dart';
import '../products/products_screen.dart';
import '../offers/offers_screen.dart';
import '../offers/discounts_screen.dart';
import '../groups/groups_screen.dart'; // صفحة المجموعات الجديدة
import '../categories/categories_screen.dart'; // صفحة إدارة الفئات
import '../search/search_management_screen.dart'; // صفحة إدارة البحث
import '../ui/ui_management_screen.dart'; // صفحة إدارة الواجهات
import '../settings/qr_sessions_screen.dart';
import '../orders/status/current_orders_screen.dart';
import '../orders/status/processing_orders_screen.dart';
import '../orders/status/shipping_orders_screen.dart';
import '../orders/status/completed_orders_screen.dart';
import '../auth/login_screen.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _selectedIndex = 0;
  bool _isOrdersExpanded = false;
  bool _isOffersExpanded = false;
  bool _isThemeExpanded = false;
  String _userRole = 'admin';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'admin';
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openModernMenu() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.4),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ModernDropMenuScreen(
            selectedIndex: _selectedIndex,
            isOrdersExpanded: _isOrdersExpanded,
            isOffersExpanded: _isOffersExpanded,
            isThemeExpanded: _isThemeExpanded,
            userRole: _userRole,
            onItemSelected: (index, isOrdersExp, isOffersExp, isThemeExp) {
              setState(() {
                _selectedIndex = index;
                _isOrdersExpanded = isOrdersExp;
                _isOffersExpanded = isOffersExp;
                _isThemeExpanded = isThemeExp;
              });
            },
            onLogout: () => _logout(context),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (!isDesktop && details.primaryDelta! > 10 && details.localPosition.dx < 50) {
          _openModernMenu();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          children: [
            if (isDesktop)
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(
                    left: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
                  ),
                ),
                child: _buildSidebarContent(context, isMobile: false),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    color: theme.cardColor,
                    child: Row(
                      children: [
                        if (!isDesktop) ...[
                          IconButton(
                            icon: const Icon(Icons.menu_rounded),
                            onPressed: _openModernMenu,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          _getTitle(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: theme.scaffoldBackgroundColor,
                      child: _getSelectedScreen(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0: return 'الرئيسية والإحصائيات';
      case 1: return 'المنتجات والمخزون';
      case 2: return 'الخصومات الفردية';
      case 13: return 'العروض والحزم';
      case 14: return 'إدارة المجموعات';
      case 5: return 'إدارة الفئات';
      case 6: return 'إدارة البحث';
      case 7: return 'إدارة الواجهات';
      case 3: return 'الطلبات الحالية';
      case 10: return 'قائمة التجهيز';
      case 11: return 'قائمة التوصيل';
      case 12: return 'الطلبات المنجزة';
      case 4: return 'إدارة جلسات المعدلين';
      default: return 'لوحة التحكم';
    }
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0: return const HomeAnalyticsScreen();
      case 1: return const ProductsScreen();
      case 2: return const DiscountsScreen();
      case 13: return const OffersScreen();
      case 14: return const GroupsScreen(); // شاشة المجموعات
      case 5: return const CategoriesScreen(); // شاشة إدارة الفئات
      case 6: return const SearchManagementScreen(); // شاشة إدارة البحث
      case 7: return const UiManagementScreen(); // شاشة إدارة الواجهات
      case 3: return const CurrentOrdersScreen();
      case 10: return const ProcessingOrdersScreen();
      case 11: return const ShippingOrdersScreen();
      case 12: return const CompletedOrdersScreen();
      case 4: return const QrSessionsScreen();
      default: return const HomeAnalyticsScreen();
    }
  }

  Widget _buildSidebarContent(BuildContext context, {required bool isMobile}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isOffersActive = _selectedIndex == 2 || _selectedIndex == 13 || _selectedIndex == 14;
    final isOrdersActive = _selectedIndex == 3 || _selectedIndex == 10 || _selectedIndex == 11 || _selectedIndex == 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Text(
                  'Zubaida-Beauty',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _userRole.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _navItem(context, 0, 'الرئيسية والإحصائيات', Icons.dashboard_rounded, isMobile),
              _navItem(context, 1, 'المنتجات والمخزون', Icons.inventory_2_rounded, isMobile),
              
              // قسم العروض والخصومات والمجموعات
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: (isOffersActive && !_isOffersExpanded) ? primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExpansionTile(
                    leading: Icon(Icons.local_offer_rounded, color: isOffersActive && !_isOffersExpanded ? primary : Colors.grey[600], size: 22),
                    title: Text(
                      'العروض والخصومات',
                      style: TextStyle(
                        fontWeight: isOffersActive && !_isOffersExpanded ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        color: isOffersActive && !_isOffersExpanded ? primary : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    initiallyExpanded: _isOffersExpanded,
                    shape: const RoundedRectangleBorder(side: BorderSide.none),
                    collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isOffersExpanded = expanded;
                        if (!expanded && !isOffersActive) {
                          _selectedIndex = 2;
                        }
                      });
                    },
                    children: [
                      _subNavItem(context, 2, 'الخصومات الفردية', isMobile),
                      _subNavItem(context, 13, 'العروض والحزم', isMobile),
                      _subNavItem(context, 14, 'المجموعات', isMobile), // زر المجموعات الجديد
                    ],
                  ),
                ),
              ),
              
              // قسم الطلبات
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExpansionTile(
                    leading: Icon(Icons.shopping_bag_rounded, color: isOrdersActive && !_isOrdersExpanded ? primary : Colors.grey[600], size: 22),
                    title: Text(
                      'الطلبات',
                      style: TextStyle(
                        fontWeight: isOrdersActive && !_isOrdersExpanded ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        color: isOrdersActive && !_isOrdersExpanded ? primary : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    initiallyExpanded: _isOrdersExpanded,
                    shape: const RoundedRectangleBorder(side: BorderSide.none),
                    collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isOrdersExpanded = expanded;
                      });
                    },
                    children: [
                      _subNavItem(context, 3, 'الطلبات الحالية', isMobile),
                      _subNavItem(context, 10, 'قائمة التجهيز', isMobile),
                      _subNavItem(context, 11, 'قائمة التوصيل', isMobile),
                      _subNavItem(context, 12, 'الطلبات المنجزة', isMobile),
                    ],
                  ),
                ),
              ),

              if (_userRole == 'admin') _navItem(context, 4, 'إدارة جلسات المعدلين', Icons.qr_code_rounded, isMobile),
              
              // أزرار الإدارة الجديدة (إدارة الفئات، إدارة البحث، إدارة الواجهات)
              _navItem(context, 5, 'إدارة الفئات', Icons.category_rounded, isMobile),
              _navItem(context, 6, 'إدارة البحث', Icons.search_rounded, isMobile),
              _navItem(context, 7, 'إدارة الواجهات', Icons.web_rounded, isMobile),
              
              const Divider(height: 20),
              
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExpansionTile(
                    leading: Icon(Icons.palette_outlined, color: Colors.grey[600], size: 22),
                    title: Text(
                      'مظهر التطبيق',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    initiallyExpanded: _isThemeExpanded,
                    shape: const RoundedRectangleBorder(side: BorderSide.none),
                    collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isThemeExpanded = expanded;
                      });
                    },
                    children: [
                      _themeSubItem(context, 'الوضع الفاتح', AppThemeMode.light, themeProvider),
                      _themeSubItem(context, 'الوضع الليلي', AppThemeMode.dark, themeProvider),
                      _themeSubItem(context, 'الوضع البنكي', AppThemeMode.banking, themeProvider),
                    ],
                  ),
                ),
              ),
              
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                title: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.08)),
            ),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueGrey,
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Powered By',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    'Abdullrahman Abdullah',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navItem(BuildContext context, int index, String title, IconData icon, bool isMobile) {
    final isSelected = _selectedIndex == index;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? primary : Colors.grey[600], size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? primary : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (isMobile) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _subNavItem(BuildContext context, int index, String title, bool isMobile) {
    final isSelected = _selectedIndex == index;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 8),
      decoration: BoxDecoration(
        color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? primary : Colors.grey[600],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (isMobile) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _themeSubItem(BuildContext context, String title, AppThemeMode mode, ThemeProvider themeProvider) {
    final isSelected = themeProvider.currentThemeMode == mode;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 8),
      decoration: BoxDecoration(
        color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? primary : Colors.grey[600],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          themeProvider.setThemeMode(mode);
        },
      ),
    );
  }
}

class ModernDropMenuScreen extends StatefulWidget {
  final int selectedIndex;
  final bool isOrdersExpanded;
  final bool isOffersExpanded;
  final bool isThemeExpanded;
  final String userRole;
  final void Function(int, bool, bool, bool) onItemSelected;
  final VoidCallback onLogout;

  const ModernDropMenuScreen({
    super.key,
    required this.selectedIndex,
    required this.isOrdersExpanded,
    required this.isOffersExpanded,
    required this.isThemeExpanded,
    required this.userRole,
    required this.onItemSelected,
    required this.onLogout,
  });

  @override
  State<ModernDropMenuScreen> createState() => _ModernDropMenuScreenState();
}

class _ModernDropMenuScreenState extends State<ModernDropMenuScreen> {
  late int _currentIndex;
  late bool _isOrdersExp;
  late bool _isOffersExp;
  late bool _isThemeExp;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _isOrdersExp = widget.isOrdersExpanded;
    _isOffersExp = widget.isOffersExpanded;
    _isThemeExp = widget.isThemeExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primary = theme.colorScheme.primary;
    final width = MediaQuery.of(context).size.width * 0.82;

    final isOffersActive = _currentIndex == 2 || _currentIndex == 13 || _currentIndex == 14;
    final isOrdersActive = _currentIndex == 3 || _currentIndex == 10 || _currentIndex == 11 || _currentIndex == 12;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          Container(
            width: width,
            height: double.infinity,
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(5, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Zubaida Admin',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.userRole.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _buildItem(0, 'الرئيسية والإحصائيات', Icons.dashboard_rounded),
                        _buildItem(1, 'المنتجات والمخزون', Icons.inventory_2_rounded),
                        
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: (isOffersActive && !_isOffersExp) ? primary.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ExpansionTile(
                              leading: Icon(Icons.local_offer_rounded, color: isOffersActive && !_isOffersExp ? primary : Colors.grey[600], size: 22),
                              title: Text(
                                'العروض والخصومات',
                                style: TextStyle(
                                  fontWeight: isOffersActive && !_isOffersExp ? FontWeight.w600 : FontWeight.w500,
                                  fontSize: 14,
                                  color: isOffersActive && !_isOffersExp ? primary : theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              initiallyExpanded: _isOffersExp,
                              shape: const RoundedRectangleBorder(side: BorderSide.none),
                              collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                              onExpansionChanged: (exp) {
                                setState(() {
                                  _isOffersExp = exp;
                                });
                              },
                              children: [
                                _buildSubItem(2, 'الخصومات الفردية'),
                                _buildSubItem(13, 'العروض والحزم'),
                                _buildSubItem(14, 'المجموعات'),
                              ],
                            ),
                          ),
                        ),

                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ExpansionTile(
                              leading: Icon(Icons.shopping_bag_rounded, color: isOrdersActive && !_isOrdersExp ? primary : Colors.grey[600], size: 22),
                              title: Text(
                                'الطلبات',
                                style: TextStyle(
                                  fontWeight: isOrdersActive && !_isOrdersExp ? FontWeight.w600 : FontWeight.w500,
                                  fontSize: 14,
                                  color: isOrdersActive && !_isOrdersExp ? primary : theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              initiallyExpanded: _isOrdersExp,
                              shape: const RoundedRectangleBorder(side: BorderSide.none),
                              collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                              onExpansionChanged: (exp) {
                                setState(() {
                                  _isOrdersExp = exp;
                                });
                              },
                              children: [
                                _buildSubItem(3, 'الطلبات الحالية'),
                                _buildSubItem(10, 'قائمة التجهيز'),
                                _buildSubItem(11, 'قائمة التوصيل'),
                                _buildSubItem(12, 'الطلبات المنجزة'),
                              ],
                            ),
                          ),
                        ),

                        if (widget.userRole == 'admin') _buildItem(4, 'إدارة جلسات المعدلين', Icons.qr_code_rounded),

                        _buildItem(5, 'إدارة الفئات', Icons.category_rounded),
                        _buildItem(6, 'إدارة البحث', Icons.search_rounded),
                        _buildItem(7, 'إدارة الواجهات', Icons.web_rounded),

                        const Divider(height: 20),

                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ExpansionTile(
                              leading: Icon(Icons.palette_outlined, color: Colors.grey[600], size: 22),
                              title: Text(
                                'مظهر التطبيق',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              initiallyExpanded: _isThemeExp,
                              shape: const RoundedRectangleBorder(side: BorderSide.none),
                              collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                              onExpansionChanged: (exp) {
                                setState(() {
                                  _isThemeExp = exp;
                                });
                              },
                              children: [
                                _buildThemeSubItem('الوضع الفاتح', AppThemeMode.light, themeProvider),
                                _buildThemeSubItem('الوضع الليلي', AppThemeMode.dark, themeProvider),
                                _buildThemeSubItem('الوضع البنكي', AppThemeMode.banking, themeProvider),
                              ],
                            ),
                          ),
                        ),

                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                          title: const Text(
                            'تسجيل الخروج',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onLogout();
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blueGrey,
                          child: Text(
                            'A',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Powered By',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            Text(
                              'Abdullrahman Abdullah',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(int index, String title, IconData icon) {
    final isSelected = _currentIndex == index;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? primary : Colors.grey[600], size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? primary : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        onTap: () {
          setState(() => _currentIndex = index);
          widget.onItemSelected(_currentIndex, _isOrdersExp, _isOffersExp, _isThemeExp);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildSubItem(int index, String title) {
    final isSelected = _currentIndex == index;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 8),
      decoration: BoxDecoration(
        color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? primary : Colors.grey[600],
          ),
        ),
        onTap: () {
          setState(() => _currentIndex = index);
          widget.onItemSelected(_currentIndex, _isOrdersExp, _isOffersExp, _isThemeExp);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildThemeSubItem(String title, AppThemeMode mode, ThemeProvider themeProvider) {
    final isSelected = themeProvider.currentThemeMode == mode;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 8),
      decoration: BoxDecoration(
        color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? primary : Colors.grey[600],
          ),
        ),
        onTap: () {
          themeProvider.setThemeMode(mode);
        },
      ),
    );
  }
}