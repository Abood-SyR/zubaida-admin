import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class GroupService {
  static final ApiService _apiService = ApiService();
  static const String _groupsKey = 'cached_product_groups';

  // 1. جلب المجموعات من السيرفر (/groups/) مع التخزين المؤقت
  static Future<List<dynamic>> getGroups({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedData = prefs.getString(_groupsKey);
      if (cachedData != null) return jsonDecode(cachedData);
    }

    try {
      Response response = await _apiService.dio.get('/groups/');
      List groups = response.data;
      
      await prefs.setString(_groupsKey, jsonEncode(groups));
      return groups;
    } catch (e) {
      final cachedData = prefs.getString(_groupsKey);
      if (cachedData != null) return jsonDecode(cachedData);
      return [];
    }
  }

  // 2. حذف مجموعة بناءً على الـ ID
  static Future<bool> deleteGroup(String id) async {
    try {
      await _apiService.dio.delete('/groups/$id');
      await clearGroupsCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 3. تعديل مجموعة موجودة مسبقاً
  static Future<bool> updateGroup(String id, Map<String, dynamic> data) async {
    try {
      await _apiService.dio.put('/groups/$id', data: data);
      await clearGroupsCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 4. إضافة مجموعة جديدة وإرسالها إلى /groups/
  static Future<bool> addGroup(Map<String, dynamic> data) async {
    try {
      await _apiService.dio.post('/groups/', data: data);
      await clearGroupsCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearGroupsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_groupsKey);
  }
}