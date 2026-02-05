import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../config/constants.dart';
import 'whatsapp_service.dart';

/// خدمة التذكيرات الشهرية
class MonthlyReminderService {
  static final MonthlyReminderService _instance = MonthlyReminderService._internal();
  factory MonthlyReminderService() => _instance;
  MonthlyReminderService._internal();

  final WhatsAppService _whatsappService = WhatsAppService();

  /// الحصول على قائمة الزبائن المديونين
  List<Map<String, dynamic>> getDebtors() {
    try {
      final customersBox = Hive.box(AppConstants.customersBox);
      final customers = customersBox.values
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((c) {
            final balance = (c['balance'] as num?)?.toDouble() ?? 0;
            return balance > 0;
          })
          .toList();
      return customers;
    } catch (e) {
      debugPrint('Error getting debtors: $e');
      return [];
    }
  }

  /// الحصول على الدفعة الشهرية لزبون
  double getMonthlyPayment(Map<String, dynamic> customer) {
    final balance = (customer['balance'] as num?)?.toDouble() ?? 0;
    final installmentMonths = (customer['installmentMonths'] as num?)?.toInt() ?? 12;
    final paidInstallments = (customer['paidInstallmentsCount'] as num?)?.toInt() ?? 0;
    final remainingInstallments = installmentMonths - paidInstallments;
    
    if (remainingInstallments <= 0) return balance;
    return balance / remainingInstallments;
  }

  /// إرسال تذكير لزبون واحد
  Future<bool> sendReminderToCustomer(Map<String, dynamic> customer) async {
    final phone = customer['phone']?.toString() ?? '';
    final name = customer['name']?.toString() ?? '';
    final dueAmount = getMonthlyPayment(customer);

    if (phone.isEmpty) return false;

    return _whatsappService.sendMonthlyReminder(
      phoneNumber: phone,
      customerName: name,
      dueAmount: dueAmount,
    );
  }

  /// فتح واتساب لإرسال تذكير (لن يرسل تلقائياً)
  Future<void> prepareReminder(Map<String, dynamic> customer) async {
    await sendReminderToCustomer(customer);
  }

  /// التحقق إذا كان اليوم هو أول الشهر
  bool isFirstDayOfMonth() {
    return DateTime.now().day == 1;
  }

  /// الحصول على عدد أيام التأخير عن الدفعة
  int getDaysOverdue(Map<String, dynamic> customer) {
    try {
      final startDateStr = customer['installmentStartDate'] as String?;
      if (startDateStr == null) return 0;

      final startDate = DateTime.parse(startDateStr);
      final paidInstallments = (customer['paidInstallmentsCount'] as num?)?.toInt() ?? 0;
      
      // تاريخ الدفعة المتوقعة = تاريخ البدء + (عدد الأقساط المدفوعة + 1) * 30 يوم
      final expectedPaymentDate = startDate.add(Duration(days: 30 * (paidInstallments + 1)));
      final now = DateTime.now();
      
      if (now.isAfter(expectedPaymentDate)) {
        return now.difference(expectedPaymentDate).inDays;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// تاريخ الدفعة القادمة
  DateTime? getNextPaymentDate(Map<String, dynamic> customer) {
    try {
      final startDateStr = customer['installmentStartDate'] as String?;
      if (startDateStr == null) return null;

      final startDate = DateTime.parse(startDateStr);
      final paidInstallments = (customer['paidInstallmentsCount'] as num?)?.toInt() ?? 0;
      
      return startDate.add(Duration(days: 30 * (paidInstallments + 1)));
    } catch (e) {
      return null;
    }
  }
}
