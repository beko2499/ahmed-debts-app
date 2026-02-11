import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:google_sign_in/google_sign_in.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../services/app_lock_service.dart';
import '../../services/whatsapp_service.dart';

/// شاشة الإعدادات الرئيسية
class SettingsScreen extends StatefulWidget {
  final bool embedded;
  
  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _ownerName = '';
  String _whatsappNumber = '';
  bool _isAppLockEnabled = false;
  
  // صورة المالك
  final ImagePicker _imagePicker = ImagePicker();
  String? _ownerImagePath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final box = Hive.box(AppConstants.settingsBox);
    setState(() {
      _ownerName = box.get(AppConstants.keyOwnerName, defaultValue: '');
      _whatsappNumber = box.get(AppConstants.keyWhatsappNumber, defaultValue: '');
      _isAppLockEnabled = AppLockService().isLockEnabled;
      _ownerImagePath = box.get('owner_image_path');
    });
  }

  /// اختيار صورة المالك
  Future<void> _pickOwnerImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('اختيار من المعرض'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (image != null) {
                  await _saveOwnerImage(File(image.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('التقاط صورة'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (image != null) {
                  await _saveOwnerImage(File(image.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOwnerImage(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final newPath = '${appDir.path}/owner_profile.jpg';
    await imageFile.copy(newPath);
    
    final box = Hive.box(AppConstants.settingsBox);
    await box.put('owner_image_path', newPath);
    
    setState(() => _ownerImagePath = newPath);
    if (mounted) {
      AppUtils.showSuccess(context, 'تم تحديث الصورة بنجاح');
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    final authService = AppLockService();
    
    // التحقق من المصادقة قبل التغيير
    final authenticated = await authService.authenticate();
    if (!authenticated) return;

    await authService.setLockEnabled(value);
    setState(() => _isAppLockEnabled = value);
    
    if (mounted) {
      AppUtils.showSuccess(
        context, 
        value ? 'تم تفعيل قفل التطبيق' : 'تم إلغاء قفل التطبيق'
      );
    }
  }

  Future<void> _openAccessibilitySettings() async {
    // عرض رسالة توضيحية أولاً
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفعيل الإرسال التلقائي'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('لتفعيل إرسال رسائل واتساب تلقائياً:'),
            SizedBox(height: 12),
            Text('1. اضغط "فتح الإعدادات"'),
            Text('2. ابحث عن "Ghazali Debts"'),
            Text('3. فعّل الخدمة'),
            SizedBox(height: 16),
            Text(
              '⚠️ تحذير: هذه الطريقة غير رسمية وقد تسبب حظر حسابك',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await WhatsAppService().openAccessibilitySettings();
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
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

    if (confirm == true && mounted) {
      try {
        // تسجيل الخروج من Google
        await GoogleSignIn().signOut();
      } catch (e) {
        debugPrint('Error signing out: $e');
      }
      
      final box = Hive.box(AppConstants.settingsBox);
      await box.put(AppConstants.keyIsFirstLaunch, true);
      
      // مسح جميع الشاشات والذهاب لشاشة الإعداد
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          AppRoutes.setup, 
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header للوضع المضمن
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                'الإعدادات',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        
        // بطاقة الملف الشخصي
        _buildProfileCard(),

        const SizedBox(height: 24),

        // إعدادات النسخ الاحتياطي
        _buildSettingsGroup([
          _buildSettingItem(
            icon: Icons.backup,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primary.withValues(alpha: 0.1),
            title: 'نسخ احتياطي واستعادة',
            subtitle: 'مزامنة Google Drive',
            onTap: () => Navigator.pushNamed(context, AppRoutes.backup),
          ),
        ]),

        const SizedBox(height: 16),

        // إعدادات الإشعارات والأمان
        _buildSettingsGroup([
          _buildSettingItem(
            icon: Icons.chat,
            iconColor: AppColors.whatsapp,
            iconBgColor: AppColors.whatsapp.withValues(alpha: 0.1),
            title: 'إعدادات إشعارات واتساب',
            subtitle: 'إدارة جميع الإشعارات',
            onTap: () => Navigator.pushNamed(context, AppRoutes.whatsappSettings),
          ),
          _buildSettingItem(
            icon: Icons.send,
            iconColor: AppColors.whatsapp,
            iconBgColor: AppColors.whatsapp.withValues(alpha: 0.1),
            title: 'ربط واتساب (إرسال تلقائي)',
            subtitle: 'إرسال رسائل في الخلفية بالكامل',
            onTap: () => Navigator.pushNamed(context, AppRoutes.whatsappConnection),
          ),
          _buildSettingItem(
            icon: Icons.lock,
            iconColor: Colors.indigo,
            iconBgColor: Colors.indigo.withValues(alpha: 0.1),
            title: 'قفل التطبيق',
            subtitle: _isAppLockEnabled ? 'مفعل' : 'غير مفعل',
            onTap: () => _toggleAppLock(!_isAppLockEnabled),
            trailing: Switch(
              value: _isAppLockEnabled,
              onChanged: _toggleAppLock,
              activeColor: AppColors.primary,
            ),
          ),
        ]),

        const SizedBox(height: 24),

        // زر تسجيل الخروج
        Container(
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            onTap: _logout,
            leading: Icon(Icons.logout, color: AppColors.error),
            title: Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );

    // إذا كان مضمناً، نعيد المحتوى فقط بدون Scaffold
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات التطبيق'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward),
        ),
      ),
      body: body,
    );
  }

  Widget _buildProfileCard() {
    return InkWell(
      onTap: _editProfile,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            // الصورة
            GestureDetector(
              onTap: _pickOwnerImage,
              child: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      final hasImage = _ownerImagePath != null && 
                                      _ownerImagePath!.isNotEmpty && 
                                      File(_ownerImagePath!).existsSync();
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.backgroundLight,
                          border: Border.all(color: AppColors.gold, width: 2),
                          image: hasImage
                              ? DecorationImage(
                                  image: FileImage(File(_ownerImagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: !hasImage
                            ? Icon(Icons.person, size: 32, color: AppColors.primary)
                            : null,
                      );
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // المعلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ownerName.isNotEmpty ? _ownerName : 'صاحب المحل',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اضغط لتعديل الملف الشخصي',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _ownerName);
    final whatsappController = TextEditingController(text: _whatsappNumber);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الملف الشخصي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم صاحب المحل',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: whatsappController,
              decoration: const InputDecoration(
                labelText: 'رقم واتساب',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) {
      final box = Hive.box(AppConstants.settingsBox);
      await box.put(AppConstants.keyOwnerName, nameController.text.trim());
      await box.put(AppConstants.keyWhatsappNumber, whatsappController.text.trim());
      _loadSettings();
      
      if (mounted) {
        AppUtils.showSuccess(context, 'تم حفظ التغييرات بنجاح');
      }
    }
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Column(
            children: [
              child,
              if (index < children.length - 1)
                Divider(height: 1, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textLight,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_left, color: AppColors.textLight),
    );
  }
}
