import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// بطاقة الزبون في القائمة
class CustomerCard extends StatelessWidget {
  final String name;
  final double balance;
  final String status; // paid, pending, overdue, credit
  final String? imageUrl;
  final VoidCallback? onTap;

  const CustomerCard({
    super.key,
    required this.name,
    required this.balance,
    required this.status,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // التحقق من وجود الصورة المحلية
    final hasLocalImage = imageUrl != null && 
                          imageUrl!.isNotEmpty && 
                          File(imageUrl!).existsSync();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // صورة الزبون
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                  ),
                ],
                image: hasLocalImage
                    ? DecorationImage(
                        image: FileImage(File(imageUrl!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !hasLocalImage
                  ? Icon(
                      Icons.person,
                      color: Colors.grey.shade400,
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // معلومات الزبون
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(balance.abs()),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: balance < 0 ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // حالة الزبون
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    _statusIcon,
                    size: 18,
                    color: _statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'overdue':
        return AppColors.error;
      case 'credit':
        return Colors.blue; // له رصيد
      default:
        return AppColors.textLight;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'overdue':
        return Icons.warning;
      case 'credit':
        return Icons.account_balance_wallet; // له رصيد
      default:
        return Icons.help;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'paid':
        return 'مسدد';
      case 'pending':
        return 'قيد الانتظار';
      case 'overdue':
        return 'متأخر';
      case 'credit':
        return 'له رصيد';
      default:
        return '';
    }
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted IQD';
  }
}
