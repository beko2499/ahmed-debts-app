import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/constants.dart';

/// شاشة تسجيل الدخول
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // انتظار التاكد من حالة المصادقة
    await Future.delayed(Duration.zero);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final box = Hive.box(AppConstants.settingsBox);
      final ownerName = box.get(AppConstants.keyOwnerName);
      
      if (mounted) {
        if (ownerName != null && ownerName.toString().isNotEmpty) {
           Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        } else {
           Navigator.pushReplacementNamed(context, AppRoutes.setup);
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      // بدء عملية تسجيل الدخول
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // المستخدم ألغى العملية
        setState(() => _isLoading = false);
        return;
      }

      // الحصول على تفاصيل المصادقة
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // إنشاء بيانات الاعتماد
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // تسجيل الدخول في Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);
      
      // حفظ البريد الإلكتروني للإشارة إليه لاحقاً
      final box = Hive.box(AppConstants.settingsBox);
      await box.put('connected_email', googleUser.email);
      
      // التحقق مما إذا كان الاسم محفوظاً مسبقاً
      final ownerName = box.get(AppConstants.keyOwnerName);
      
      if (mounted) {
        if (ownerName != null && ownerName.toString().isNotEmpty) {
           Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        } else {
           Navigator.pushReplacementNamed(context, AppRoutes.setup);
        }
      }
    } catch (e) {
      // التحقق مما إذا كان المستخدم مسجلاً رغم الخطأ (مشكلة معروفة في Pigeon)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // المستخدم مسجل فعلاً، نتجاهل الخطأ ونتابع
        final box = Hive.box(AppConstants.settingsBox);
        await box.put('connected_email', currentUser.email ?? '');
        
        // التحقق مما إذا كان الاسم محفوظاً مسبقاً
        final ownerName = box.get(AppConstants.keyOwnerName);

        if (mounted) {
          if (ownerName != null && ownerName.toString().isNotEmpty) {
             Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
          } else {
             Navigator.pushReplacementNamed(context, AppRoutes.setup);
          }
        }
        return;
      }
      
      // خطأ حقيقي
      if (mounted) {
        AppUtils.showError(context, 'حدث خطأ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              AppColors.backgroundLight,
              AppColors.gold.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                
                // الأيقونة الموحدة (من Splash Screen)
                Container(
                  width: 120,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // الورقة/الفاتورة
                      Positioned(
                        left: 25,
                        child: Container(
                          width: 65,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 3,
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Container(
                                width: 35,
                                height: 3,
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // رمز العملة
                              Text(
                                'ع',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // علامة الصح
                      Positioned(
                        right: 20,
                        bottom: 5,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // اسم التطبيق بالعربي
                Text(
                  'ديون الغزالي',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // اسم التطبيق بالإنجليزي
                Text(
                  'AL-GHAZALI DEBT MANAGER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gold,
                    letterSpacing: 3,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'نظامك الذكي لإدارة ديون الزبائن\nوتتبع المعاملات المالية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                
                const Spacer(),
                
                // مميزات التطبيق بلون داكن لأن الخلفية فاتحة
                _buildFeatureItem(Icons.cloud_sync, 'نسخ احتياطي تلقائي', AppColors.primary),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.chat, 'تذكير عبر واتساب', AppColors.whatsapp),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.security, 'بيانات آمنة ومشفرة', AppColors.gold),
                
                const Spacer(),
                
                // زر تسجيل الدخول
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, // زر أزرق
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 18,
                                  height: 18,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'تسجيل الدخول بحساب Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ملاحظة الخصوصية
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Text(
                      'بيانات الحساب تُستخدم للنسخ الاحتياطي فقط',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
