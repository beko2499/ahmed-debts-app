import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../services/whatsapp_service.dart';

/// شاشة إعدادات إشعارات الواتساب - محسّنة
class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  bool _isLoading = false;
  
  // إعدادات كل نوع إشعار
  final Map<NotificationType, NotificationSettings> _settings = {};
  
  // Controllers للنصوص
  final Map<NotificationType, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadSettings();
  }

  void _initControllers() {
    for (final type in NotificationType.values) {
      _controllers[type] = TextEditingController(text: type.defaultTemplate);
      _settings[type] = NotificationSettings(
        isEnabled: true,
        template: type.defaultTemplate,
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      final box = await Hive.openBox(AppConstants.settingsBox);
      
      for (final type in NotificationType.values) {
        final isEnabled = box.get('${type.key}_enabled', defaultValue: true);
        final template = box.get('${type.key}_template', defaultValue: type.defaultTemplate);
        
        setState(() {
          _settings[type] = NotificationSettings(
            isEnabled: isEnabled,
            template: template,
          );
          _controllers[type]!.text = template;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final box = await Hive.openBox(AppConstants.settingsBox);
      
      for (final type in NotificationType.values) {
        await box.put('${type.key}_enabled', _settings[type]!.isEnabled);
        await box.put('${type.key}_template', _controllers[type]!.text);
      }

      if (mounted) {
        AppUtils.showSuccess(context, 'تم حفظ الإعدادات');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'حدث خطأ: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestMessage(NotificationType type) async {
    // إرسال رسالة تجريبية باستخدام WhatsApp Service
    final box = await Hive.openBox(AppConstants.settingsBox);
    final userPhone = box.get(AppConstants.keyWhatsappNumber, defaultValue: '');

    if (userPhone.isEmpty) {
        AppUtils.showError(context, 'يرجى إعداد رقم الواتساب أولاً من صفحة إعداد الحساب');
        return;
    }

    final result = await WhatsAppService().sendMessage(
      phoneNumber: userPhone,
      message: '🧪 رسالة اختبار: ${type.title}\n\n${_controllers[type]!.text}',
    );

    if (mounted) {
      if (result) {
        AppUtils.showSuccess(context, 'جاري فتح واتساب...');
      } else {
        AppUtils.showError(context, 'فشل فتح واتساب');
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات إشعارات واتساب'),
        backgroundColor: AppColors.whatsapp,
        foregroundColor: Colors.white,
        actions: [],
      ),
      body: Column(
        children: [
          // قائمة الإشعارات
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: NotificationType.values.length,
              itemBuilder: (context, index) {
                final type = NotificationType.values[index];
                return _buildNotificationCard(type);
              },
            ),
          ),
          
          // زر الحفظ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSettings,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: const Text('حفظ جميع الإعدادات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildNotificationCard(NotificationType type) {
    final settings = _settings[type]!;
    final controller = _controllers[type]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: settings.isEnabled 
              ? AppColors.whatsapp.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (settings.isEnabled ? type.color : Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              type.icon,
              color: settings.isEnabled ? type.color : Colors.grey,
              size: 22,
            ),
          ),
          title: Text(
            type.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: settings.isEnabled ? AppColors.textPrimary : Colors.grey,
            ),
          ),
          subtitle: Text(
            type.description,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
            ),
          ),
          trailing: Switch(
            value: settings.isEnabled,
            onChanged: (value) {
              setState(() {
                _settings[type] = NotificationSettings(
                  isEnabled: value,
                  template: controller.text,
                );
              });
            },
            activeColor: AppColors.whatsapp,
          ),
          children: [
            if (settings.isEnabled) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // نص الرسالة
                    Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: AppColors.textLight),
                        const SizedBox(width: 8),
                        const Text(
                          'نص الرسالة:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: controller,
                        maxLines: 6,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'أدخل نص الرسالة...',
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // المتغيرات المتاحة
                    Text(
                      'المتغيرات: ${type.variables.join(' | ')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // أزرار
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              controller.text = type.defaultTemplate;
                              setState(() {});
                            },
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('استعادة الافتراضي'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _sendTestMessage(type),
                            icon: const Icon(Icons.send, size: 16),
                            label: const Text('اختبار'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: type.color,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// أنواع الإشعارات
enum NotificationType {
  newCustomer(
    key: 'notification_new_customer',
    title: 'إشعار زبون جديد',
    description: 'يُرسل عند إضافة زبون جديد عليه دين',
    icon: Icons.person_add,
    color: Colors.blue,
    variables: ['{اسم_الزبون}', '{المبلغ_الكلي}', '{الدفعة_الأولى}', '{المتبقي}'],
    defaultTemplate: '''عزيزي {اسم_الزبون} 🌟

~ تمت إضافة ديونك إلى نظامنا الإلكتروني ~

📋 تفاصيل الدين:
• المبلغ الإجمالي: {المبلغ_الكلي}
• الدفعة الأولى: {الدفعة_الأولى}
• المبلغ المتبقي: {المتبقي}

شكراً لثقتك بنا 💙''',
  ),
  
  payment(
    key: 'notification_payment',
    title: 'إشعار سداد دفعة',
    description: 'يُرسل عند تسديد دفعة',
    icon: Icons.payments,
    color: Colors.green,
    variables: ['{اسم_الزبون}', '{المبلغ_الأصلي}', '{الدفعة_الحالية}', '{المتبقي}', '{التاريخ}'],
    defaultTemplate: '''📝 تم سداد مبلغ دين جديد

عزيزي {اسم_الزبون}،

• المبلغ الأساسي: {المبلغ_الأصلي}
• الدفعة الحالية: {الدفعة_الحالية}
• المبلغ المتبقي: {المتبقي}
• تاريخ الدفعة: {التاريخ}

شكراً لالتزامك 🙏''',
  ),
  
  fullPayment(
    key: 'notification_full_payment',
    title: 'إشعار إتمام السداد',
    description: 'يُرسل عند سداد كامل المبلغ',
    icon: Icons.celebration,
    color: Colors.amber,
    variables: ['{اسم_الزبون}', '{المبلغ_الكلي}'],
    defaultTemplate: '''عزيزي {اسم_الزبون} 🫂
~ نأمل أن نجدك بخير وراحة ~

✅ تم تسديد كل المبلغ المستحق
💰 المبلغ: {المبلغ_الكلي}

سعداء بالمعاملة معك، نراك مجدداً 📝
شكراً لثقتك بنا 💙''',
  ),
  
  monthlyReminder(
    key: 'notification_monthly_reminder',
    title: 'تذكير شهري',
    description: 'يُرسل كتذكير بموعد القسط',
    icon: Icons.calendar_today,
    color: Colors.orange,
    variables: ['{اسم_الزبون}', '{المبلغ_المستحق}'],
    defaultTemplate: '''عزيزي {اسم_الزبون} 🩵🫂
نأمل أن نجدك بخير

يجب سداد مبلغ إلينا، هنالك مبلغ مستحق:
📝 المبلغ المستحق: {المبلغ_المستحق}

نرجو تسديد المبلغ في أقرب وقت ممكن.
في حال وجود أي استفسار، لا تتردد في التواصل معنا.

💙''',
  );

  final String key;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> variables;
  final String defaultTemplate;

  const NotificationType({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.variables,
    required this.defaultTemplate,
  });
}

/// إعدادات الإشعار
class NotificationSettings {
  final bool isEnabled;
  final String template;

  NotificationSettings({
    required this.isEnabled,
    required this.template,
  });
}

/// تردد التذكير (للتوافق مع الكود القديم)
enum ReminderFrequency {
  daily('يومي'),
  weekly('أسبوعي'),
  monthly('شهري');

  final String label;
  const ReminderFrequency(this.label);
}
