import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'config/constants.dart';
import 'services/database_service.dart';
import 'services/app_lock_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // إعداد Hive للتخزين المحلي
  await Hive.initFlutter();
  
  // تسجيل الـ Adapters (سيتم توليدها لاحقاً)
  // Hive.registerAdapter(CustomerAdapter());
  // Hive.registerAdapter(TransactionAdapter());
  
  // فتح الـ Boxes
  await Hive.openBox(AppConstants.settingsBox);
  await Hive.openBox(AppConstants.customersBox);
  await Hive.openBox(AppConstants.transactionsBox);
  
  // إعداد شريط الحالة
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const GhazaliDebtApp());
}

class GhazaliDebtApp extends StatefulWidget {
  const GhazaliDebtApp({super.key});

  @override
  State<GhazaliDebtApp> createState() => _GhazaliDebtAppState();
}

class _GhazaliDebtAppState extends State<GhazaliDebtApp> with WidgetsBindingObserver {
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (AppLockService().isLockEnabled) {
        setState(() => _isLocked = true);
        AppLockService().setAuthenticated(false);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isLocked) {
        _checkLock();
      }
    }
  }

  Future<void> _checkLock() async {
    final authenticated = await AppLockService().authenticate();
    if (authenticated) {
      setState(() => _isLocked = false);
      AppLockService().setAuthenticated(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseService()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        
        // دعم اللغة العربية
        locale: const Locale('ar', 'IQ'),
        supportedLocales: const [
          Locale('ar', 'IQ'),
          Locale('ar'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        
        // الثيم
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        
        // اتجاه النص وقفل التطبيق
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              children: [
                child!,
                if (_isLocked)
                  Scaffold(
                    body: Container(
                      color: Colors.white,
                      width: double.infinity,
                      height: double.infinity,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, size: 64, color: AppColors.primary),
                            const SizedBox(height: 16),
                            const Text(
                              'التطبيق مقفل',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _checkLock,
                              child: const Text('فتح القفل'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        
        // المسارات
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
