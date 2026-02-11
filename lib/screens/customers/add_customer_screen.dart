import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/whatsapp_service.dart';
import '../../services/backup_service.dart';
import '../../utils/currency_input_formatter.dart';

/// شاشة إضافة أو تعديل زبون
class AddCustomerScreen extends StatefulWidget {
  final String? customerId; // null للإضافة، قيمة للتعديل

  const AddCustomerScreen({super.key, this.customerId});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  bool _isLoading = false;
  bool _isEditMode = false;
  
  // صورة الزبون
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _existingImagePath;
  
  // إعدادات الأقساط
  int _installmentMonths = 12;
  final List<int> _monthOptions = List.generate(24, (i) => i + 1); // 1-24 شهر
  
  // وضع الأقساط: تلقائي أو يدوي
  bool _isManualInstallment = false;
  final _manualPaymentController = TextEditingController();
  
  // سعر المادة وسعرها مع القصد
  final _costPriceController = TextEditingController(text: '0');
  final _sellingPriceController = TextEditingController(text: '0');

  // ثابت التقريب (250 دينار)
  static const int _roundingUnit = 250;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      _isEditMode = true;
      _loadCustomerData();
    }
    // الاستماع لتغييرات المبلغ
    _balanceController.addListener(_onBalanceChanged);
    // حساب المبلغ الافتتاحي = سعر المادة + سعر التقسيط
    _costPriceController.addListener(_updateBalanceFromPrices);
    _sellingPriceController.addListener(_updateBalanceFromPrices);
  }

  /// تحديث المبلغ الافتتاحي من مجموع سعر المادة وسعر التقسيط
  void _updateBalanceFromPrices() {
    if (!_isEditMode) {
      final cost = parseFormattedNumber(_costPriceController.text);
      final installmentFee = parseFormattedNumber(_sellingPriceController.text);
      final total = cost + installmentFee;
      final formatted = _formatNumber(total);
      if (_balanceController.text != formatted) {
        _balanceController.text = formatted;
      }
    }
  }

  String _formatNumber(double value) {
    if (value == 0) return '';
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _onBalanceChanged() {
    setState(() {});
  }

  /// حساب الأقساط الذكية (مقربة لأقرب 250 دينار)
  List<double> _calculateSmartInstallments(double total, int months) {
    if (months <= 0 || total <= 0) return [];
    
    // القسط الأساسي (مقرب للأسفل)
    final basePayment = (total / months / _roundingUnit).floor() * _roundingUnit;
    // القسط الأعلى
    final highPayment = basePayment + _roundingUnit;
    
    // كم شهر يحتاج للقسط الأعلى؟
    // total = (months - x) * basePayment + x * highPayment
    // total = months * basePayment + x * (highPayment - basePayment)
    // x = (total - months * basePayment) / _roundingUnit
    final highPaymentMonths = ((total - months * basePayment) / _roundingUnit).round();
    final lowPaymentMonths = months - highPaymentMonths;
    
    // إنشاء قائمة الأقساط
    List<double> installments = [];
    for (int i = 0; i < lowPaymentMonths; i++) {
      installments.add(basePayment.toDouble());
    }
    for (int i = 0; i < highPaymentMonths; i++) {
      installments.add(highPayment.toDouble());
    }
    
    return installments;
  }

  /// حساب الأقساط اليدوية (مبلغ ثابت + الشهر الأخير يأخذ الباقي)
  List<double> _calculateManualInstallments(double total, int months, double fixedMonthly) {
    if (months <= 0 || total <= 0 || fixedMonthly <= 0) return [];
    
    List<double> installments = [];
    double remaining = total;
    
    // الأشهر من 1 إلى N-1 تأخذ المبلغ الثابت
    for (int i = 0; i < months - 1; i++) {
      if (remaining <= fixedMonthly) {
        // إذا كان المتبقي أقل من القسط الثابت، نضيفه كله
        installments.add(remaining);
        remaining = 0;
        break;
      }
      installments.add(fixedMonthly);
      remaining -= fixedMonthly;
    }
    
    // الشهر الأخير يأخذ الباقي
    if (remaining > 0) {
      installments.add(remaining);
    }
    
    return installments;
  }

  /// الحصول على ملخص الأقساط (يعمل مع الوضعين)
  Map<String, dynamic> _getInstallmentSummary() {
    List<double> installments;
    
    if (_isManualInstallment) {
      final fixedPayment = parseFormattedNumber(_manualPaymentController.text);
      installments = _calculateManualInstallments(_currentBalance, _installmentMonths, fixedPayment);
    } else {
      installments = _calculateSmartInstallments(_currentBalance, _installmentMonths);
    }
    
    if (installments.isEmpty) return {};
    
    Map<double, int> distribution = {};
    for (var amount in installments) {
      distribution[amount] = (distribution[amount] ?? 0) + 1;
    }
    
    return {
      'installments': installments,
      'distribution': distribution,
      'total': installments.fold(0.0, (sum, v) => sum + v),
      'isManual': _isManualInstallment,
    };
  }

  /// الحصول على ملخص الأقساط الذكية (للتوافق مع الكود القديم)
  Map<String, dynamic> _getSmartInstallmentSummary() {
    final installments = _calculateSmartInstallments(_currentBalance, _installmentMonths);
    if (installments.isEmpty) return {};
    
    Map<double, int> distribution = {};
    for (var amount in installments) {
      distribution[amount] = (distribution[amount] ?? 0) + 1;
    }
    
    return {
      'installments': installments,
      'distribution': distribution,
      'total': installments.fold(0.0, (sum, v) => sum + v),
    };
  }

  void _loadCustomerData() {
    final customersBox = Hive.box(AppConstants.customersBox);
    final customerData = customersBox.get(widget.customerId);
    if (customerData != null) {
      _nameController.text = customerData['name']?.toString() ?? '';
      _phoneController.text = customerData['phone']?.toString() ?? '';
      _addressController.text = customerData['address']?.toString() ?? '';
      _balanceController.text = (customerData['balance'] as num?)?.toString() ?? '0';
      _installmentMonths = (customerData['installmentMonths'] as num?)?.toInt() ?? 12;
      _existingImagePath = customerData['imageUrl']?.toString();
      // تحميل الحقول الجديدة
      _costPriceController.text = (customerData['costPrice'] as num?)?.toString() ?? '0';
      _sellingPriceController.text = (customerData['sellingPrice'] as num?)?.toString() ?? '0';
      // تحميل إعدادات وضع الأقساط
      _isManualInstallment = customerData['installmentMode'] == 'manual';
      _manualPaymentController.text = (customerData['fixedMonthlyPayment'] as num?)?.toString() ?? '';
    }
  }

  /// اختيار صورة من المعرض أو الكاميرا
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('اختيار من المعرض'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() => _selectedImage = File(image.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('التقاط صورة'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() => _selectedImage = File(image.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// حفظ الصورة في مجلد التطبيق
  Future<String?> _saveImageToAppDir(File imageFile, String customerId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/customer_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final newPath = '${imagesDir.path}/$customerId.jpg';
    await imageFile.copy(newPath);
    return newPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  double get _currentBalance => parseFormattedNumber(_balanceController.text);
  double get _monthlyPayment => _currentBalance > 0 && _installmentMonths > 0 
      ? _currentBalance / _installmentMonths 
      : 0;

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // استخدام ID الموجود للتعديل أو إنشاء جديد للإضافة
      final customerId = _isEditMode ? widget.customerId! : const Uuid().v4();
      final balance = _currentBalance;
      
      // حفظ الصورة إذا تم اختيارها
      String? imagePath = _existingImagePath;
      if (_selectedImage != null) {
        imagePath = await _saveImageToAppDir(_selectedImage!, customerId);
      }
      
      // تحديد حالة الزبون بناءً على الرصيد
      String status = 'completed';
      if (balance > 0) {
        status = 'active';
      } else if (balance < 0) {
        status = 'active'; // نعتبر الرصيد السالب نشط أيضاً لتنبيه المستخدم
      }
      
      // حساب الأقساط حسب الوضع المختار
      List<double> smartInstallments;
      if (_isManualInstallment) {
        final fixedPayment = parseFormattedNumber(_manualPaymentController.text);
        smartInstallments = _calculateManualInstallments(balance, _installmentMonths, fixedPayment);
      } else {
        smartInstallments = _calculateSmartInstallments(balance, _installmentMonths);
      }

      final customerData = {
        'id': customerId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'balance': balance,
        'originalDebt': balance > 0 ? balance : 0,
        'installmentMonths': _installmentMonths,
        'installmentStartDate': DateTime.now().toIso8601String(),
        'status': status,
        'totalPaid': 0.0,
        'paidInstallmentsCount': 0,
        'currentInstallmentPaid': 0.0,
        'imageUrl': imagePath,
        'createdAt': _isEditMode ? null : DateTime.now().toIso8601String(),
        // الحقول الجديدة
        'costPrice': parseFormattedNumber(_costPriceController.text),
        'sellingPrice': parseFormattedNumber(_sellingPriceController.text),
        'smartInstallments': smartInstallments, // الأقساط الذكية
        // إعدادات وضع الأقساط
        'installmentMode': _isManualInstallment ? 'manual' : 'auto',
        'fixedMonthlyPayment': _isManualInstallment ? parseFormattedNumber(_manualPaymentController.text) : 0.0,
      };

      // حفظ في Hive
      final customersBox = Hive.box(AppConstants.customersBox);
      
      // للتعديل، نحتفظ بالبيانات الأصلية
      if (_isEditMode) {
        final existingData = customersBox.get(customerId);
        if (existingData != null) {
          customerData['createdAt'] = existingData['createdAt'];
          customerData['totalPaid'] = existingData['totalPaid'] ?? 0.0;
          customerData['paidInstallmentsCount'] = existingData['paidInstallmentsCount'] ?? 0;
          customerData['currentInstallmentPaid'] = existingData['currentInstallmentPaid'] ?? 0.0;
          // الاحتفاظ بالدين الأصلي فقط إذا لم يتم تغيير الرصيد
          if (existingData['originalDebt'] != null) {
            customerData['originalDebt'] = existingData['originalDebt'];
          }
        }
      }
      
      await customersBox.put(customerId, customerData);

      // النسخ الاحتياطي التلقائي بعد أي تغيير
      BackupService.autoBackup();

      // إرسال إشعار واتساب تلقائياً للزبون الجديد (إذا كان عليه دين)
      if (!_isEditMode && balance > 0 && _phoneController.text.isNotEmpty) {
        // إرسال إشعار واتساب
        try {
          WhatsAppService().sendNewCustomerNotification(
            phoneNumber: _phoneController.text.trim(),
            customerName: _nameController.text.trim(),
            totalAmount: balance,
            firstPayment: 0,
            remainingAmount: balance,
            remainingMonths: _installmentMonths,
          );
        } catch (e) {
          debugPrint('Error sending WhatsApp: $e');
        }
      }

      if (mounted) {
        AppUtils.showSuccess(
          context,
          _isEditMode 
            ? 'تم تعديل ${_nameController.text} بنجاح'
            : 'تم إضافة ${_nameController.text} بنجاح',
        );
        Navigator.pop(context, customerData);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'تعديل الزبون' : 'إضافة حساب جديد'),
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
              // صورة الزبون
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : (_existingImagePath != null && File(_existingImagePath!).existsSync())
                                  ? DecorationImage(
                                      image: FileImage(File(_existingImagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: (_selectedImage == null && 
                                (_existingImagePath == null || !File(_existingImagePath!).existsSync()))
                            ? Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey.shade400,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // الاسم الكامل
              Text('الاسم الكامل', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'مثال: علي العراقي',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم الزبون';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // رقم الهاتف
              Text('رقم الهاتف (مع رمز الدولة)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: '249123456789',
                  helperText: 'مثال: 249 للسودان، 964 للعراق، 966 للسعودية',
                  helperStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
                  prefixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.phone, color: AppColors.whatsapp),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 24, color: Colors.grey.shade300),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال رقم الهاتف';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // العنوان (اختياري)
              Row(
                children: [
                  Text('العنوان / المنطقة', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'اختياري',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'بغداد، الكرادة',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),

              const SizedBox(height: 24),

              // سعر المادة
              Text('سعر المادة (التكلفة)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _costPriceController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.shopping_cart_outlined, color: Colors.grey),
                  suffixText: 'د.ع',
                  suffixStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              // سعر التقسيط (الربح)
              Text('سعر التقسيط (الربح)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _sellingPriceController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.sell_outlined, color: AppColors.gold),
                  suffixText: 'د.ع',
                  suffixStyle: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                  helperText: 'المبلغ الافتتاحي = سعر المادة + سعر التقسيط',
                  helperStyle: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),

              const SizedBox(height: 20),

              // المبلغ الافتتاحي
              Text('المبلغ الافتتاحي', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                  suffixText: 'د.ع',
                  suffixStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // جدول الأقساط (يظهر فقط عند إدخال مبلغ)
              if (_currentBalance > 0) ...[
                const SizedBox(height: 24),
                _buildInstallmentPreview(),
              ],

              const SizedBox(height: 32),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveCustomer,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isEditMode ? 'حفظ التعديلات' : 'إضافة الحساب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// معاينة جدول الأقساط
  Widget _buildInstallmentPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'جدول الأقساط',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // زر التبديل بين الوضعين
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                // تعيين تلقائي
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isManualInstallment = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isManualInstallment ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_fix_high,
                              size: 18,
                              color: !_isManualInstallment ? Colors.white : AppColors.textLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'تعيين تلقائي',
                              style: TextStyle(
                                color: !_isManualInstallment ? Colors.white : AppColors.textLight,
                                fontWeight: !_isManualInstallment ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // تعيين يدوي
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isManualInstallment = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isManualInstallment ? AppColors.gold : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit,
                              size: 18,
                              color: _isManualInstallment ? Colors.white : AppColors.textLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'تعيين يدوي',
                              style: TextStyle(
                                color: _isManualInstallment ? Colors.white : AppColors.textLight,
                                fontWeight: _isManualInstallment ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // اختيار عدد الأشهر
          Text(
            'مدة التقسيط',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _monthOptions.length,
              itemBuilder: (context, index) {
                final months = _monthOptions[index];
                final isSelected = _installmentMonths == months;
                return GestureDetector(
                  onTap: () => setState(() => _installmentMonths = months),
                  child: Container(
                    width: 48,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$months',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // حقل القسط الثابت (يظهر فقط في الوضع اليدوي)
          if (_isManualInstallment) ...[
            const SizedBox(height: 16),
            Text(
              'القسط الشهري الثابت',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _manualPaymentController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsSeparatorInputFormatter(),
              ],
              decoration: InputDecoration(
                hintText: 'مثال: 200,000',
                prefixIcon: Icon(Icons.payments_outlined, color: AppColors.gold),
                suffixText: 'د.ع',
                suffixStyle: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.gold, width: 2),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ملخص الأقساط
          Builder(
            builder: (context) {
              final summary = _getInstallmentSummary();
              final installments = summary['installments'] as List<double>? ?? [];
              final isManual = summary['isManual'] as bool? ?? false;
              
              if (installments.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      isManual ? 'أدخل مبلغ القسط الشهري' : 'لا توجد أقساط',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                );
              }
              
              // حساب الملخص
              double fixedAmount = 0;
              double lastAmount = 0;
              int fixedCount = 0;
              
              if (isManual && installments.length > 1) {
                fixedAmount = installments.first;
                lastAmount = installments.last;
                fixedCount = installments.length - 1;
              }
              
              final distribution = summary['distribution'] as Map<double, int>? ?? {};
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('إجمالي المبلغ', _formatCurrency(_currentBalance)),
                    const Divider(height: 20),
                    _buildSummaryRow('عدد الأقساط', '${installments.length} قسط'),
                    const Divider(height: 20),
                    
                    // عرض حسب الوضع
                    if (isManual && installments.length > 1) ...[
                      // الوضع اليدوي: نعرض القسط الثابت والشهر الأخير
                      _buildSummaryRow(
                        'الأشهر 1-$fixedCount',
                        _formatCurrency(fixedAmount),
                        highlight: true,
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'الشهر الأخير',
                        _formatCurrency(lastAmount),
                        highlight: true,
                        isLastMonth: true,
                      ),
                    ] else if (distribution.length == 1) ...[
                      // الوضع التلقائي: قسط واحد موحد
                      _buildSummaryRow(
                        'القسط الشهري',
                        _formatCurrency(distribution.keys.first),
                        highlight: true,
                      ),
                    ] else if (distribution.length == 2) ...[
                      // الوضع التلقائي: قسطين مختلفين
                      Column(
                        children: distribution.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${e.value} قسط',
                                  style: TextStyle(color: AppColors.textLight, fontSize: 14),
                                ),
                                Text(
                                  _formatCurrency(e.key),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.gold),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'مقربة لأقرب 250 دينار',
                                style: TextStyle(fontSize: 12, color: AppColors.gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // معاينة الأقساط القادمة
          Text(
            'الأقساط القادمة',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final summary = _getInstallmentSummary();
              final installments = summary['installments'] as List<double>? ?? [];
              final previewCount = installments.length > 3 ? 3 : installments.length;
              
              return Column(
                children: [
                  ...List.generate(previewCount, (index) {
                    final date = DateTime.now().add(Duration(days: 30 * (index + 1)));
                    final amount = index < installments.length ? installments[index] : _monthlyPayment;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${date.day}/${date.month}/${date.year}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          Text(
                            _formatCurrency(amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_installmentMonths > 3)
                    Center(
                      child: Text(
                        '... و ${_installmentMonths - 3} أقساط أخرى',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool highlight = false, bool isLastMonth = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: highlight ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: highlight ? 18 : 14,
            color: isLastMonth ? AppColors.gold : (highlight ? AppColors.primary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
