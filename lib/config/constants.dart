import 'app_config_loader.dart';

/// الثوابت العامة للتطبيق
class AppConstants {
  // معلومات التطبيق - تُقرأ من app_config.yaml
  static String get appName => AppConfigLoader.appName;
  static String get appNameEn => AppConfigLoader.appNameEnglish;
  static const String appVersion = '1.0.0';
  
  // العملة - تُقرأ من app_config.yaml
  static String get defaultCurrency => AppConfigLoader.currencyCode;
  static String get currencySymbol => AppConfigLoader.currencySymbol;
  
  // التخزين
  static const String customersBox = 'customers';
  static const String transactionsBox = 'transactions';
  static const String settingsBox = 'settings';
  
  // مفاتيح الإعدادات
  static const String keyOwnerName = 'owner_name';
  static const String keyWhatsappNumber = 'whatsapp_number';
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyLastBackup = 'last_backup';
  static const String keyAutoBackup = 'auto_backup';
  static const String keyWifiOnlyBackup = 'wifi_only_backup';
  static const String keyDailyReminder = 'daily_reminder';
  static const String keyReminderFrequency = 'reminder_frequency';
  static const String keyPinEnabled = 'pin_enabled';
  static const String keyPinCode = 'pin_code';
  
  // قوالب رسائل الواتساب - تُقرأ من app_config.yaml
  static String get defaultReminderTemplate => AppConfigLoader.reminderTemplate;
  static String get defaultPaymentConfirmTemplate => AppConfigLoader.paymentConfirmationTemplate;
  static String get defaultNewDebtTemplate => AppConfigLoader.newDebtTemplate;
}


/// تكرار الإرسال
enum ReminderFrequency {
  daily('يومي'),
  weekly('أسبوعي'),
  monthly('شهري');

  final String label;
  const ReminderFrequency(this.label);
}

/// حالة الزبون
enum CustomerStatus {
  paid('مسدد', 'success'),
  pending('قيد الانتظار', 'warning'),
  overdue('متأخر', 'error');

  final String label;
  final String color;
  const CustomerStatus(this.label, this.color);
}

/// نوع القيد المالي
enum TransactionType {
  debt('بيع بالدين', 'debit'),
  payment('تسديد مبلغ', 'credit');

  final String label;
  final String type;
  const TransactionType(this.label, this.type);
}
