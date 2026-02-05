import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/constants.dart';
import '../../widgets/customer_card.dart';

/// شاشة قائمة الزبائن
class CustomersListScreen extends StatefulWidget {
  final bool embedded;
  
  const CustomersListScreen({super.key, this.embedded = false});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, pending, paid, overdue

  // قائمة الزبائن (سيتم تحميلها من قاعدة البيانات)
  List<Map<String, dynamic>> _customers = [];

  List<Map<String, dynamic>> get _filteredCustomers {
    var filtered = _customers;
    
    // فلترة حسب النص
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((c) => c['name'].toString().contains(_searchQuery))
          .toList();
    }
    
    // فلترة حسب الحالة
    if (_statusFilter != 'all') {
      filtered = filtered.where((c) => c['status'] == _statusFilter).toList();
    }
    
    return filtered;
  }

  double get _totalDebt {
    return _customers
        .where((c) => ((c['balance'] as num?)?.toDouble() ?? 0) > 0)
        .fold(0.0, (sum, c) => sum + ((c['balance'] as num?)?.toDouble() ?? 0));
  }

  double get _totalPaidThisMonth {
    try {
      final transactionsBox = Hive.box(AppConstants.transactionsBox);
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      double total = 0;
      for (var transaction in transactionsBox.values) {
        final t = Map<String, dynamic>.from(transaction as Map);
        final type = t['type']?.toString() ?? '';
        final dateStr = t['date']?.toString() ?? '';
        
        // فقط التسديدات
        if (type == 'payment' || type == 'تسديد') {
          try {
            final date = DateTime.parse(dateStr);
            if (date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth)) {
              total += (t['amount'] as num?)?.toDouble() ?? 0;
            }
          } catch (_) {}
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() {
    final customersBox = Hive.box(AppConstants.customersBox);
    final customers = customersBox.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    setState(() {
      _customers = customers;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'فلترة الزبائن',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFilterOption('الكل', 'all', Icons.people),
            _buildFilterOption('عليهم ديون', 'pending', Icons.hourglass_empty, color: Colors.orange),
            _buildFilterOption('تم السداد', 'paid', Icons.check_circle, color: AppColors.success),
            _buildFilterOption('متأخرون', 'overdue', Icons.warning, color: AppColors.error),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value, IconData icon, {Color? color}) {
    final isSelected = _statusFilter == value;
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textLight),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
      selected: isSelected,
      onTap: () {
        setState(() => _statusFilter = value);
        Navigator.pop(context);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        // Header للوضع المضمن
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48),
                Text(
                  'قائمة الزبائن',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: _showFilterSheet,
                  icon: Icon(
                    Icons.filter_list,
                    color: _statusFilter != 'all' ? AppColors.primary : null,
                  ),
                ),
              ],
            ),
          ),
        // شريط البحث
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'بحث عن زبون...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // بطاقات الإحصائيات
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'إجمالي الديون',
                  _formatCurrency(_totalDebt),
                  AppColors.primary,
                  true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'المسددة هذا الشهر',
                  _formatCurrency(_totalPaidThisMonth),
                  AppColors.success,
                  false,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // رأس القائمة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الاسم',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                ),
              ),
              Text(
                'الحالة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // قائمة الزبائن أو حالة فارغة
        Expanded(
          child: _filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.groups,
                        size: 64,
                        color: AppColors.textLight.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا يوجد زبائن حتى الآن',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على + لإضافة زبون جديد',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CustomerCard(
                        name: customer['name'],
                        balance: customer['balance'],
                        status: customer['status'],
                        imageUrl: customer['imageUrl'],
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.customerDetails,
                            arguments: customer['id'],
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    // إذا كان مضمناً، نعيد المحتوى فقط بدون Scaffold
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة الزبائن'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward),
        ),
        actions: [
          IconButton(
            onPressed: _showFilterSheet,
            icon: Icon(
              Icons.filter_list,
              color: _statusFilter != 'all' ? AppColors.primary : null,
            ),
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, AppRoutes.addCustomer);
          if (result != null) {
            _loadCustomers();
          }
        },
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    bool isPrimary,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
        border: isPrimary ? null : Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isPrimary ? Colors.white.withValues(alpha: 0.8) : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isPrimary ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    // تنسيق الرقم بفواصل الآلاف
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted د.ع';
  }
}
