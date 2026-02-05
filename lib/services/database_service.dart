import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../config/constants.dart';

/// خدمة قاعدة البيانات المحلية
class DatabaseService extends ChangeNotifier {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final List<Customer> _customers = [];
  final List<Transaction> _transactions = [];

  List<Customer> get customers => _customers;
  List<Transaction> get transactions => _transactions;

  /// إجمالي الديون (الموجبة = لنا على الزبائن)
  double get totalDebt {
    return _customers.fold(0.0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0));
  }

  /// إجمالي ما لنا على الزبائن
  double get totalOwed {
    return _customers.fold(0.0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0));
  }

  /// عدد الزبائن المدينين
  int get debtorCount {
    return _customers.where((c) => c.balance > 0).length;
  }

  /// تهيئة قاعدة البيانات
  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    await Hive.openBox(AppConstants.settingsBox);

    _isInitialized = true;
    notifyListeners();
  }

  /// إضافة زبون جديد
  Future<void> addCustomer(Customer customer) async {
    _customers.add(customer);
    notifyListeners();
  }

  /// تحديث زبون
  Future<void> updateCustomer(Customer customer) async {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
    }
  }

  /// حذف زبون
  Future<void> deleteCustomer(String customerId) async {
    _customers.removeWhere((c) => c.id == customerId);
    // حذف معاملات الزبون أيضاً
    _transactions.removeWhere((t) => t.customerId == customerId);
    notifyListeners();
  }

  /// الحصول على زبون بالـ ID
  Customer? getCustomer(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// إضافة معاملة جديدة
  Future<void> addTransaction(Transaction transaction) async {
    _transactions.insert(0, transaction);

    // تحديث رصيد الزبون
    final customer = getCustomer(transaction.customerId);
    if (customer != null) {
      double newBalance;
      if (transaction.type == TransactionType.debt) {
        newBalance = customer.balance + transaction.amount;
      } else {
        newBalance = customer.balance - transaction.amount;
      }
      
      await updateCustomer(customer.copyWith(
        balance: newBalance,
        lastTransactionAt: transaction.date,
      ));
    }

    notifyListeners();
  }

  /// الحصول على معاملات زبون معين
  List<Transaction> getCustomerTransactions(String customerId) {
    return _transactions
        .where((t) => t.customerId == customerId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// آخر المعاملات
  List<Transaction> get recentTransactions {
    final sorted = List<Transaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(10).toList();
  }

  /// البحث عن زبائن
  List<Customer> searchCustomers(String query) {
    if (query.isEmpty) return _customers;
    return _customers.where((c) {
      return c.name.contains(query) || c.phone.contains(query);
    }).toList();
  }

  /// تصدير البيانات للنسخ الاحتياطي
  Map<String, dynamic> exportData() {
    return {
      'customers': _customers.map((c) => c.toJson()).toList(),
      'transactions': _transactions.map((t) => t.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// استيراد البيانات من النسخة الاحتياطية
  Future<void> importData(Map<String, dynamic> data) async {
    // استيراد الزبائن
    final customersData = data['customers'] as List<dynamic>?;
    if (customersData != null) {
      for (final cData in customersData) {
        final customer = Customer.fromJson(cData as Map<String, dynamic>);
        await addCustomer(customer);
      }
    }

    // استيراد المعاملات
    final transactionsData = data['transactions'] as List<dynamic>?;
    if (transactionsData != null) {
      for (final tData in transactionsData) {
        final transaction = Transaction.fromJson(tData as Map<String, dynamic>);
        _transactions.add(transaction);
      }
    }

    notifyListeners();
  }

  /// مسح جميع البيانات
  Future<void> clearAll() async {
    _customers.clear();
    _transactions.clear();
    notifyListeners();
  }
}
