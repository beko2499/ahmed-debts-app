import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../widgets/transaction_item.dart';
import '../../widgets/stat_card.dart';
import '../customers/customers_list_screen.dart';
import '../settings/settings_screen.dart';

/// اللوحة الرئيسية (Dashboard)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String _ownerName = '';
  String? _ownerImagePath;
  late PageController _pageController;
  
  // البيانات الفعلية (سيتم تحميلها من قاعدة البيانات)
  double _totalDebt = 0;
  double _totalCostPrice = 0; // مجموع سعر المواد
  double _totalProfit = 0; // مجموع الأرباح
  int _customerCount = 0;
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _loadOwnerName();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadOwnerName() {
    final settingsBox = Hive.box(AppConstants.settingsBox);
    setState(() {
      _ownerName = settingsBox.get(AppConstants.keyOwnerName, defaultValue: 'المستخدم');
      _ownerImagePath = settingsBox.get('owner_image_path');
    });
  }

  void _loadDashboardData() {
    final customersBox = Hive.box(AppConstants.customersBox);
    final transactionsBox = Hive.box(AppConstants.transactionsBox);
    final customers = customersBox.values.toList();
    
    double totalDebt = 0;
    double totalCostPrice = 0;
    double totalProfit = 0;
    
    for (var customer in customers) {
      final balance = (customer['balance'] as num?)?.toDouble() ?? 0;
      if (balance > 0) {
        totalDebt += balance;
      }
      
      // حساب سعر المادة والربح
      final costPrice = (customer['costPrice'] as num?)?.toDouble() ?? 0;
      final sellingPrice = (customer['sellingPrice'] as num?)?.toDouble() ?? 0;
      totalCostPrice += costPrice;
      totalProfit += sellingPrice; // الربح = سعر التقسيط (الفرق بين سعر البيع وسعر المادة)
    }
    
    // تحميل آخر الحركات
    final allTransactions = transactionsBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    
    // ترتيب حسب التاريخ (الأحدث أولاً)
    allTransactions.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA);
    });
    
    // أخذ آخر 5 حركات وإضافة اسم الزبون
    final recentTxs = allTransactions.take(5).map((tx) {
      final customerId = tx['customerId'];
      final customerData = customersBox.get(customerId);
      final customerName = customerData != null 
          ? customerData['name']?.toString() ?? 'زبون غير معروف'
          : 'زبون غير معروف';
      
      // تنسيق التاريخ
      final createdAt = DateTime.tryParse(tx['createdAt'] ?? '') ?? DateTime.now();
      final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
      
      return {
        'type': tx['type'],
        'customerName': customerName,
        'amount': (tx['amount'] as num?)?.toDouble() ?? 0,
        'date': formattedDate,
      };
    }).toList();
    
    setState(() {
      _customerCount = customers.length;
      _totalDebt = totalDebt;
      _totalCostPrice = totalCostPrice;
      _totalProfit = totalProfit;
      _recentTransactions = recentTxs;
    });
  }

  // مفتاح الـ Scaffold للتحكم بالـ Drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// فتح القائمة الجانبية
  void _showQuickMenu() {
    _scaffoldKey.currentState?.openDrawer();
  }

  /// بناء القائمة الجانبية
  Widget _buildEndDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header مع البروفايل
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // صورة البروفايل
                  Builder(
                    builder: (context) {
                      final hasImage = _ownerImagePath != null && 
                                      _ownerImagePath!.isNotEmpty && 
                                      File(_ownerImagePath!).existsSync();
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                            ),
                          ],
                          image: hasImage
                              ? DecorationImage(
                                  image: FileImage(File(_ownerImagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: !hasImage
                            ? Icon(
                                Icons.person,
                                size: 40,
                                color: AppColors.primary,
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // الاسم
                  Text(
                    _ownerName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سجل ديون $_ownerName',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // عناصر القائمة
            ListTile(
              leading: Icon(Icons.person_add, color: AppColors.gold),
              title: const Text('إضافة زبون جديد'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.addCustomer);
              },
            ),
            ListTile(
              leading: Icon(Icons.groups, color: AppColors.primary),
              title: const Text('قائمة الزبائن'),
              onTap: () {
                Navigator.pop(context);
                _pageController.animateToPage(1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.chat, color: AppColors.whatsapp),
              title: const Text('إعدادات واتساب'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.whatsappSettings);
              },
            ),
            ListTile(
              leading: Icon(Icons.backup, color: Colors.blue),
              title: const Text('النسخ الاحتياطي'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.backup);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: AppColors.textLight),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                _pageController.animateToPage(2,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            
            const Spacer(),
            
            // معلومات التطبيق
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'سجل ديون الغزالي v1.0',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// عرض جميع المعاملات
  void _showAllTransactions() {
    final transactionsBox = Hive.box(AppConstants.transactionsBox);
    final customersBox = Hive.box(AppConstants.customersBox);
    
    final allTransactions = transactionsBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    
    // ترتيب حسب التاريخ
    allTransactions.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA);
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جميع الحركات (${allTransactions.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: allTransactions.isEmpty
                  ? const Center(child: Text('لا توجد حركات'))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = allTransactions[index];
                        final customerId = tx['customerId'];
                        final customerData = customersBox.get(customerId);
                        final customerName = customerData?['name'] ?? 'غير معروف';
                        final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
                        final type = tx['type']?.toString() ?? '';
                        final isPayment = type == 'payment' || type == 'تسديد';
                        final createdAt = DateTime.tryParse(tx['createdAt'] ?? '') ?? DateTime.now();
                        final dateStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPayment 
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.error.withValues(alpha: 0.1),
                              child: Icon(
                                isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isPayment ? AppColors.success : AppColors.error,
                              ),
                            ),
                            title: Text(customerName),
                            subtitle: Text(dateStr),
                            trailing: Text(
                              '${isPayment ? "-" : "+"}${_formatCurrency(amount)}',
                              style: TextStyle(
                                color: isPayment ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildEndDrawer(),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
            // تحديث البيانات عند العودة للصفحة الرئيسية
            if (index == 0) {
              _loadDashboardData();
            }
          },
          children: [
            _buildDashboardPage(),
            _buildCustomersPage(),
            _buildSettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(context, AppRoutes.addCustomer);
                if (result != null) {
                  _loadDashboardData();
                }
              },
              backgroundColor: AppColors.gold,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDashboardPage() {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              IconButton(
                  onPressed: () => _showQuickMenu(),
                  icon: const Icon(Icons.menu),
                ),
                Text(
                  'اللوحة الرئيسية',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),

        // بطاقة الإحصائيات المقسمة
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSplitStatsCard(),
          ),
        ),

        // زر إضافة زبون
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.addCustomer),
              icon: Icon(Icons.person_add, color: AppColors.gold),
              label: Text('إضافة حساب جديد', style: TextStyle(color: AppColors.gold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.gold),
                backgroundColor: AppColors.gold.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),

        // عنوان آخر الحركات
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'آخر الحركات',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => _showAllTransactions(),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
          ),
        ),

        // قائمة آخر الحركات أو حالة فارغة
        if (_recentTransactions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: AppColors.textLight.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد حركات حتى الآن',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ابدأ بإضافة زبائن وتسجيل الديون',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final transaction = _recentTransactions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TransactionItem(
                      type: transaction['type'],
                      title: transaction['type'] == 'payment'
                          ? 'تسديد من ${transaction['customerName']}'
                          : transaction['customerName'],
                      subtitle: transaction['date'],
                      amount: transaction['amount'].toDouble(),
                      isPayment: transaction['type'] == 'payment',
                    ),
                  );
                },
                childCount: _recentTransactions.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSplitStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // الصف الأول
          Row(
            children: [
              // الديون لنا
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'الديون لنا',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(_totalDebt),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // الخط الفاصل العمودي
              Container(
                width: 1,
                height: 70,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
              
              // عدد الزبائن
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.groups,
                          color: AppColors.gold,
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'الزبائن',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_customerCount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // الخط الفاصل الأفقي
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          
          // الصف الثاني
          Row(
            children: [
              // مجموع الديون (سعر المواد)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: Colors.teal,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'مجموع الديون',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(_totalCostPrice),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // الخط الفاصل العمودي
              Container(
                width: 1,
                height: 70,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
              
              // مجموع الأرباح
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: AppColors.success,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'مجموع الأرباح',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(_totalProfit),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildCustomersCard() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 1),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.primary.withValues(alpha: 0.9),
              AppColors.primary.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // خلفية
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups, color: Colors.white),
              ),
            ),
            // المحتوى
            Positioned(
              bottom: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الزبائن',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'عرض ومتابعة ديون الزبائن',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersPage() {
    // استخدام شاشة الزبائن الأصلية بدون Scaffold
    return const CustomersListScreen(embedded: true);
  }

  Widget _buildSettingsPage() {
    // استخدام شاشة الإعدادات الأصلية بدون Scaffold  
    return const SettingsScreen(embedded: true);
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.dashboard, 'الرئيسية'),
            _buildNavItem(1, Icons.groups, 'الزبائن'),
            _buildNavItem(2, Icons.settings, 'الإعدادات'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textLight,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.textLight,
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
