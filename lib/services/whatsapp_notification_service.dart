import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';
import '../config/constants.dart';

/// خدمة إشعارات الواتساب
class WhatsAppNotificationService {
  static final WhatsAppNotificationService _instance = WhatsAppNotificationService._internal();
  factory WhatsAppNotificationService() => _instance;
  WhatsAppNotificationService._internal();

  /// تنسيق المبلغ بالدينار العراقي
  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted دينار';
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// الحصول على اسم المتجر من الإعدادات
  String _getStoreName() {
    try {
      final box = Hive.box(AppConstants.settingsBox);
      return box.get(AppConstants.keyOwnerName, defaultValue: 'الغزالي');
    } catch (e) {
      return 'الغزالي';
    }
  }

  /// 1️⃣ رسالة إضافة زبون جديد / دين جديد
  String getNewDebtMessage({
    required String customerName,
    required double totalAmount,
    required double firstPayment,
    required double remainingAmount,
  }) {
    final storeName = _getStoreName();
    return '''عزيزي $customerName 🌟

~ تمت إضافة ديونك إلى نظامنا الإلكتروني ~

📋 تفاصيل الدين:
• المبلغ الإجمالي: ${_formatCurrency(totalAmount)}
• الدفعة الأولى: ${_formatCurrency(firstPayment)}
• المبلغ المتبقي: ${_formatCurrency(remainingAmount)}

شكراً لثقتك بنا 💙
$storeName''';
  }

  /// 2️⃣ رسالة تسديد دفعة
  String getPaymentMessage({
    required String customerName,
    required double originalAmount,
    required double paidToday,
    required double remainingAmount,
    required DateTime paymentDate,
    required DateTime nextPaymentDate,
  }) {
    return '''📝 تم سداد مبلغ دين جديد

عزيزي $customerName،

• المبلغ الأساسي: ${_formatCurrency(originalAmount)}
• الدفعة الحالية: ${_formatCurrency(paidToday)}
• المبلغ المتبقي: ${_formatCurrency(remainingAmount)}
• تاريخ الدفعة: ${_formatDate(paymentDate)}
• تاريخ الدفعة القادمة: ${_formatDate(nextPaymentDate)}

شكراً لالتزامك 🙏''';
  }

  /// 3️⃣ رسالة التذكير الشهري
  String getMonthlyReminderMessage({
    required String customerName,
    required double dueAmount,
  }) {
    final storeName = _getStoreName();
    return '''عزيزي $customerName 🩵🫂
نأمل أن نجدك بخير

يجب سداد مبلغ إلينا، هنالك مبلغ مستحق:
📝 المبلغ المستحق: ${_formatCurrency(dueAmount)}

نرجو تسديد المبلغ في أقرب وقت ممكن.
في حال وجود أي استفسار، لا تتردد في التواصل معنا.

$storeName 💙''';
  }

  /// 4️⃣ رسالة إتمام سداد كل الدين
  String getFullPaymentMessage({
    required String customerName,
    required double totalPaid,
  }) {
    final storeName = _getStoreName();
    return '''عزيزي $customerName 🫂
~ نأمل أن نجدك بخير وراحة ~

✅ تم تسديد كل المبلغ المستحق لنا ($storeName)
💰 المبلغ: ${_formatCurrency(totalPaid)}

سعداء بالمعاملة معك، نراك مجدداً 📝
شكراً لثقتك بنا 💙''';
  }

  /// إرسال رسالة واتساب
  Future<bool> sendWhatsAppMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // تنظيف رقم الهاتف
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // إضافة كود العراق إذا لم يكن موجوداً
      if (!cleanNumber.startsWith('+') && !cleanNumber.startsWith('964')) {
        if (cleanNumber.startsWith('0')) {
          cleanNumber = '964${cleanNumber.substring(1)}';
        } else {
          cleanNumber = '964$cleanNumber';
        }
      }

      // إنشاء رابط الواتساب
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
      
      final uri = Uri.parse(whatsappUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        debugPrint('Cannot launch WhatsApp URL');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending WhatsApp message: $e');
      return false;
    }
  }

  /// إرسال إشعار زبون جديد
  Future<bool> sendNewCustomerNotification({
    required String phoneNumber,
    required String customerName,
    required double totalAmount,
    required double firstPayment,
    required double remainingAmount,
  }) async {
    final message = getNewDebtMessage(
      customerName: customerName,
      totalAmount: totalAmount,
      firstPayment: firstPayment,
      remainingAmount: remainingAmount,
    );
    return sendWhatsAppMessage(phoneNumber: phoneNumber, message: message);
  }

  /// إرسال إشعار دفعة
  Future<bool> sendPaymentNotification({
    required String phoneNumber,
    required String customerName,
    required double originalAmount,
    required double paidToday,
    required double remainingAmount,
    DateTime? paymentDate,
    DateTime? nextPaymentDate,
  }) async {
    final message = getPaymentMessage(
      customerName: customerName,
      originalAmount: originalAmount,
      paidToday: paidToday,
      remainingAmount: remainingAmount,
      paymentDate: paymentDate ?? DateTime.now(),
      nextPaymentDate: nextPaymentDate ?? DateTime.now().add(const Duration(days: 30)),
    );
    return sendWhatsAppMessage(phoneNumber: phoneNumber, message: message);
  }

  /// إرسال تذكير شهري
  Future<bool> sendMonthlyReminder({
    required String phoneNumber,
    required String customerName,
    required double dueAmount,
  }) async {
    final message = getMonthlyReminderMessage(
      customerName: customerName,
      dueAmount: dueAmount,
    );
    return sendWhatsAppMessage(phoneNumber: phoneNumber, message: message);
  }

  /// إرسال إشعار إتمام السداد
  Future<bool> sendFullPaymentNotification({
    required String phoneNumber,
    required String customerName,
    required double totalPaid,
  }) async {
    final message = getFullPaymentMessage(
      customerName: customerName,
      totalPaid: totalPaid,
    );
    return sendWhatsAppMessage(phoneNumber: phoneNumber, message: message);
  }
}
