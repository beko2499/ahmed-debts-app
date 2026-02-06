import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/constants.dart';

class WhatsAppService {
  static final WhatsAppService _instance = WhatsAppService._internal();
  factory WhatsAppService() => _instance;
  WhatsAppService._internal();

  static const MethodChannel _channel = MethodChannel('com.ghazali.ahmed_debts/whatsapp');
  
  // URL السيرفر (Railway Production)
  static const String _serverUrl = 'https://ghazali-whatsapp-server-production.up.railway.app';

  /// الحصول على معرف المتجر من Firebase Auth
  String get _storeId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'default';
  }

  /// تحميل URL السيرفر (للتوافق)
  Future<void> loadServerUrl() async {
    // URL ثابت - لا حاجة للتحميل
  }

  /// التحقق من حالة الاتصال
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/status/$_storeId'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'connected': false, 'error': 'Server error'};
    } catch (e) {
      return {'connected': false, 'error': e.toString()};
    }
  }

  /// بدء الاتصال والحصول على كود الربط
  Future<Map<String, dynamic>> connectWithPhoneNumber(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/connect'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'storeId': _storeId,
          'phoneNumber': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 60));
      
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// قطع الاتصال
  Future<bool> disconnect() async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/disconnect/$_storeId'),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// تنسيق المبلغ
  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted دينار';
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  /// استبدال المتغيرات في القالب
  String _processTemplate(String template, Map<String, String> variables) {
    String result = template;
    variables.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }

  /// إرسال رسالة عبر السيرفر (في الخلفية بالكامل)
  Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      debugPrint('📤 WhatsApp: Sending message to $phoneNumber');
      await loadServerUrl();
      
      // إضافة التوقيع
      final box = await Hive.openBox(AppConstants.settingsBox);
      final storeName = box.get(AppConstants.keyOwnerName, defaultValue: 'الغزالي');
      final storePhone = box.get(AppConstants.keyWhatsappNumber, defaultValue: '');
      
      String signature = '\n\n$storeName';
      if (storePhone != null && storePhone.toString().isNotEmpty) {
        signature += '\nللتواصل: $storePhone';
      }
      
      final fullMessage = '$message$signature';

      debugPrint('📤 WhatsApp: Calling $_serverUrl/send for store $_storeId');
      
      // إرسال عبر السيرفر
      final response = await http.post(
        Uri.parse('$_serverUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'storeId': _storeId,
          'phone': phoneNumber,
          'message': fullMessage,
        }),
      ).timeout(const Duration(seconds: 30));
      
      debugPrint('📤 WhatsApp: Response ${response.statusCode}: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ WhatsApp message sent successfully');
          return true;
        }
      }
      
      debugPrint('❌ Server error: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }

  /// إرسال رسائل متعددة
  Future<List<Map<String, dynamic>>> sendBulkMessages(List<Map<String, String>> messages) async {
    try {
      await loadServerUrl();
      
      // إضافة التوقيع لكل رسالة
      final box = await Hive.openBox(AppConstants.settingsBox);
      final storeName = box.get(AppConstants.keyOwnerName, defaultValue: 'الغزالي');
      final storePhone = box.get(AppConstants.keyWhatsappNumber, defaultValue: '');
      
      String signature = '\n\n$storeName';
      if (storePhone != null && storePhone.toString().isNotEmpty) {
        signature += '\nللتواصل: $storePhone';
      }
      
      final messagesWithSignature = messages.map((m) => {
        'phone': m['phone'],
        'message': '${m['message']}$signature',
      }).toList();

      final response = await http.post(
        Uri.parse('$_serverUrl/send-bulk'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'storeId': _storeId,
          'messages': messagesWithSignature,
        }),
      ).timeout(const Duration(minutes: 5));
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return List<Map<String, dynamic>>.from(result['results'] ?? []);
      }
      
      return [];
    } catch (e) {
      debugPrint('Error sending bulk messages: $e');
      return [];
    }
  }

  // --- دوال إرسال الإشعارات ---

  /// 1️⃣ إشعار زبون جديد
  Future<bool> sendNewCustomerNotification({
    required String phoneNumber,
    required String customerName,
    required double totalAmount,
    required double firstPayment,
    required double remainingAmount,
  }) async {
    final box = await Hive.openBox(AppConstants.settingsBox);
    String template = box.get('notification_new_customer_template', 
      defaultValue: '''عزيزي {اسم_الزبون} 🌟
      
تمت إضافة ديونك إلى نظامنا الإلكتروني

تفاصيل الدين:
• المبلغ الإجمالي: {المبلغ_الكلي}
• الدفعة الأولى: {الدفعة_الأولى}
• المبلغ المتبقي: {المتبقي}

شكراً لثقتك بنا 💙''');

    final message = _processTemplate(template, {
      '{اسم_الزبون}': customerName,
      '{المبلغ_الكلي}': _formatCurrency(totalAmount),
      '{الدفعة_الأولى}': _formatCurrency(firstPayment),
      '{المتبقي}': _formatCurrency(remainingAmount),
    });

    return sendMessage(phoneNumber: phoneNumber, message: message);
  }

  /// 2️⃣ إشعار سداد دفعة
  Future<bool> sendPaymentNotification({
    required String phoneNumber,
    required String customerName,
    required double originalAmount,
    required double paidToday,
    required double remainingAmount,
    DateTime? paymentDate,
  }) async {
    final box = await Hive.openBox(AppConstants.settingsBox);
    String template = box.get('notification_payment_template', 
      defaultValue: '''📝 تم سداد دفعة
      
عزيزي {اسم_الزبون}،

• المبلغ الأساسي: {المبلغ_الأصلي}
• الدفعة الحالية: {الدفعة_الحالية}
• المبلغ المتبقي: {المتبقي}
• التاريخ: {التاريخ}

شكراً لالتزامك''');

    final message = _processTemplate(template, {
      '{اسم_الزبون}': customerName,
      '{المبلغ_الأصلي}': _formatCurrency(originalAmount),
      '{الدفعة_الحالية}': _formatCurrency(paidToday),
      '{المتبقي}': _formatCurrency(remainingAmount),
      '{التاريخ}': _formatDate(paymentDate ?? DateTime.now()),
    });

    return sendMessage(phoneNumber: phoneNumber, message: message);
  }

  /// 3️⃣ تذكير شهري/عام
  Future<bool> sendMonthlyReminder({
    required String phoneNumber,
    required String customerName,
    required double dueAmount,
  }) async {
    final box = await Hive.openBox(AppConstants.settingsBox);
    String template = box.get('notification_monthly_reminder_template', 
      defaultValue: '''عزيزي {اسم_الزبون}
      
نود تذكيرك بالمبلغ المستحق: {المبلغ_المستحق}

نرجو السداد في أقرب وقت.''');

    final message = _processTemplate(template, {
      '{اسم_الزبون}': customerName,
      '{المبلغ_المستحق}': _formatCurrency(dueAmount),
    });

    return sendMessage(phoneNumber: phoneNumber, message: message);
  }

  /// 4️⃣ إشعار إتمام السداد
  Future<bool> sendFullPaymentNotification({
    required String phoneNumber,
    required String customerName,
    required double totalPaid,
  }) async {
    final box = await Hive.openBox(AppConstants.settingsBox);
    String template = box.get('notification_full_payment_template', 
      defaultValue: '''عزيزي {اسم_الزبون}
      
✅ تم تسديد كامل المبلغ المستحق: {المبلغ_الكلي}

شكراً جزيلاً لثقتك بنا.''');

    final message = _processTemplate(template, {
      '{اسم_الزبون}': customerName,
      '{المبلغ_الكلي}': _formatCurrency(totalPaid),
    });

    return sendMessage(phoneNumber: phoneNumber, message: message);
  }

  /// 5️⃣ إشعار زيادة الدين
  Future<bool> sendDebtIncreaseNotification({
    required String phoneNumber,
    required String customerName,
    required double addedAmount,
    required double newTotal,
  }) async {
    final box = await Hive.openBox(AppConstants.settingsBox);
    String template = box.get('notification_debt_increase_template', 
      defaultValue: '''عزيزي {اسم_الزبون}

📝 تم تسجيل مبلغ جديد على حسابك

• المبلغ المضاف: {المبلغ_المضاف}
• إجمالي المستحق: {الإجمالي_الجديد}

شكراً لتعاملك معنا.''');

    final message = _processTemplate(template, {
      '{اسم_الزبون}': customerName,
      '{المبلغ_المضاف}': _formatCurrency(addedAmount),
      '{الإجمالي_الجديد}': _formatCurrency(newTotal),
    });

    return sendMessage(phoneNumber: phoneNumber, message: message);
  }

  // --- Accessibility Methods (Fallback) ---
  
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod('isAccessibilityEnabled');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Error opening accessibility settings: $e');
    }
  }
}
