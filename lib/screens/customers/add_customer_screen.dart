import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
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
  final List<int> _monthOptions = [3, 6, 9, 12, 18, 24];

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      _isEditMode = true;
      _loadCustomerData();
    }
    // الاستماع لتغييرات المبلغ
    _balanceController.addListener(() {
      setState(() {});
    });
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
      String status = 'paid';
      if (balance > 0) {
        status = 'pending';
      } else if (balance < 0) {
        status = 'overdue';
      }
      
      final customerData = {
        'id': customerId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'balance': balance,
        'originalDebt': balance > 0 ? balance : 0, // حفظ الدين الأصلي
        'installmentMonths': _installmentMonths,
        'installmentStartDate': DateTime.now().toIso8601String(), // تاريخ بدء الأقساط
        'status': status,
        'totalPaid': 0.0,
        'paidInstallmentsCount': 0,
        'currentInstallmentPaid': 0.0,
        'imageUrl': imagePath,
        'createdAt': _isEditMode ? null : DateTime.now().toIso8601String(),
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

              // الرصيد الافتتاحي
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

          // اختيار عدد الأشهر
          Text(
            'مدة التقسيط',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _monthOptions.map((months) {
                final isSelected = _installmentMonths == months;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _installmentMonths = months),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        '$months شهر',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // ملخص الأقساط
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryRow('إجمالي المبلغ', _formatCurrency(_currentBalance)),
                const Divider(height: 20),
                _buildSummaryRow('عدد الأقساط', '$_installmentMonths قسط'),
                const Divider(height: 20),
                _buildSummaryRow(
                  'القسط الشهري',
                  _formatCurrency(_monthlyPayment),
                  highlight: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // معاينة أول 3 أقساط
          Text(
            'الأقساط القادمة',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            _installmentMonths > 3 ? 3 : _installmentMonths,
            (index) {
              final date = DateTime.now().add(Duration(days: 30 * (index + 1)));
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
                      _formatCurrency(_monthlyPayment),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
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
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool highlight = false}) {
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
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
