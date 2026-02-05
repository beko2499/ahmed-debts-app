/// الثوابت العامة للتطبيق
class AppConstants {
  // معلومات التطبيق
  static const String appName = 'ديون الغزالي';
  static const String appNameEn = 'Al-Ghazali Debt Manager';
  static const String appVersion = '1.0.0';
  
  // العملة
  static const String defaultCurrency = 'IQD';
  static const String currencySymbol = 'د.ع';
  
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
  
  // قوالب رسائل الواتساب
  static const String defaultReminderTemplate = '''
مرحباً {اسم_الزبون}،
نود تذكيركم بأن المبلغ المستحق في ذمتكم هو {المبلغ}.
يرجى التفضل بالسداد في أقرب وقت ممكن.
شكراً لتعاملكم مع الغزالي.
''';

  static const String defaultPaymentConfirmTemplate = '''
مرحباً {اسم_الزبون}،
نشكركم على سداد مبلغ {المبلغ}.
رصيدكم الحالي: {الرصيد_الحالي}.
شكراً لتعاملكم مع الغزالي.
''';

  static const String defaultNewDebtTemplate = '''
مرحباً {اسم_الزبون}،
تم تسجيل دين جديد بقيمة {المبلغ}.
إجمالي ذمتكم: {الرصيد_الحالي}.
الغزالي.
''';
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
