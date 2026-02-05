import '../config/constants.dart';

/// نموذج الزبون
class Customer {
  final String id;
  String name;
  String phone;
  String? address;
  String? imageUrl;
  double balance; // موجب = لنا عليه، سالب = له علينا
  DateTime createdAt;
  DateTime? lastTransactionAt;
  String? notes;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.imageUrl,
    this.balance = 0,
    DateTime? createdAt,
    this.lastTransactionAt,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now();

  /// حالة الزبون بناءً على الرصيد
  CustomerStatus get status {
    if (balance <= 0) {
      return CustomerStatus.paid;
    }
    // إذا مر أكثر من 30 يوم على آخر معاملة
    if (lastTransactionAt != null) {
      final daysSinceLastTransaction = 
          DateTime.now().difference(lastTransactionAt!).inDays;
      if (daysSinceLastTransaction > 30) {
        return CustomerStatus.overdue;
      }
    }
    return CustomerStatus.pending;
  }

  /// تنسيق الرصيد للعرض
  String get formattedBalance {
    final absBalance = balance.abs();
    final formatted = _formatNumber(absBalance);
    return '$formatted ${AppConstants.currencySymbol}';
  }

  /// تنسيق الأرقام بالفواصل
  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// نسخة محدثة من الزبون
  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? imageUrl,
    double? balance,
    DateTime? lastTransactionAt,
    String? notes,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      balance: balance ?? this.balance,
      createdAt: createdAt,
      lastTransactionAt: lastTransactionAt ?? this.lastTransactionAt,
      notes: notes ?? this.notes,
    );
  }

  /// تحويل لـ Map للتصدير
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'imageUrl': imageUrl,
    'balance': balance,
    'createdAt': createdAt.toIso8601String(),
    'lastTransactionAt': lastTransactionAt?.toIso8601String(),
    'notes': notes,
  };

  /// إنشاء من Map
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    address: json['address'] as String?,
    imageUrl: json['imageUrl'] as String?,
    balance: (json['balance'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastTransactionAt: json['lastTransactionAt'] != null 
        ? DateTime.parse(json['lastTransactionAt'] as String)
        : null,
    notes: json['notes'] as String?,
  );
}
