import 'dart:math' as math;
import 'package:dashboard/screens/dashboard/main_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../../core/services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  final ApiService _apiService = ApiService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _bubblesController;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _bubblesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _bubblesController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال اسم المستخدم/البريد وكلمة المرور';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Response response = await _apiService.dio.post(
        '/auth/login',
        data: FormData.fromMap({
          'username': identifier,
          'password': password,
        }),
      );

      final token = response.data['access_token'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_role', 'admin'); 

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainDashboardScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في اسم المستخدم أو كلمة المرور، تأكد من البيانات المدخلة';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      body: Stack(
        children: [
          // 1. الفقاعات المتعددة المتحركة في الخلفية
          AnimatedBuilder(
            animation: _bubblesController,
            builder: (context, child) {
              return CustomPaint(
                painter: BubblesPainter(animationValue: _bubblesController.value),
                size: MediaQuery.of(context).size,
              );
            },
          ),

          // 2. طبقة الـ Blur الشاملة لتأثير الزجاج على كامل الشاشة
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              color: Colors.black.withOpacity(0.45),
            ),
          ),

          // 3. محتوى شاشة تسجيل الدخول المباشر
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // الأيقونة العلوية
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 40,
                            color: Colors.pinkAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Zubaida-Beauty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'By Abdullrahman',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.pinkAccent.withOpacity(0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 36),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // حقل اسم المستخدم أو البريد
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'اسم المستخدم أو البريد الإلكتروني',
                          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          hintText: 'أدخل المعرف الإداري',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.pinkAccent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // حقل كلمة المرور
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          hintText: '••••••••',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.pinkAccent, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 32),

                      // زر تسجيل الدخول
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// رسم فقاعات متعددة ومتنوعة الألوان تتحرك ببطء في الخلفية
class BubblesPainter extends CustomPainter {
  final double animationValue;

  BubblesPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint1 = Paint()
      ..color = const Color(0xFFE91E63).withOpacity(0.3) // وردي
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final Paint paint2 = Paint()
      ..color = const Color(0xFF9C27B0).withOpacity(0.3) // بنفسجي
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);

    final Paint paint3 = Paint()
      ..color = const Color(0xFF3F51B5).withOpacity(0.3) // أزرق
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 85);

    final Paint paint4 = Paint()
      ..color = const Color(0xFF00BCD4).withOpacity(0.25) // سماوي
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 75);

    final Paint paint5 = Paint()
      ..color = const Color(0xFFFF9800).withOpacity(0.2) // برتقالي خفيف
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 95);

    final double x1 = size.width * 0.2 + math.sin(animationValue * 2 * math.pi) * 70;
    final double y1 = size.height * 0.25 + math.cos(animationValue * 2 * math.pi) * 60;

    final double x2 = size.width * 0.8 - math.cos(animationValue * 2 * math.pi) * 80;
    final double y2 = size.height * 0.75 + math.sin(animationValue * 2 * math.pi) * 70;

    final double x3 = size.width * 0.5 + math.sin(animationValue * math.pi * 1.5) * 90;
    final double y3 = size.height * 0.5 + math.cos(animationValue * math.pi * 1.5) * 80;

    final double x4 = size.width * 0.15 + math.cos(animationValue * math.pi) * 60;
    final double y4 = size.height * 0.8 + math.sin(animationValue * math.pi) * 50;

    final double x5 = size.width * 0.85 + math.sin(animationValue * 2 * math.pi) * 60;
    final double y5 = size.height * 0.2 + math.cos(animationValue * 2 * math.pi) * 60;

    canvas.drawCircle(Offset(x1, y1), 140, paint1);
    canvas.drawCircle(Offset(x2, y2), 160, paint2);
    canvas.drawCircle(Offset(x3, y3), 150, paint3);
    canvas.drawCircle(Offset(x4, y4), 120, paint4);
    canvas.drawCircle(Offset(x5, y5), 130, paint5);
  }

  @override
  bool shouldRepaint(covariant BubblesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}