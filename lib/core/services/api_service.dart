import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  late final Dio dio;

  // ضع رابط السيرفر الأساسي هنا (مثلاً رابط الـ Hugging Face أو السيرفر المحلي)
  static const String baseUrl = 'https://resonta-yalla-match-notifications.hf.space';

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // إضافة Interceptor لإرفاق الـ Token تلقائياً في الطلبات المحمية
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // يمكنك معالجة أخطاء المصادقة هنا (مثل انتهاء الصلاحية 401)
          return handler.next(e);
        },
      ),
    );
  }
}