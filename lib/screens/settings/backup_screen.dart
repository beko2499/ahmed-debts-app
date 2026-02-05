import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/backup_service.dart';

/// شاشة النسخ الاحتياطي واستعادة البيانات
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backupService = BackupService();
  
  bool _autoBackup = true;
  bool _wifiOnly = true;
  DateTime? _lastBackup;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLoading = true;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    // التحقق من تسجيل الدخول
    final signedIn = await _backupService.checkPreviousSignIn();
    
    final box = Hive.box(AppConstants.settingsBox);
    final lastBackupDate = await _backupService.getLastBackupDate();
    
    setState(() {
      _isSignedIn = signedIn;
      _autoBackup = box.get(AppConstants.keyAutoBackup, defaultValue: true);
      _wifiOnly = box.get(AppConstants.keyWifiOnlyBackup, defaultValue: true);
      _lastBackup = lastBackupDate;
      _isLoading = false;
    });
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    final success = await _backupService.signIn();
    setState(() {
      _isSignedIn = success;
      _isLoading = false;
    });
    
    if (!success && mounted) {
      AppUtils.showError(context, 'فشل تسجيل الدخول. حاول مرة أخرى');
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد فصل حساب Google؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('تسجيل الخروج', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _backupService.signOut();
      setState(() => _isSignedIn = false);
    }
  }

  Future<void> _backupNow() async {
    if (!_isSignedIn) {
      AppUtils.showError(context, 'يرجى ربط حساب Google أولاً');
      return;
    }

    setState(() => _isBackingUp = true);
    
    try {
      final result = await _backupService.backup();
      
      if (result.success) {
        final box = Hive.box(AppConstants.settingsBox);
        final now = DateTime.now();
        await box.put(AppConstants.keyLastBackup, now.toIso8601String());
        setState(() => _lastBackup = now);
      }
      
      if (mounted) {
        if (result.success) {
          AppUtils.showSuccess(context, result.message);
        } else {
          AppUtils.showError(context, result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'فشل النسخ الاحتياطي: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _restoreData() async {
    if (!_isSignedIn) {
      AppUtils.showError(context, 'يرجى ربط حساب Google أولاً');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ استعادة البيانات'),
        content: const Text(
          'سيتم استبدال جميع البيانات الحالية بالنسخة الاحتياطية.\n\n'
          'هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('استعادة', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);
    
    try {
      final result = await _backupService.restore();
      
      if (mounted) {
        if (result.success) {
          AppUtils.showSuccess(context, result.message);
        } else {
          AppUtils.showError(context, result.message);
        }

        if (result.success) {
          // إعادة تحميل التطبيق
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('تمت الاستعادة'),
              content: const Text('تم استعادة البيانات بنجاح. يرجى إعادة تشغيل التطبيق.'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'فشلت الاستعادة: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put(AppConstants.keyAutoBackup, value);
    setState(() => _autoBackup = value);
  }

  Future<void> _toggleWifiOnly(bool value) async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put(AppConstants.keyWifiOnlyBackup, value);
    setState(() => _wifiOnly = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نسخ احتياطي واستعادة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // حالة الاتصال
                _buildConnectionCard(),

                const SizedBox(height: 16),

                // حالة النسخ الاحتياطي
                if (_isSignedIn) ...[
                  _buildBackupStatusCard(),
                  
                  const SizedBox(height: 16),

                  // أزرار النسخ والاستعادة
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isBackingUp ? null : _backupNow,
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: const Text('نسخ احتياطي الآن'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: _isRestoring ? null : _restoreData,
                    icon: _isRestoring
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(Icons.cloud_download, color: AppColors.primary),
                    label: Text(
                      'استعادة البيانات',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // الخيارات التلقائية
                  Text(
                    'الخيارات التلقائية',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),

                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _autoBackup,
                          onChanged: _toggleAutoBackup,
                          title: const Text(
                            'نسخ احتياطي يومي تلقائي',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'يتم النسخ عند استخدام التطبيق',
                            style: TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                          activeColor: AppColors.primary,
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        SwitchListTile(
                          value: _wifiOnly,
                          onChanged: _toggleWifiOnly,
                          title: const Text(
                            'المزامنة عبر Wi-Fi فقط',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'لتجنب استهلاك بيانات الهاتف',
                            style: TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ملاحظة
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'يتم حفظ النسخة الاحتياطية في مجلد خاص بالتطبيق على Google Drive',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // أيقونة Google Drive
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isSignedIn ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.cloud,
                  size: 32,
                  color: _isSignedIn ? AppColors.success : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSignedIn ? 'متصل بـ Google Drive' : 'غير متصل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isSignedIn ? AppColors.success : AppColors.textLight,
                      ),
                    ),
                    if (_isSignedIn && _backupService.userEmail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _backupService.userEmail!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _isSignedIn
                ? OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.link_off),
                    label: const Text('فصل الحساب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _signIn,
                    icon: const Icon(Icons.link),
                    label: const Text('ربط حساب Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          // أيقونة السحابة
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.cloud,
                  size: 40,
                  color: AppColors.primary,
                ),
                if (_lastBackup != null)
                  Positioned(
                    bottom: 15,
                    child: Icon(
                      Icons.check_circle,
                      size: 20,
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // آخر نسخة
          Text(
            'آخر نسخة احتياطية',
            style: TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 4),
          Text(
            _lastBackup != null
                ? '${_lastBackup!.day}/${_lastBackup!.month}/${_lastBackup!.year} • ${_formatTime(_lastBackup!)}'
                : 'لم يتم النسخ الاحتياطي بعد',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // حالة الاتصال
          if (_lastBackup != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'بياناتك آمنة ومزامنة',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}
