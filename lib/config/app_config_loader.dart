import 'dart:io';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// مُحمّل الإعدادات المركزي
/// يقرأ الإعدادات من ملف app_config.yaml
class AppConfigLoader {
  static AppConfigLoader? _instance;
  static YamlMap? _config;
  static bool _isLoaded = false;

  AppConfigLoader._();

  static AppConfigLoader get instance {
    _instance ??= AppConfigLoader._();
    return _instance!;
  }

  /// تحميل الإعدادات من الملف
  static Future<void> load() async {
    if (_isLoaded) return;
    
    try {
      final String yamlString = await rootBundle.loadString('app_config.yaml');
      _config = loadYaml(yamlString);
      _isLoaded = true;
      print('✅ App config loaded successfully');
    } catch (e) {
      print('⚠️ Failed to load app_config.yaml: $e');
      print('📌 Using default values');
      _config = null;
      _isLoaded = true;
    }
  }

  /// التأكد من تحميل الإعدادات
  static void ensureLoaded() {
    if (!_isLoaded) {
      throw Exception('AppConfigLoader not loaded. Call AppConfigLoader.load() first.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //                         معلومات التطبيق
  // ═══════════════════════════════════════════════════════════════════
  
  static String get appName {
    return _getNestedValue(['app', 'name']) ?? 'ديون الغزالي';
  }

  static String get appNameEnglish {
    return _getNestedValue(['app', 'name_english']) ?? 'Ghazali Debts';
  }

  static String get packageId {
    return _getNestedValue(['app', 'package_id']) ?? 'com.ghazali.ahmed_debts';
  }

  // ═══════════════════════════════════════════════════════════════════
  //                         إعدادات العملة
  // ═══════════════════════════════════════════════════════════════════
  
  static String get currencySymbol {
    return _getNestedValue(['currency', 'symbol']) ?? 'ج.س';
  }

  static String get currencyName {
    return _getNestedValue(['currency', 'name']) ?? 'جنيه سوداني';
  }

  static String get currencyCode {
    return _getNestedValue(['currency', 'code']) ?? 'SDG';
  }

  // ═══════════════════════════════════════════════════════════════════
  //                         سيرفر الواتساب
  // ═══════════════════════════════════════════════════════════════════
  
  static String get whatsappServerUrl {
    return _getNestedValue(['whatsapp', 'server_url']) ?? 
        'https://ghazali-whatsapp-server-production-f464.up.railway.app';
  }

  // ═══════════════════════════════════════════════════════════════════
  //                         الألوان
  // ═══════════════════════════════════════════════════════════════════
  
  static int get primaryColor {
    return _parseColor(_getNestedValue(['colors', 'primary'])) ?? 0xFF0F3BBD;
  }

  static int get primaryLightColor {
    return _parseColor(_getNestedValue(['colors', 'primary_light'])) ?? 0xFFE8EFFF;
  }

  static int get goldColor {
    return _parseColor(_getNestedValue(['colors', 'gold'])) ?? 0xFFD4AF37;
  }

  static int get successColor {
    return _parseColor(_getNestedValue(['colors', 'success'])) ?? 0xFF22C55E;
  }

  static int get warningColor {
    return _parseColor(_getNestedValue(['colors', 'warning'])) ?? 0xFFEAB308;
  }

  static int get errorColor {
    return _parseColor(_getNestedValue(['colors', 'error'])) ?? 0xFFEF4444;
  }

  static int get whatsappColor {
    return _parseColor(_getNestedValue(['colors', 'whatsapp'])) ?? 0xFF25D366;
  }

  // ═══════════════════════════════════════════════════════════════════
  //                         قوالب الرسائل
  // ═══════════════════════════════════════════════════════════════════
  
  static String get reminderTemplate {
    return _getNestedValue(['messages', 'reminder'])?.toString().trim() ?? '''
مرحباً {اسم_الزبون}،
نود تذكيركم بأن المبلغ المستحق في ذمتكم هو {المبلغ}.
يرجى التفضل بالسداد في أقرب وقت ممكن.
شكراً لتعاملكم مع الغزالي.
''';
  }

  static String get paymentConfirmationTemplate {
    return _getNestedValue(['messages', 'payment_confirmation'])?.toString().trim() ?? '''
تم استلام دفعة بقيمة {المبلغ} من {اسم_الزبون}.
الرصيد المتبقي: {الرصيد_الحالي}
شكراً لكم.
''';
  }

  static String get newDebtTemplate {
    return _getNestedValue(['messages', 'new_debt'])?.toString().trim() ?? '''
مرحباً {اسم_الزبون}،
تم تسجيل دين جديد بقيمة {المبلغ_الكلي}.
الدفعة الأولى: {الدفعة_الأولى}
المتبقي: {المتبقي}
شكراً لتعاملكم معنا.
''';
  }

  // ═══════════════════════════════════════════════════════════════════
  //                         دوال مساعدة
  // ═══════════════════════════════════════════════════════════════════

  static dynamic _getNestedValue(List<String> keys) {
    if (_config == null) return null;
    
    dynamic value = _config;
    for (final key in keys) {
      if (value is YamlMap && value.containsKey(key)) {
        value = value[key];
      } else {
        return null;
      }
    }
    return value;
  }

  static int? _parseColor(dynamic colorValue) {
    if (colorValue == null) return null;
    
    String colorStr = colorValue.toString().trim();
    // إزالة # إذا وجدت
    if (colorStr.startsWith('#')) {
      colorStr = colorStr.substring(1);
    }
    
    try {
      return int.parse('0xFF$colorStr');
    } catch (e) {
      print('⚠️ Invalid color value: $colorValue');
      return null;
    }
  }
}
