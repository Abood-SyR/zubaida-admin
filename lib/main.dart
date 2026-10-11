import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/main_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://blltdhrwdgmuuydsqdxd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJsbHRkaHJ3ZGdtdXV5ZHNxZHhkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyMDcyODIsImV4cCI6MjEwNjc4MzI4Mn0.zBmtSbvWu_m-cDdq0n8-z_V27VyU4i86XrjaBgVJIZI',
  );
  // التحقق مما إذا كان المستخدم مسجل الدخول مسبقاً
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final bool isLoggedIn = token != null && token.isNotEmpty;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: ZubaidaAdminApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class ZubaidaAdminApp extends StatelessWidget {
  final bool isLoggedIn;

  const ZubaidaAdminApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Zubaida Admin Dashboard',
      debugShowCheckedModeBanner: false,
      // تطبيق الثيم الديناميكي (يتغير لحظياً بين الفاتح، الليلي، والبنكي)
      theme: themeProvider.getThemeData,
      // توجيه تلقائي: إذا كان مسجلاً للدخول يذهب للوحة التحكم، وإلا لتسجيل الدخول
      home: isLoggedIn ? const MainDashboardScreen() : const LoginScreen(),
    );
  }
}