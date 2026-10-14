import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class UiManageService {
  static final ApiService _apiService = ApiService();

  // --- 1. خدمة الكلمات الرائجة (Trending Keywords) ---
  static const String _trendingCacheKey = 'cached_trending_keywords';

  static Future<List<dynamic>> getTrendingKeywords({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedData = prefs.getString(_trendingCacheKey);
      if (cachedData != null) {
        return jsonDecode(cachedData);
      }
    }

    try {
      Response response = await _apiService.dio.get('/admin/trending-keywords/');
      await prefs.setString(_trendingCacheKey, jsonEncode(response.data));
      return response.data;
    } catch (e) {
      final cachedData = prefs.getString(_trendingCacheKey);
      if (cachedData != null) return jsonDecode(cachedData);
      return [];
    }
  }

  static Future<bool> addTrendingKeyword(String keyword, int displayOrder) async {
    try {
      await _apiService.dio.post('/admin/trending-keywords/', data: {
        "keyword": keyword,
        "display_order": displayOrder,
        "is_active": true,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trendingCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteTrendingKeyword(String id) async {
    try {
      await _apiService.dio.delete('/admin/trending-keywords/$id');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trendingCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 2. خدمة المنتجات المقترحة للبحث (Suggested Products) ---
  static const String _suggestedCacheKey = 'cached_suggested_products';

  static Future<List<dynamic>> getSuggestedProducts({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedData = prefs.getString(_suggestedCacheKey);
      if (cachedData != null) {
        return jsonDecode(cachedData);
      }
    }

    try {
      Response response = await _apiService.dio.get('/admin/suggested-products/');
      await prefs.setString(_suggestedCacheKey, jsonEncode(response.data));
      return response.data;
    } catch (e) {
      final cachedData = prefs.getString(_suggestedCacheKey);
      if (cachedData != null) return jsonDecode(cachedData);
      return [];
    }
  }

  static Future<bool> setSuggestedProduct(String productId, int displayOrder) async {
    try {
      await _apiService.dio.post('/admin/suggested-products/', data: {
        "product_id": productId,
        "display_order": displayOrder,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_suggestedCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteSuggestedProduct(String id) async {
    try {
      await _apiService.dio.delete('/admin/suggested-products/$id');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_suggestedCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 3. خدمة أبرز المنتجات (Featured Grid Products) ---
  static const String _gridCacheKey = 'cached_home_grid_products';

  static Future<List<dynamic>> getGridProducts({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedData = prefs.getString(_gridCacheKey);
      if (cachedData != null) {
        return jsonDecode(cachedData);
      }
    }

    try {
      Response response = await _apiService.dio.get('/admin/featured-products/');
      await prefs.setString(_gridCacheKey, jsonEncode(response.data));
      return response.data;
    } catch (e) {
      final cachedData = prefs.getString(_gridCacheKey);
      if (cachedData != null) return jsonDecode(cachedData);
      return [];
    }
  }

  static Future<bool> addFeaturedProduct(String productId, int displayOrder) async {
    try {
      await _apiService.dio.post('/admin/featured-products/', data: {
        "product_id": productId,
        "display_order": displayOrder,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gridCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteFeaturedProduct(String recordId) async {
    try {
      await _apiService.dio.delete('/admin/featured-products/$recordId');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gridCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearAllCaches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trendingCacheKey);
    await prefs.remove(_suggestedCacheKey);
    await prefs.remove(_gridCacheKey);
  }
}