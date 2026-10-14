import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class SearchManagementService {
  static final ApiService _apiService = ApiService();

  // --- 1. إعدادات البحث ---
  static const String _settingsCacheKey = 'cached_search_settings';

  static Future<List<dynamic>> getSearchSettings({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getString(_settingsCacheKey);
      if (cached != null) return jsonDecode(cached);
    }
    try {
      Response response = await _apiService.dio.get('/admin/search-config/settings');
      await prefs.setString(_settingsCacheKey, jsonEncode(response.data));
      return response.data;
    } catch (e) {
      final cached = prefs.getString(_settingsCacheKey);
      if (cached != null) return jsonDecode(cached);
      return [];
    }
  }

  static Future<bool> updateSetting(String settingKey, bool isEnabled) async {
    try {
      await _apiService.dio.patch('/admin/search-config/settings/$settingKey', data: {
        "is_enabled": isEnabled,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 2. الكلمات المرادفة (Synonyms) ---
  static const String _synonymsCacheKey = 'cached_search_synonyms';

  static Future<List<dynamic>> getSynonyms({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getString(_synonymsCacheKey);
      if (cached != null) return jsonDecode(cached);
    }
    try {
      Response response = await _apiService.dio.get('/admin/search-config/synonyms');
      await prefs.setString(_synonymsCacheKey, jsonEncode(response.data));
      return response.data;
    } catch (e) {
      final cached = prefs.getString(_synonymsCacheKey);
      if (cached != null) return jsonDecode(cached);
      return [];
    }
  }

  static Future<bool> createSynonym(String targetWord, String synonymWord) async {
    try {
      await _apiService.dio.post('/admin/search-config/synonyms', data: {
        "target_word": targetWord,
        "synonym_word": synonymWord,
        "is_active": true,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_synonymsCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteSynonym(String id) async {
    try {
      await _apiService.dio.delete('/admin/search-config/synonyms/$id');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_synonymsCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 3. سجّلات البحث بلا نتائج (Zero Results & AI Insights) ---
  static const String _zeroResultsCacheKey = 'cached_zero_results_logs';

  static Future<List<dynamic>> getZeroResultsLogs({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getString(_zeroResultsCacheKey);
      if (cached != null) return jsonDecode(cached);
    }
    try {
      Response response = await _apiService.dio.get('/admin/search-config/zero-results');
      await prefs.setString(_zeroResultsCacheKey, jsonEncode(response.data));
      return response.data;
    } catch (e) {
      final cached = prefs.getString(_zeroResultsCacheKey);
      if (cached != null) return jsonDecode(cached);
      return [];
    }
  }

  static Future<bool> deleteZeroResultLog(String id) async {
    try {
      await _apiService.dio.delete('/admin/search-config/zero-results/$id');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_zeroResultsCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // حذف مجموعة سجلات دفعة واحدة (Batch Delete)
  static Future<bool> batchDeleteZeroResults(List<String> ids) async {
    try {
      await _apiService.dio.post('/admin/search-config/zero-results/batch-delete', data: {
        "ids": ids,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_zeroResultsCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // تفريغ كافة السجلات
  static Future<bool> clearAllZeroResults() async {
    try {
      await _apiService.dio.delete('/admin/search-config/zero-results/clear-all');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_zeroResultsCacheKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // إرسال طلب تحليل الذكاء الاصطناعي (Gemini AI Insights) مع مهلة زمنية واسعة جداً لمنع إلغاء الطلب[cite: 6]
  static Future<Map<String, dynamic>?> generateAiInsights({String modelName = 'gemini-2.5-flash'}) async {
    try {
      Response response = await _apiService.dio.post(
        '/admin/search-config/zero-results/ai-insights',
        data: {
          "model_name": modelName,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_zeroResultsCacheKey);
      return response.data;
    } catch (e) {
      print("AI Insights Error: $e");
      return null;
    }
  }

  // --- 4. أرشيف تقارير الذكاء الاصطناعي (محلياً عبر SharedPreferences) ---
  static const String _aiReportsHistoryKey = 'cached_ai_reports_history';

  // جلب أرشيف التقارير المحفوظة
  static Future<List<dynamic>> getAiReportsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_aiReportsHistoryKey);
    if (cached != null) {
      try {
        return jsonDecode(cached);
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // حفظ تقرير جديد في الأرشيف المحلي
  static Future<void> saveAiReportToHistory(String report, String modelUsed, int clearedCount) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> history = await getAiReportsHistory();

    final newReportRecord = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'model_used': modelUsed,
      'cleared_count': clearedCount,
      'report': report,
    };

    history.insert(0, newReportRecord); // وضع الأحدث في البداية
    if (history.length > 50) {
      history = history.sublist(0, 50); // الاحتفاظ بآخر 50 تقريراً فقط
    }

    await prefs.setString(_aiReportsHistoryKey, jsonEncode(history));
  }

  // حذف تقرير معين من الأرشيف المحلي
  static Future<void> deleteAiReportFromHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> history = await getAiReportsHistory();
    history.removeWhere((item) => item['id']?.toString() == id);
    await prefs.setString(_aiReportsHistoryKey, jsonEncode(history));
  }
}