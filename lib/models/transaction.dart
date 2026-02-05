import '../config/constants.dart';

/// نموذج القيد المالي (دين أو تسديد)
class Transaction {
  final String id;
  final String customerId;
  final TransactionType type;
  final double amount;
  final DateTime date;
  String? notes;
  final DateTime createdAt;
  String? customerName; // للعرض في آخر الحركات

  Transaction({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.date,
    this.notes,
    DateTime? createdAt,
    this.customerName,
  }) : createdAt = createdAt ?? DateTime.now();

  /// هل هو دين (زيادة على الزبون)
  bool get isDebt => type == TransactionType.debt;

  /// هل هو تسديد (نقص من الزبون)
  bool get isPayment => type == TransactionType.payment;

  /// تنسيق المبلغ للعرض
  String get formattedAmount {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final prefix = isDebt ? '+' : '-';
    return '$prefix $formatted ${AppConstants.currencySymbol}';
  }

  /// تنسيق التاريخ للعرض
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDay = DateTime(date.year, date.month, date.day);
    
    if (transactionDay == today) {
      return 'اليوم، ${_formatTime(date)}';
    } else if (transactionDay == today.subtract(const Duration(days: 1))) {
      return 'أمس، ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  /// وصف موجز للمعاملة
  String get description {
    if (isDebt) {
      return notes ?? 'بيع بالدين';
    } else {
      return 'تسديد${customerName != null ? ' من $customerName' : ''}';
    }
  }

  /// تحويل لـ Map
  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'type': type.name,
    'amount': amount,
    'date': date.toIso8601String(),
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'customerName': customerName,
  };

  /// إنشاء من Map
  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    customerId: json['customerId'] as String,
    type: TransactionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => TransactionType.debt,
    ),
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    customerName: json['customerName'] as String?,
  );
}
