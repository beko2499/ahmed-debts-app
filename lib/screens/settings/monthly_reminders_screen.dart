import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/monthly_reminder_service.dart';
import '../../services/whatsapp_notification_service.dart';

/// صفحة إرسال التذكيرات الشهرية
class MonthlyRemindersScreen extends StatefulWidget {
  const MonthlyRemindersScreen({super.key});

  @override
  State<MonthlyRemindersScreen> createState() => _MonthlyRemindersScreenState();
}

class _MonthlyRemindersScreenState extends State<MonthlyRemindersScreen> {
  final MonthlyReminderService _reminderService = MonthlyReminderService();
  List<Map<String, dynamic>> _debtors = [];
  Set<String> _selectedIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDebtors();
  }

  void _loadDebtors() {
    setState(() {
      _debtors = _reminderService.getDebtors();
      _selectedIds = _debtors.map((d) => d['id'].toString()).toSet(); // تحديد الكل افتراضياً
    });
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted د.ع';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _sendReminders() async {
    if (_selectedIds.isEmpty) {
      AppUtils.showError(context, 'الرجاء تحديد زبون واحد على الأقل');
      return;
    }

    setState(() => _isLoading = true);

    final selectedDebtors = _debtors.where((d) => _selectedIds.contains(d['id'].toString())).toList();
    
    for (var i = 0; i < selectedDebtors.length; i++) {
      final customer = selectedDebtors[i];
      
      // عرض dialog للتأكيد قبل كل إرسال
      if (mounted) {
        final shouldSend = await _showConfirmDialog(customer, i + 1, selectedDebtors.length);
        
        if (shouldSend == true) {
          await _reminderService.sendReminderToCustomer(customer);
          // انتظار قليلاً بين الرسائل
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    setState(() => _isLoading = false);

    if (mounted) {
      AppUtils.showSuccess(context, 'تم إرسال التذكيرات لـ ${selectedDebtors.length} زبون');
    }
  }

  Future<bool?> _showConfirmDialog(Map<String, dynamic> customer, int current, int total) {
    final name = customer['name']?.toString() ?? '';
    final dueAmount = _reminderService.getMonthlyPayment(customer);
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.send, color: AppColors.whatsapp),
            const SizedBox(width: 8),
            Text('إرسال تذكير ($current/$total)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الزبون: $name', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('المبلغ المستحق: ${_formatCurrency(dueAmount)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تخطي'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send),
            label: const Text('إرسال'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.whatsapp,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التذكيرات الشهرية'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // تحديد/إلغاء تحديد الكل
          IconButton(
            onPressed: () {
              setState(() {
                if (_selectedIds.length == _debtors.length) {
                  _selectedIds.clear();
                } else {
                  _selectedIds = _debtors.map((d) => d['id'].toString()).toSet();
                }
              });
            },
            icon: Icon(
              _selectedIds.length == _debtors.length 
                  ? Icons.deselect 
                  : Icons.select_all,
            ),
            tooltip: _selectedIds.length == _debtors.length ? 'إلغاء تحديد الكل' : 'تحديد الكل',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.notifications_active, size: 48, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(height: 12),
                Text(
                  'إرسال تذكيرات للمديونين',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_debtors.length} زبون لديهم ديون مستحقة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // قائمة الزبائن
          Expanded(
            child: _debtors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: AppColors.success),
                        const SizedBox(height: 16),
                        const Text(
                          'لا يوجد زبائن مديونين حالياً',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _debtors.length,
                    itemBuilder: (context, index) {
                      final customer = _debtors[index];
                      final id = customer['id'].toString();
                      final isSelected = _selectedIds.contains(id);
                      final name = customer['name']?.toString() ?? '';
                      final phone = customer['phone']?.toString() ?? '';
                      final balance = (customer['balance'] as num?)?.toDouble() ?? 0;
                      final monthlyPayment = _reminderService.getMonthlyPayment(customer);
                      final daysOverdue = _reminderService.getDaysOverdue(customer);
                      final nextPaymentDate = _reminderService.getNextPaymentDate(customer);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(id);
                              } else {
                                _selectedIds.add(id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Checkbox
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedIds.add(id);
                                      } else {
                                        _selectedIds.remove(id);
                                      }
                                    });
                                  },
                                  activeColor: AppColors.primary,
                                ),
                                // معلومات الزبون
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (daysOverdue > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.error.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'متأخر $daysOverdue يوم',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.error,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        phone,
                                        style: TextStyle(color: AppColors.textLight, fontSize: 12),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildInfoChip(
                                            'الإجمالي',
                                            _formatCurrency(balance),
                                            AppColors.error,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildInfoChip(
                                            'المستحق',
                                            _formatCurrency(monthlyPayment),
                                            AppColors.warning,
                                          ),
                                        ],
                                      ),
                                      if (nextPaymentDate != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'الدفعة القادمة: ${_formatDate(nextPaymentDate)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // زر إرسال فردي
                                IconButton(
                                  onPressed: () async {
                                    await _reminderService.sendReminderToCustomer(customer);
                                  },
                                  icon: Icon(Icons.send, color: AppColors.whatsapp),
                                  tooltip: 'إرسال تذكير',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      // زر إرسال للمحددين
      bottomNavigationBar: _debtors.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendReminders,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isLoading
                        ? 'جاري الإرسال...'
                        : 'إرسال تذكيرات (${_selectedIds.length})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.whatsapp,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
