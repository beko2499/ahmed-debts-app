import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/whatsapp_service.dart';
import '../../services/backup_service.dart';
import '../../utils/currency_input_formatter.dart';

/// شاشة إضافة قيد جديد (دين أو تسديد) - مُحسّنة
class AddTransactionScreen extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final bool? isPayment;

  const AddTransactionScreen({
    super.key, 
    this.customerId,
    this.customerName,
    this.isPayment,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  late bool _isPayment;
  String? _selectedCustomerId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  double _customerBalance = 0;

  // قائمة الزبائن (للحالة القديمة فقط)
  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.customerId;
    _isPayment = widget.isPayment ?? false;
    _loadCustomers();
    _loadCustomerBalance();
  }

  void _loadCustomers() {
    final customersBox = Hive.box(AppConstants.customersBox);
    final customers = customersBox.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    setState(() {
      _customers = customers;
    });
  }

  void _loadCustomerBalance() {
    if (_selectedCustomerId != null) {
      final customersBox = Hive.box(AppConstants.customersBox);
      final customerData = customersBox.get(_selectedCustomerId);
      if (customerData != null) {
        final customer = Map<String, dynamic>.from(customerData);
        setState(() {
          _customerBalance = (customer['balance'] as num?)?.toDouble() ?? 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      AppUtils.showError(context, 'الرجاء اختيار الزبون');
      return;
    }

    final amount = parseFormattedNumber(_amountController.text);
    
    // التحقق من عدم سداد أكثر من المبلغ المطلوب
    if (_isPayment && amount > _customerBalance) {
      AppUtils.showError(context, 'لا يمكن سداد أكثر من المبلغ المستحق (${_formatCurrency(_customerBalance)})');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final transactionId = const Uuid().v4();
      final transactionType = _isPayment ? TransactionType.payment : TransactionType.debt;
      
      final newTransaction = {
        'id': transactionId,
        'customerId': _selectedCustomerId,
        'type': transactionType.name,
        'amount': amount,
        'date': _selectedDate.toIso8601String(),
        'notes': _notesController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      // حفظ القيد في Hive
      final transactionsBox = Hive.box(AppConstants.transactionsBox);
      await transactionsBox.put(transactionId, newTransaction);

      // تحديث رصيد الزبون
      final customersBox = Hive.box(AppConstants.customersBox);
      final customerData = customersBox.get(_selectedCustomerId);
      if (customerData != null) {
        final customer = Map<String, dynamic>.from(customerData);
        double currentBalance = (customer['balance'] as num?)?.toDouble() ?? 0;
        double totalPaid = (customer['totalPaid'] as num?)?.toDouble() ?? 0;
        int paidInstallmentsCount = (customer['paidInstallmentsCount'] as num?)?.toInt() ?? 0;
        double currentInstallmentPaid = (customer['currentInstallmentPaid'] as num?)?.toDouble() ?? 0;
        final installmentMonths = (customer['installmentMonths'] as num?)?.toInt() ?? 12;
        
        // قائمة مبالغ الأقساط المدفوعة
        List<double> paidInstallmentAmounts = (customer['paidInstallmentAmounts'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble()).toList() ?? [];
        
        // تحميل الأقساط الذكية المحفوظة (من إنشاء الزبون)
        List<double> smartInstallments = (customer['smartInstallments'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble()).toList() ?? [];
        
        if (_isPayment) {
          // تسديد
          currentBalance -= amount;
          totalPaid += amount;
          
          // استخدام القسط المحفوظ من smartInstallments بدلاً من إعادة الحساب
          final remainingInstallments = installmentMonths - paidInstallmentsCount;
          double currentMonthlyPayment;
          
          if (smartInstallments.isNotEmpty && paidInstallmentsCount < smartInstallments.length) {
            // استخدام القسط المخطط له من الجدول الأصلي
            currentMonthlyPayment = smartInstallments[paidInstallmentsCount];
          } else if (remainingInstallments > 0) {
            // إذا لم تكن الأقساط محفوظة، نحسبها (للزبائن القدامى)
            currentMonthlyPayment = (currentBalance + amount) / remainingInstallments;
          } else {
            currentMonthlyPayment = amount;
          }
          
          // إضافة المبلغ للقسط الحالي
          currentInstallmentPaid += amount;
          
          // التحقق من اكتمال القسط الحالي (مع هامش تسامح للأرقام العشرية)
          const tolerance = 1.0; // هامش 1 دينار للتقريب
          while ((currentInstallmentPaid + tolerance) >= currentMonthlyPayment && paidInstallmentsCount < installmentMonths) {
            // حفظ قيمة القسط الأصلي المخطط وليس المبلغ المدفوع فعلياً
            paidInstallmentAmounts.add(currentMonthlyPayment);
            
            currentInstallmentPaid -= currentMonthlyPayment;
            if (currentInstallmentPaid < 0 && currentInstallmentPaid > -tolerance) {
              currentInstallmentPaid = 0; // تصفير القيم السالبة الصغيرة
            }
            paidInstallmentsCount++;
            
            // تحديث القسط التالي من الجدول الأصلي
            if (smartInstallments.isNotEmpty && paidInstallmentsCount < smartInstallments.length) {
              currentMonthlyPayment = smartInstallments[paidInstallmentsCount];
            }
          }
          
          // حفظ قائمة الأقساط المدفوعة
          customer['paidInstallmentAmounts'] = paidInstallmentAmounts;
        } else {
          // دين جديد - إعادة توزيع على الأقساط المتبقية
          currentBalance += amount;
          
          // تحديث الدين الأصلي ليعكس المبلغ الجديد الموزع
          final remainingInstallments = installmentMonths - paidInstallmentsCount;
          
          if (remainingInstallments > 0) {
            // هناك أقساط متبقية - توزيع الدين الجديد عليها
            customer['originalDebt'] = currentBalance + totalPaid;
            
            // إعادة حساب الأقساط المتبقية لتشمل الدين الجديد
            const roundingUnit = 250.0;
            final newOriginalDebt = currentBalance + totalPaid;
            
            // إنشاء جدول أقساط جديد كامل
            if (installmentMonths > 0 && newOriginalDebt > 0) {
              final basePayment = (newOriginalDebt / installmentMonths / roundingUnit).floor() * roundingUnit;
              final highPayment = basePayment + roundingUnit;
              final highPaymentMonths = ((newOriginalDebt - installmentMonths * basePayment) / roundingUnit).round();
              final lowPaymentMonths = installmentMonths - highPaymentMonths;
              
              List<double> newInstallments = [];
              for (int i = 0; i < lowPaymentMonths; i++) {
                newInstallments.add(basePayment.toDouble());
              }
              for (int i = 0; i < highPaymentMonths; i++) {
                newInstallments.add(highPayment.toDouble());
              }
              customer['smartInstallments'] = newInstallments;
            }
          } else {
            // تم سداد جميع الأقساط - بدء جدول أقساط جديد
            customer['originalDebt'] = currentBalance;
            customer['installmentStartDate'] = DateTime.now().toIso8601String();
            paidInstallmentsCount = 0;
            currentInstallmentPaid = 0;
            totalPaid = 0;
            paidInstallmentAmounts = [];
            customer['paidInstallmentAmounts'] = paidInstallmentAmounts;
            
            // إنشاء جدول أقساط جديد للمبلغ المضاف
            // حساب الأقساط الذكية للرصيد الجديد
            const roundingUnit = 250.0;
            if (installmentMonths > 0 && currentBalance > 0) {
              final basePayment = (currentBalance / installmentMonths / roundingUnit).floor() * roundingUnit;
              final highPayment = basePayment + roundingUnit;
              final highPaymentMonths = ((currentBalance - installmentMonths * basePayment) / roundingUnit).round();
              final lowPaymentMonths = installmentMonths - highPaymentMonths;
              
              List<double> newInstallments = [];
              for (int i = 0; i < lowPaymentMonths; i++) {
                newInstallments.add(basePayment.toDouble());
              }
              for (int i = 0; i < highPaymentMonths; i++) {
                newInstallments.add(highPayment.toDouble());
              }
              customer['smartInstallments'] = newInstallments;
            }
          }
        }
        
        // تحديث حالة الزبون
        String status = 'completed';
        if (currentBalance > 0) {
          status = 'active'; // عليه دين
        } else if (currentBalance < 0) {
          status = 'active'; // له رصيد (دفع زيادة) - نعتبره نشط
        }
        // إذا كان الرصيد = 0، يبقى 'paid'
        
        customer['balance'] = currentBalance;
        customer['totalPaid'] = totalPaid;
        customer['paidInstallmentsCount'] = paidInstallmentsCount;
        customer['currentInstallmentPaid'] = currentInstallmentPaid;
        customer['status'] = status;
        await customersBox.put(_selectedCustomerId, customer);
        
        // إرسال إشعار واتساب تلقائياً عند السداد
        if (_isPayment && mounted && _customerBalance > 0) {
          try {
             final customer = _customers.firstWhere((c) => c['id'] == _selectedCustomerId);
             final phone = customer['phone']?.toString();
             
             if (phone != null && phone.isNotEmpty) {
               final remainingAfterPayment = _customerBalance - amount;
               
               if (remainingAfterPayment <= 0) {
                 // إتمام السداد بالكامل
                 WhatsAppService().sendFullPaymentNotification(
                   phoneNumber: phone,
                   customerName: customer['name'] ?? '',
                   totalPaid: _customerBalance, // المبلغ الكلي الذي تم سداده
                 );
               } else {
                 // سداد جزئي
                 final installmentMonths = (customer['installmentMonths'] as num?)?.toInt() ?? 12;
                 final paidCount = (customer['paidInstallmentsCount'] as num?)?.toInt() ?? 0;
                 final remainingMonths = installmentMonths - paidCount;
                 WhatsAppService().sendPaymentNotification(
                   phoneNumber: phone,
                   customerName: customer['name'] ?? '',
                   originalAmount: _customerBalance, // المبلغ الكلي قبل الدفعة
                   paidToday: amount,
                   remainingAmount: remainingAfterPayment,
                   paymentDate: _selectedDate,
                   remainingMonths: remainingMonths > 0 ? remainingMonths : 0,
                 );
               }
             }
          } catch (e) {
             debugPrint('Error sending notification: $e');
          }
        } else if (!_isPayment && mounted) {
          // إرسال إشعار عند زيادة الدين
          try {
             final customer = _customers.firstWhere((c) => c['id'] == _selectedCustomerId);
             final phone = customer['phone']?.toString();
             
             if (phone != null && phone.isNotEmpty) {
               final newTotal = _customerBalance + amount;
               WhatsAppService().sendDebtIncreaseNotification(
                 phoneNumber: phone,
                 customerName: customer['name'] ?? '',
                 addedAmount: amount,
                 newTotal: newTotal,
               );
             }
          } catch (e) {
             debugPrint('Error sending debt increase notification: $e');
          }
        }
        
        // النسخ الاحتياطي
        BackupService.autoBackup();
      } // end of if (customerData != null)

      if (mounted) {
        AppUtils.showSuccess(
          context,
          _isPayment ? 'تم تسجيل السداد بنجاح' : 'تم إضافة المبلغ بنجاح',
        );
        Navigator.pop(context, newTransaction);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'حدث خطأ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted د.ع';
  }

  @override
  Widget build(BuildContext context) {
    // إذا كان الزبون محدد مسبقاً، نعرض الشاشة المبسطة
    if (widget.customerId != null && widget.isPayment != null) {
      return _buildFocusedScreen();
    }
    // وإلا نعرض الشاشة القديمة (للتوافق)
    return _buildLegacyScreen();
  }

  /// الشاشة الجديدة المبسطة
  Widget _buildFocusedScreen() {
    final primaryColor = _isPayment ? AppColors.success : AppColors.error;
    final icon = _isPayment ? Icons.payment : Icons.add_circle;
    final title = _isPayment ? 'تسجيل سداد' : 'إضافة مبلغ';
    final subtitle = _isPayment ? 'سداد جزء من الدين' : 'إضافة دين جديد';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: false, // لا يتحرك الزر مع الكيبورد
      appBar: AppBar(
        title: Text(title),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
          // Header مع معلومات الزبون
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                // أيقونة
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 16),
                // اسم الزبون
                Text(
                  widget.customerName ?? 'زبون',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                // الرصيد الحالي
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'الرصيد الحالي: ${_formatCurrency(_customerBalance)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // النموذج
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // المبلغ
                    Text(
                      _isPayment ? 'مبلغ السداد' : 'المبلغ المضاف',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: 28,
                          color: AppColors.textLight.withValues(alpha: 0.5),
                        ),
                        suffixText: 'د.ع',
                        suffixStyle: TextStyle(
                          fontSize: 18,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'أدخل المبلغ';
                        }
                        final amount = parseFormattedNumber(value);
                        if (amount <= 0) {
                          return 'المبلغ غير صالح';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // التاريخ
                    Text(
                      'التاريخ',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: primaryColor),
                            const SizedBox(width: 12),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down, color: AppColors.textLight),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ملاحظات
                    Text(
                      'ملاحظات (اختياري)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: _isPayment ? 'مثال: دفعة شهر فبراير...' : 'مثال: بضاعة إضافية...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // مساحة إضافية للزر
          const SizedBox(height: 100),
        ],
        ),
      ),
      // زر الحفظ - ثابت في الأسفل
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isPayment ? Icons.check_circle : Icons.add_circle),
                      const SizedBox(width: 8),
                      Text(
                        _isPayment ? 'تأكيد السداد' : 'إضافة المبلغ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// الشاشة القديمة (للتوافق مع الاستخدامات الأخرى)
  Widget _buildLegacyScreen() {
    final transactionType = _isPayment ? TransactionType.payment : TransactionType.debt;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة قيد جديد'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // نوع القيد
              Text('نوع القيد', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      false,
                      Icons.shopping_cart,
                      'بيع بالدين',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeOption(
                      true,
                      Icons.payments,
                      'تسديد مبلغ',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // اسم الزبون
              Text('اسم الزبون', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCustomerId,
                decoration: const InputDecoration(
                  hintText: 'اختر اسم الزبون...',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: _customers.map((c) {
                  return DropdownMenuItem(
                    value: c['id']?.toString(),
                    child: Text(c['name']?.toString() ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCustomerId = value);
                },
              ),

              const SizedBox(height: 24),

              // المبلغ
              Text('المبلغ', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: const InputDecoration(
                  hintText: 'أدخل المبلغ',
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: 'د.ع',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال المبلغ';
                  }
                  if (parseFormattedNumber(value) <= 0) {
                    return 'الرجاء إدخال مبلغ صحيح';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // التاريخ
              Text('التاريخ', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.textLight),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ملاحظات
              Text('ملاحظات (اختياري)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'أضف ملاحظة...',
                  prefixIcon: Icon(Icons.note),
                ),
              ),

              const SizedBox(height: 32),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: transactionType == TransactionType.debt
                        ? AppColors.error
                        : AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(transactionType == TransactionType.debt
                                ? Icons.add_circle
                                : Icons.check_circle),
                            const SizedBox(width: 8),
                            Text(
                              transactionType == TransactionType.debt
                                  ? 'إضافة دين'
                                  : 'تأكيد السداد',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(bool isPaymentOption, IconData icon, String label) {
    final isSelected = _isPayment == isPaymentOption;
    final color = isPaymentOption ? AppColors.success : AppColors.error;
    
    return GestureDetector(
      onTap: () => setState(() => _isPayment = isPaymentOption),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textLight, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textLight,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// أنواع المعاملات
enum TransactionType {
  debt('دين'),
  payment('تسديد');

  final String label;
  const TransactionType(this.label);
}
