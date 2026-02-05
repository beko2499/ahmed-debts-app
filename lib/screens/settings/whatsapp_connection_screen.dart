import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/whatsapp_service.dart';

/// شاشة ربط واتساب (مبسطة)
class WhatsAppConnectionScreen extends StatefulWidget {
  const WhatsAppConnectionScreen({super.key});

  @override
  State<WhatsAppConnectionScreen> createState() => _WhatsAppConnectionScreenState();
}

class _WhatsAppConnectionScreenState extends State<WhatsAppConnectionScreen> {
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  bool _isConnected = false;
  String? _pairingCode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    
    final status = await WhatsAppService().getStatus();
    
    setState(() {
      _isConnected = status['connected'] == true;
      _pairingCode = status['pairingCode'];
      _errorMessage = status['error'];
      _isLoading = false;
    });
  }

  Future<void> _connect() async {
    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم الهاتف');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pairingCode = null;
    });

    final result = await WhatsAppService().connectWithPhoneNumber(_phoneController.text);

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _pairingCode = result['pairingCode'];
      } else {
        _errorMessage = result['error'] ?? 'فشل الاتصال';
      }
    });
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    
    await WhatsAppService().disconnect();
    
    setState(() {
      _isLoading = false;
      _isConnected = false;
      _pairingCode = null;
    });
    
    if (mounted) {
      AppUtils.showSuccess(context, 'تم قطع الاتصال');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ربط واتساب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // حالة الاتصال
            _buildStatusCard(),
            
            const SizedBox(height: 24),
            
            // ربط الهاتف أو كود الربط
            if (!_isConnected && _pairingCode == null) _buildPhonePairing(),
            
            // كود الربط
            if (_pairingCode != null) _buildPairingCodeCard(),
            
            // رسالة الخطأ
            if (_errorMessage != null && !_errorMessage!.contains('timeout')) 
              _buildErrorCard(),
            
            const SizedBox(height: 24),
            
            // تعليمات
            if (!_isConnected) _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              ),
              child: Icon(
                _isConnected ? Icons.check_circle : Icons.link_off,
                size: 32,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isConnected ? '✅ متصل بواتساب' : '❌ غير متصل',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isConnected 
                        ? 'الرسائل سترسل تلقائياً في الخلفية'
                        : 'اربط حسابك للإرسال التلقائي',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhonePairing() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, color: AppColors.whatsapp),
                const SizedBox(width: 8),
                const Text(
                  'أدخل رقم هاتفك',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 18, letterSpacing: 1),
              decoration: InputDecoration(
                hintText: '07xxxxxxxxx',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link, color: Colors.white),
                label: Text(
                  _isLoading ? 'جاري الربط...' : 'الحصول على كود الربط',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingCodeCard() {
    return Card(
      elevation: 3,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.key, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              'كود الربط',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _pairingCode!));
                AppUtils.showSuccess(context, 'تم نسخ الكود');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _pairingCode!,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '📋 اضغط للنسخ',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const Text(
              'أدخل هذا الكود في واتساب:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('الإعدادات ← الأجهزة المرتبطة ← ربط جهاز'),
            const Text('← الربط برقم الهاتف'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'كيفية الربط',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStep('1', 'أدخل رقم هاتفك أعلاه'),
            _buildStep('2', 'اضغط "الحصول على كود الربط"'),
            _buildStep('3', 'افتح واتساب على هاتفك'),
            _buildStep('4', 'الإعدادات ← الأجهزة المرتبطة'),
            _buildStep('5', 'ربط جهاز ← الربط برقم الهاتف'),
            _buildStep('6', 'أدخل الكود الظاهر'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ تحذير: هذه الطريقة غير رسمية',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
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

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
