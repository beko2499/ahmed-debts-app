import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive/hive.dart';
import '../config/constants.dart';

class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;

  /// هل القفل مفعل من الإعدادات؟
  bool get isLockEnabled {
    final box = Hive.box(AppConstants.settingsBox);
    return box.get('is_app_lock_enabled', defaultValue: false);
  }

  /// تفعيل/تعطيل القفل
  Future<void> setLockEnabled(bool value) async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put('is_app_lock_enabled', value);
  }

  /// هل المستخدم موثق حالياً؟ (للجلسة الحالية)
  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
  }

  /// طلب المصادقة (بصمة أو رمز)
  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        // إذا كان الجهاز لا يدعم، نعتبره موثقاً لتجنب القفل الدائم
        return true;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'الرجاء المصادقة لفتح التطبيق',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // يسمح بالرمز أيضاً
        ),
      );

      _isAuthenticated = didAuthenticate;
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
