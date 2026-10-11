import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class OfferService {
  static final ApiService _apiService = ApiService();
  static const String _discountsKey = 'cached_discounts';
  static const String _bundlesKey = 'cached_bundles';

  // 1. جلب الخصومات الفردية من السيرفر (/offers/)
  static Future<List<dynamic>> getDiscounts({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedData = prefs.getString(_discountsKey);
      if (cachedData != null) return jsonDecode(cachedData);
    }

    try {
      Response response = await _apiService.dio.get('/offers/');
      List allOffers = response.data;
      List discounts = allOffers.where((o) => o['offer_type'] == 'single_discount').toList();
      
      await prefs.setString(_discountsKey, jsonEncode(discounts));
      return discounts;
    } catch (e) {
      final cachedData = prefs.getString(_discountsKey);
      if (cachedData != null) return jsonDecode(cachedData);
      return [];
    }
  }

  // 2. جلب عروض الحزم من السيرفر (/offers/)
  static Future<List<dynamic>> getBundles({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedData = prefs.getString(_bundlesKey);
      if (cachedData != null) return jsonDecode(cachedData);
    }

    try {
      Response response = await _apiService.dio.get('/offers/');
      List allOffers = response.data;
      List bundles = allOffers.where((o) => o['offer_type'] == 'bundle').toList();
      
      await prefs.setString(_bundlesKey, jsonEncode(bundles));
      return bundles;
    } catch (e) {
      final cachedData = prefs.getString(_bundlesKey);
      if (cachedData != null) return jsonDecode(cachedData);
      return [];
    }
  }

  // 3. حذف عرض أو حزمة بناءً على الـ ID
  static Future<bool> deleteOffer(String id) async {
    try {
      await _apiService.dio.delete('/offers/$id');
      await clearDiscountsCache();
      await clearBundlesCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 4. تعديل عرض أو حزمة موجودة مسبقاً
  static Future<bool> updateOffer(String id, Map<String, dynamic> data) async {
    try {
      await _apiService.dio.put('/offers/$id', data: data);
      await clearDiscountsCache();
      await clearBundlesCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 5. إضافة خصم جديد وإرساله إلى /offers/
  static Future<bool> addDiscount(Map<String, dynamic> data) async {
    try {
      await _apiService.dio.post('/offers/', data: data);
      await clearDiscountsCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 6. إضافة حزمة جديدة وإرسالها إلى /offers/
  static Future<bool> addBundle(Map<String, dynamic> data) async {
    try {
      await _apiService.dio.post('/offers/', data: data);
      await clearBundlesCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearDiscountsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_discountsKey);
  }

  static Future<void> clearBundlesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bundlesKey);
  }
}