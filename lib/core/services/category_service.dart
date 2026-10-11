import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class CategoryService {
  static final ApiService _apiService = ApiService();
  static const String _categoriesKey = 'cached_categories';

  static Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedData = prefs.getString(_categoriesKey);
      if (cachedData != null) {
        return jsonDecode(cachedData);
      }
    }

    try {
      Response response = await _apiService.dio.get('/categories/');
      await prefs.setString(_categoriesKey, jsonEncode(response.data));
      return response.data;
    } catch (e) {
      final cachedData = prefs.getString(_categoriesKey);
      if (cachedData != null) return jsonDecode(cachedData);
      return [];
    }
  }

  // إضافة هذه الدالة لمسح الكاش فوراً عند أي تعديل
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_categoriesKey);
  }
}