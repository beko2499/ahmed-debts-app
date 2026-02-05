import 'package:flutter/material.dart';
import '../config/theme.dart';

/// عنصر المعاملة المالية في القائمة
class TransactionItem extends StatelessWidget {
  final String type; // payment, debt
  final String title;
  final String subtitle;
  final double amount;
  final bool isPayment;

  const TransactionItem({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.isPayment = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // أيقونة
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPayment
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              isPayment ? Icons.arrow_downward : Icons.receipt_long,
              size: 20,
              color: isPayment ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),

          // المعلومات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),

          // المبلغ
          if (amount > 0)
            Text(
              '${isPayment ? '+' : ''} ${_formatAmount(amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPayment ? AppColors.success : AppColors.textPrimary,
              ),
            )
          else
            Text(
              '--',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return formatted;
  }
}
