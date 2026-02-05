import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/setup_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/customers/customers_list_screen.dart';
import '../screens/customers/customer_details_screen.dart';
import '../screens/customers/add_customer_screen.dart';
import '../screens/transactions/add_transaction_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/whatsapp_settings_screen.dart';
import '../screens/settings/whatsapp_connection_screen.dart';
import '../screens/settings/backup_screen.dart';
import '../screens/settings/monthly_reminders_screen.dart';


/// مسارات التطبيق
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String setup = '/setup';
  static const String dashboard = '/dashboard';
  static const String customers = '/customers';
  static const String customerDetails = '/customer-details';
  static const String addCustomer = '/add-customer';
  static const String addTransaction = '/add-transaction';
  static const String settings = '/settings';
  static const String whatsappSettings = '/whatsapp-settings';
  static const String whatsappConnection = '/whatsapp-connection';
  static const String backup = '/backup';
  static const String monthlyReminders = '/monthly-reminders';


  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    setup: (_) => const SetupScreen(),
    dashboard: (_) => const DashboardScreen(),
    customers: (_) => const CustomersListScreen(),
    settings: (_) => const SettingsScreen(),
    whatsappSettings: (_) => const WhatsAppSettingsScreen(),
    whatsappConnection: (_) => const WhatsAppConnectionScreen(),
    backup: (_) => const BackupScreen(),
    monthlyReminders: (_) => const MonthlyRemindersScreen(),

  };

  /// التنقل مع تمرير arguments
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case customerDetails:
        final customerId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => CustomerDetailsScreen(customerId: customerId),
        );
      case addCustomer:
        final customerId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => AddCustomerScreen(customerId: customerId),
        );
      case addTransaction:
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => AddTransactionScreen(
              customerId: args['customerId'] as String?,
              customerName: args['customerName'] as String?,
              isPayment: args['isPayment'] as bool?,
            ),
          );
        } else {
          final customerId = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => AddTransactionScreen(customerId: customerId),
          );
        }
      default:
        return null;
    }
  }
}
