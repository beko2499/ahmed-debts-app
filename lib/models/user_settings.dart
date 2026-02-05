/// نموذج إعدادات المستخدم
class UserSettings {
  final String ownerName;
  final String whatsappNumber;
  final String? googleEmail;
  final bool autoBackup;
  final bool wifiOnlyBackup;
  final bool dailyReminder;
  final String reminderFrequency;
  final DateTime? lastBackup;
  final String reminderTemplate;
  final String paymentConfirmTemplate;
  final String newDebtTemplate;

  const UserSettings({
    required this.ownerName,
    required this.whatsappNumber,
    this.googleEmail,
    this.autoBackup = true,
    this.wifiOnlyBackup = true,
    this.dailyReminder = true,
    this.reminderFrequency = 'daily',
    this.lastBackup,
    this.reminderTemplate = '',
    this.paymentConfirmTemplate = '',
    this.newDebtTemplate = '',
  });

  UserSettings copyWith({
    String? ownerName,
    String? whatsappNumber,
    String? googleEmail,
    bool? autoBackup,
    bool? wifiOnlyBackup,
    bool? dailyReminder,
    String? reminderFrequency,
    DateTime? lastBackup,
    String? reminderTemplate,
    String? paymentConfirmTemplate,
    String? newDebtTemplate,
  }) {
    return UserSettings(
      ownerName: ownerName ?? this.ownerName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      googleEmail: googleEmail ?? this.googleEmail,
      autoBackup: autoBackup ?? this.autoBackup,
      wifiOnlyBackup: wifiOnlyBackup ?? this.wifiOnlyBackup,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      lastBackup: lastBackup ?? this.lastBackup,
      reminderTemplate: reminderTemplate ?? this.reminderTemplate,
      paymentConfirmTemplate: paymentConfirmTemplate ?? this.paymentConfirmTemplate,
      newDebtTemplate: newDebtTemplate ?? this.newDebtTemplate,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerName': ownerName,
    'whatsappNumber': whatsappNumber,
    'googleEmail': googleEmail,
    'autoBackup': autoBackup,
    'wifiOnlyBackup': wifiOnlyBackup,
    'dailyReminder': dailyReminder,
    'reminderFrequency': reminderFrequency,
    'lastBackup': lastBackup?.toIso8601String(),
    'reminderTemplate': reminderTemplate,
    'paymentConfirmTemplate': paymentConfirmTemplate,
    'newDebtTemplate': newDebtTemplate,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    ownerName: json['ownerName'] as String? ?? '',
    whatsappNumber: json['whatsappNumber'] as String? ?? '',
    googleEmail: json['googleEmail'] as String?,
    autoBackup: json['autoBackup'] as bool? ?? true,
    wifiOnlyBackup: json['wifiOnlyBackup'] as bool? ?? true,
    dailyReminder: json['dailyReminder'] as bool? ?? true,
    reminderFrequency: json['reminderFrequency'] as String? ?? 'daily',
    lastBackup: json['lastBackup'] != null 
        ? DateTime.parse(json['lastBackup'] as String) 
        : null,
    reminderTemplate: json['reminderTemplate'] as String? ?? '',
    paymentConfirmTemplate: json['paymentConfirmTemplate'] as String? ?? '',
    newDebtTemplate: json['newDebtTemplate'] as String? ?? '',
  );

  static const UserSettings empty = UserSettings(
    ownerName: '',
    whatsappNumber: '',
  );
}
