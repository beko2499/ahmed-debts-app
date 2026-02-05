import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';

/// شاشة إعداد الحساب لأول مرة
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();

    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final settingsBox = Hive.box(AppConstants.settingsBox);
      await settingsBox.put(AppConstants.keyOwnerName, _nameController.text.trim());
      await settingsBox.put(AppConstants.keyWhatsappNumber, _whatsappController.text.trim());

      await settingsBox.put(AppConstants.keyIsFirstLaunch, false);
      
      // إعداد القوالب الافتراضية
      await settingsBox.put('reminderTemplate', AppConstants.defaultReminderTemplate);
      await settingsBox.put('paymentConfirmTemplate', AppConstants.defaultPaymentConfirmTemplate);
      await settingsBox.put('newDebtTemplate', AppConstants.defaultNewDebtTemplate);

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'حدث خطأ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد الحساب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أيقونة
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.store,
                    size: 50,
                    color: AppColors.primary,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // العنوان
              Center(
                child: Text(
                  'أخبرنا عن متجرك',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Center(
                child: Text(
                  'هذه المعلومات ستُستخدم في إرسال التذكيرات',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // حقل الاسم
              Text(
                'اسم صاحب المتجر',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'مثال: أحمد الغزالي',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال الاسم';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // حقل رقم الواتساب
              Text(
                'رقم الواتساب (للتواصل معك)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'مثال: 07701234567',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال رقم الواتساب';
                  }
                  return null;
                },
              ),
              

              
              const SizedBox(height: 48),
              
              // ملاحظة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.gold, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'يمكنك تعديل هذه الإعدادات لاحقاً من صفحة الإعدادات',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // زر المتابعة
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndContinue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('متابعة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
