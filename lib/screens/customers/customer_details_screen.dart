import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/constants.dart';
import '../../services/whatsapp_service.dart';

/// شاشة تفاصيل حساب الزبون
class CustomerDetailsScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  // بيانات الزبون (يتم تحميلها من Hive)
  Map<String, dynamic> _customer = {};
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _showInstallments = true; // للتبديل بين جدول الدفعات وسجل المعاملات
  bool _showAllInstallments = false; // لعرض جميع الأقساط

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // تحميل بيانات الزبون
    final customersBox = Hive.box(AppConstants.customersBox);
    final customerData = customersBox.get(widget.customerId);
    if (customerData != null) {
      _customer = Map<String, dynamic>.from(customerData);
      
      // تهيئة الدين الأصلي للزبائن القدامى الذين لا يملكون هذا الحقل
      if (_customer['originalDebt'] == null && (_customer['balance'] as num?)?.toDouble() != null) {
        final balance = (_customer['balance'] as num).toDouble();
        if (balance > 0) {
          _customer['originalDebt'] = balance;
          _customer['installmentMonths'] = _customer['installmentMonths'] ?? 12;
          _customer['installmentStartDate'] = _customer['installmentStartDate'] ?? DateTime.now().toIso8601String();
          // حفظ التحديث
          customersBox.put(widget.customerId, _customer);
        }
      }
    }

    // تحميل معاملات هذا الزبون
    final transactionsBox = Hive.box(AppConstants.transactionsBox);
    final allTransactions = transactionsBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((t) => t['customerId'] == widget.customerId)
        .toList();
    
    // ترتيب حسب التاريخ (الأحدث أولاً)
    allTransactions.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    setState(() {
      _transactions = allTransactions;
      _isLoading = false;
    });
  }

  Future<void> _makeCall() async {
    final phone = _customer['phone']?.toString() ?? '';
    if (phone.isEmpty) {
      AppUtils.showError(context, 'لا يوجد رقم هاتف مسجل');
      return;
    }
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'تعذر فتح تطبيق الهاتف');
      }
    }
  }

  Future<void> _openLocation() async {
    final address = _customer['address']?.toString() ?? '';
    if (address.isEmpty) {
      AppUtils.showError(context, 'الموقع غير مضاف');
      return;
    }
    final encodedAddress = Uri.encodeComponent(address);
    final uri = Uri.parse('https://maps.google.com/?q=$encodedAddress');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'تعذر فتح تطبيق الخرائط');
      }
    }
  }

  Future<void> _sendWhatsAppReminder() async {
    final phone = (_customer['phone']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      AppUtils.showError(context, 'لا يوجد رقم هاتف مسجل');
      return;
    }

    // إظهار رسالة جاري الإرسال
    AppUtils.showInfo(context, 'جارٍ إرسال التذكير...');

    final name = _customer['name']?.toString() ?? 'الزبون';
    final balance = (_customer['balance'] as num?)?.toDouble() ?? 0;

    final success = await WhatsAppService().sendMonthlyReminder(
      phoneNumber: phone,
      customerName: name,
      dueAmount: balance,
    );

    if (mounted) {
      if (success) {
        AppUtils.showSuccess(context, 'تم إرسال التذكير بنجاح');
      } else {
        AppUtils.showError(context, 'فشل فتح واتساب');
      }
    }
  }

  Future<void> _navigateToAddTransaction({required bool isPayment}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.addTransaction,
      arguments: {
        'customerId': widget.customerId,
        'customerName': _customer['name'],
        'isPayment': isPayment,
      },
    );
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الزبون'),
        content: Text('هل أنت متأكد من حذف ${_customer['name']}؟ سيتم حذف جميع المعاملات المرتبطة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final customersBox = Hive.box(AppConstants.customersBox);
      final transactionsBox = Hive.box(AppConstants.transactionsBox);
      
      // حذف معاملات الزبون
      final customerTransactions = transactionsBox.values
          .where((t) => (t as Map)['customerId'] == widget.customerId)
          .toList();
      for (var tx in customerTransactions) {
        await transactionsBox.delete((tx as Map)['id']);
      }
      
      // حذف الزبون
      await customersBox.delete(widget.customerId);
      
      if (mounted) {
        AppUtils.showSuccess(context, 'تم حذف الزبون بنجاح');
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_forward),
            ),
            title: Text(_customer['name']?.toString() ?? 'زبون'),
            actions: [
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    final result = await Navigator.pushNamed(
                      context,
                      AppRoutes.addCustomer,
                      arguments: widget.customerId,
                    );
                    if (result != null) {
                      _loadData();
                    }
                  } else if (value == 'delete') {
                    _deleteCustomer();
                  }
                },
              ),
            ],
          ),

          // Hero Card (Profile & Balance)
          SliverToBoxAdapter(
            child: _buildHeroCard(),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: _buildActionButtons(),
          ),

          // Tabs
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              minHeight: 60.0,
              maxHeight: 60.0,
              child: Container(
                color: Colors.grey.shade50,
                child: _buildTabSelector(),
              ),
            ),
            pinned: true,
          ),

          // Content
          if (_showInstallments) ...[
            SliverToBoxAdapter(child: _buildInstallmentsSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]
          else ...[
            if (_transactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('لا توجد معاملات بعد', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTransactionTimelineItem(
                      _transactions[index],
                      isFirst: index == 0,
                      isLast: index == _transactions.length - 1,
                    ),
                    childCount: _transactions.length,
                  ),
                ),
              ),
          ],
        ],
      ),
      
      // Floating Action Button for Adding Transaction
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionSheet(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('إضافة معاملة'),
      ),
    );
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ما هو نوع المعاملة؟',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildTransactionOption(
                    icon: Icons.shopping_cart,
                    label: 'دين جديد',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToAddTransaction(isPayment: false);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTransactionOption(
                    icon: Icons.payment,
                    label: 'تسديد',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToAddTransaction(isPayment: true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Builder(
                builder: (context) {
                  final imageUrl = _customer['imageUrl']?.toString();
                  final hasImage = imageUrl != null && 
                                  imageUrl.isNotEmpty && 
                                  File(imageUrl).existsSync();
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                      image: hasImage
                          ? DecorationImage(
                              image: FileImage(File(imageUrl)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasImage
                        ? Icon(Icons.person, size: 50, color: Colors.grey.shade400)
                        : null,
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified, color: AppColors.primary, size: 24),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Name & Location
          Text(
            _customer['name']?.toString() ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                _customer['address']?.toString() ?? 'العنوان غير محدد',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Container(
            height: 1,
            width: double.infinity,
            color: Colors.grey.shade100,
          ),
          
          // Balance Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'الرصيد الحالي',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency((_customer['balance'] as num?)?.toDouble() ?? 0),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickAction(
            icon: Icons.call,
            label: 'اتصال',
            color: Colors.blue,
            onTap: _makeCall,
          ),
          _buildQuickAction(
            icon: Icons.chat,
            label: 'واتساب',
            color: Colors.green,
            onTap: _sendWhatsAppReminder,
          ),
          _buildQuickAction(
            icon: Icons.map,
            label: 'الموقع',
            color: Colors.orange,
            onTap: _openLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem('جدول الدفعات', true),
          _buildTabItem('سجل المعاملات', false),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, bool isInstallments) {
    final isSelected = _showInstallments == isInstallments;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showInstallments = isInstallments),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
          // عرض القسم المحدد
          if (_showInstallments) ...[
            // قسم الدفعات / الأقساط
            SliverToBoxAdapter(
              child: _buildInstallmentsSection(),
            ),
            // مسافة في الأسفل للأزرار
            const SliverToBoxAdapter(
              child: SizedBox(height: 150),
            ),
          ]
          else ...[
            // Timeline أو حالة فارغة
            if (_transactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 150),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: AppColors.textLight.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد معاملات حتى الآن',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 180),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTransactionTimelineItem(
                      _transactions[index],
                      isFirst: index == 0,
                      isLast: index == _transactions.length - 1,
                    ),
                    childCount: _transactions.length,
                  ),
                ),
              ),
          ],
        ],
      ),

      // زر الواتساب
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // زرين: سداد وزيادة المبلغ
              Row(
                children: [
                  // زر سداد
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToAddTransaction(isPayment: true),
                      icon: const Icon(Icons.payment, size: 20),
                      label: const Text('سداد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // زر زيادة المبلغ
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToAddTransaction(isPayment: false),
                      icon: const Icon(Icons.add_circle, size: 20),
                      label: const Text('زيادة المبلغ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // زر واتساب
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sendWhatsAppReminder,
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('إرسال تذكير عبر واتساب'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showInstallments = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _showInstallments ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: _showInstallments ? Colors.white : AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'جدول الدفعات',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _showInstallments ? Colors.white : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showInstallments = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_showInstallments ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 18,
                        color: !_showInstallments ? Colors.white : AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'سجل المعاملات',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: !_showInstallments ? Colors.white : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentsSection() {
    // بيانات الأقساط
    final currentBalance = (_customer['balance'] as num?)?.toDouble() ?? 0;
    final installmentMonths = (_customer['installmentMonths'] as num?)?.toInt() ?? 12;
    
    // عدد الأقساط المدفوعة (مُخزّن)
    final paidInstallmentsCount = (_customer['paidInstallmentsCount'] as num?)?.toInt() ?? 0;
    
    // المبلغ المدفوع من القسط الحالي (مُخزّن)
    final currentInstallmentPaid = (_customer['currentInstallmentPaid'] as num?)?.toDouble() ?? 0;
    
    // إجمالي ما تم دفعه (من السجل)
    final totalPaid = (_customer['totalPaid'] as num?)?.toDouble() ?? 0;
    
    // قائمة مبالغ الأقساط المدفوعة (الفعلية)
    final paidInstallmentAmounts = (_customer['paidInstallmentAmounts'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble()).toList() ?? [];
    
    // إذا لم يكن هناك دين، لا تعرض القسم
    if (currentBalance <= 0 && paidInstallmentsCount == 0) {
      return const SizedBox.shrink();
    }

    // حساب الأقساط المتبقية
    final remainingInstallments = installmentMonths - paidInstallmentsCount;
    
    // الدين الأصلي (عند إنشاء الحساب)
    final originalDebt = (_customer['originalDebt'] as num?)?.toDouble() ?? (currentBalance + totalPaid);
    
    // قسط الأشهر المتبقية = الرصيد الحالي ÷ الأقساط المتبقية (يتغير عند إضافة دين)
    final futureMonthlyPayment = remainingInstallments > 0 
        ? currentBalance / remainingInstallments 
        : currentBalance;
    
    // تاريخ بدء الأقساط
    final startDateStr = _customer['installmentStartDate']?.toString();
    final startDate = startDateStr != null 
        ? DateTime.tryParse(startDateStr) ?? DateTime.now()
        : DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان وزر الإعدادات
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'جدول الدفعات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _showInstallmentSettingsDialog(currentBalance),
                    icon: Icon(Icons.settings, color: AppColors.textLight),
                    tooltip: 'إعدادات التقسيط',
                  ),
                ],
              ),
            ),
            
            // ملخص
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInstallmentStat('المتبقي', _formatCurrency(currentBalance)),
                      Container(width: 1, height: 30, color: AppColors.primary.withValues(alpha: 0.3)),
                      _buildInstallmentStat('المدفوع', _formatCurrency(totalPaid)),
                      Container(width: 1, height: 30, color: AppColors.primary.withValues(alpha: 0.3)),
                      _buildInstallmentStat('القسط', _formatCurrency(futureMonthlyPayment)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // شريط التقدم
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: installmentMonths > 0 ? paidInstallmentsCount / installmentMonths : 0,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation(AppColors.success),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$paidInstallmentsCount من $installmentMonths قسط مدفوع • متبقي $remainingInstallments قسط',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // جدول الأقساط
            ...List.generate(_showAllInstallments ? installmentMonths : (installmentMonths > 6 ? 6 : installmentMonths), (index) {
              final dueDate = DateTime(startDate.year, startDate.month + index, startDate.day);
              final now = DateTime.now();
              
              // تحديد حالة القسط
              String status;
              String amountDisplay;
              Color statusColor;
              Color bgColor;
              IconData statusIcon;
              
              if (index < paidInstallmentsCount) {
                // قسط مدفوع بالكامل - يظهر بالقيمة التي دُفعت فعلاً
                status = 'تم السداد ✓';
                // استخدام القيمة الفعلية من القائمة إن وجدت
                final actualAmount = index < paidInstallmentAmounts.length 
                    ? paidInstallmentAmounts[index]
                    : originalDebt / installmentMonths;
                amountDisplay = _formatCurrency(actualAmount);
                statusColor = AppColors.success;
                bgColor = Colors.green.shade50;
                statusIcon = Icons.check_circle;
              } else if (index == paidInstallmentsCount) {
                // القسط الحالي
                final remaining = futureMonthlyPayment - currentInstallmentPaid;
                if (currentInstallmentPaid > 0) {
                  status = 'متبقي ${_formatCurrency(remaining)}';
                  amountDisplay = '${_formatCurrency(currentInstallmentPaid)} / ${_formatCurrency(futureMonthlyPayment)}';
                  statusColor = Colors.orange;
                  bgColor = Colors.orange.shade50;
                  statusIcon = Icons.hourglass_top;
                } else if (dueDate.isBefore(now)) {
                  status = 'متأخر - غير مدفوع';
                  amountDisplay = _formatCurrency(futureMonthlyPayment);
                  statusColor = AppColors.error;
                  bgColor = Colors.red.shade50;
                  statusIcon = Icons.warning;
                } else {
                  status = 'القسط الحالي';
                  amountDisplay = _formatCurrency(futureMonthlyPayment);
                  statusColor = AppColors.primary;
                  bgColor = Colors.blue.shade50;
                  statusIcon = Icons.schedule;
                }
              } else {
                // قسط قادم - يظهر بالقيمة الجديدة
                amountDisplay = _formatCurrency(futureMonthlyPayment);
                if (dueDate.isBefore(now)) {
                  status = 'متأخر - غير مدفوع';
                  statusColor = AppColors.error;
                  bgColor = Colors.red.shade50;
                  statusIcon = Icons.warning;
                } else {
                  status = 'غير مدفوع';
                  statusColor = AppColors.textLight;
                  bgColor = Colors.grey.shade50;
                  statusIcon = Icons.access_time;
                }
              }
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: index < paidInstallmentsCount
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      amountDisplay,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(statusIcon, color: statusColor, size: 18),
                  ],
                ),
              );
            }),
            
            // زر عرض/إخفاء الكل
            if (installmentMonths > 6)
              TextButton.icon(
                onPressed: () => setState(() => _showAllInstallments = !_showAllInstallments),
                icon: Icon(_showAllInstallments ? Icons.expand_less : Icons.expand_more),
                label: Text(_showAllInstallments 
                    ? 'إخفاء الأقساط' 
                    : 'عرض جميع الأقساط ($installmentMonths)'),
              ),
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Future<void> _showInstallmentSettingsDialog(double originalDebt) async {
    final currentMonths = (_customer['installmentMonths'] as num?)?.toInt() ?? 12;
    int selectedMonths = currentMonths;
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إعدادات التقسيط'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('عدد الأشهر: $selectedMonths'),
              const SizedBox(height: 16),
              Slider(
                value: selectedMonths.toDouble(),
                min: 1,
                max: 36,
                divisions: 35,
                label: '$selectedMonths شهر',
                onChanged: (value) {
                  setDialogState(() => selectedMonths = value.toInt());
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [3, 6, 12, 18, 24].map((months) {
                  return ChoiceChip(
                    label: Text('$months'),
                    selected: selectedMonths == months,
                    onSelected: (_) {
                      setDialogState(() => selectedMonths = months);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedMonths),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      // حفظ الإعدادات
      final customersBox = Hive.box(AppConstants.customersBox);
      _customer['installmentMonths'] = result;
      if (_customer['originalDebt'] == null) {
        _customer['originalDebt'] = (_customer['balance'] as num?)?.toDouble() ?? 0;
      }
      _customer['installmentStartDate'] = DateTime.now().toIso8601String();
      await customersBox.put(widget.customerId, _customer);
      setState(() {});
    }
  }

  void _showAllInstallmentsDialog(
    double currentBalance, int months, List<double> paidInstallmentAmounts, double originalDebt, double futureMonthlyPayment,
    DateTime startDate, int paidInstallmentsCount, double currentInstallmentPaid,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('جميع الأقساط'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: months,
            itemBuilder: (context, index) {
              final dueDate = DateTime(startDate.year, startDate.month + index, startDate.day);
              final now = DateTime.now();
              
              // تحديد حالة القسط
              String status;
              String amountDisplay;
              Color statusColor;
              
              if (index < paidInstallmentsCount) {
                // قسط مدفوع - بقيمته الفعلية
                status = 'تم السداد ✓';
                final actualAmount = index < paidInstallmentAmounts.length 
                    ? paidInstallmentAmounts[index]
                    : originalDebt / months;
                amountDisplay = _formatCurrency(actualAmount);
                statusColor = AppColors.success;
              } else if (index == paidInstallmentsCount) {
                final remaining = futureMonthlyPayment - currentInstallmentPaid;
                if (currentInstallmentPaid > 0) {
                  status = 'متبقي ${_formatCurrency(remaining)}';
                  amountDisplay = '${_formatCurrency(currentInstallmentPaid)} / ${_formatCurrency(futureMonthlyPayment)}';
                  statusColor = Colors.orange;
                } else if (dueDate.isBefore(now)) {
                  status = 'متأخر - غير مدفوع';
                  amountDisplay = _formatCurrency(futureMonthlyPayment);
                  statusColor = AppColors.error;
                } else {
                  status = 'القسط الحالي';
                  amountDisplay = _formatCurrency(futureMonthlyPayment);
                  statusColor = AppColors.primary;
                }
              } else {
                // قسط مستقبلي - بالقيمة الجديدة
                amountDisplay = _formatCurrency(futureMonthlyPayment);
                if (dueDate.isBefore(now)) {
                  status = 'متأخر - غير مدفوع';
                  statusColor = AppColors.error;
                } else {
                  status = 'غير مدفوع';
                  statusColor = AppColors.textLight;
                }
              }
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor,
                  child: index < paidInstallmentsCount
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                ),
                title: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                subtitle: Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
                trailing: Text(
                  amountDisplay,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTimelineItem(
    Map<String, dynamic> transaction, {
    required bool isFirst,
    required bool isLast,
  }) {
    final type = transaction['type']?.toString() ?? 'debt';
    final isPayment = type == 'payment';
    final isOpening = type == 'opening';
    
    // إنشاء العنوان ديناميكياً إذا لم يكن موجوداً
    String title = transaction['title']?.toString() ?? '';
    if (title.isEmpty) {
      if (isPayment) {
        title = 'دفعة نقدية (له)';
      } else if (isOpening) {
        title = 'رصيد افتتاحي';
      } else {
        title = 'دين جديد (عليه)';
      }
    }
    
    // تنسيق التاريخ
    String dateStr = transaction['date']?.toString() ?? '';
    if (dateStr.isEmpty) {
      final createdAt = DateTime.tryParse(transaction['createdAt'] ?? '');
      if (createdAt != null) {
        dateStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
      } else {
        dateStr = 'تاريخ غير محدد';
      }
    }
    
    // المبلغ
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    Color iconBgColor;
    Color iconColor;
    IconData icon;

    if (isPayment) {
      iconBgColor = AppColors.success.withValues(alpha: 0.1);
      iconColor = AppColors.success;
      icon = Icons.arrow_downward;
    } else if (isOpening) {
      iconBgColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade600;
      icon = Icons.account_balance_wallet;
    } else {
      iconBgColor = AppColors.error.withValues(alpha: 0.1);
      iconColor = AppColors.error;
      icon = Icons.shopping_cart;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 8, color: Colors.grey.shade200),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.backgroundLight,
                      width: 4,
                    ),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: Colors.grey.shade200),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        amount > 0
                            ? '${isPayment ? '-' : '+'} ${_formatCurrencyShort(amount)}'
                            : '٠ د.ع',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPayment ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                  if (transaction['notes'] != null && transaction['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        transaction['notes'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}،',
    );
    return '$formatted د.ع';
  }

  String _formatCurrencyShort(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}،',
    );
    return '$formatted د.ع';
  }
}
