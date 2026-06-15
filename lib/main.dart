import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:loghr_mobile/data/services/auth_service.dart';
import 'package:loghr_mobile/data/services/attendance_service.dart';
import 'package:loghr_mobile/data/services/leave_service.dart';
import 'package:loghr_mobile/data/services/loan_service.dart';
import 'package:loghr_mobile/data/services/expense_service.dart';
import 'package:loghr_mobile/data/services/notification_service.dart';
import 'package:loghr_mobile/data/repositories/auth_repository.dart';
import 'package:loghr_mobile/data/repositories/attendance_repository.dart';
import 'package:loghr_mobile/data/repositories/leave_repository.dart';
import 'package:loghr_mobile/data/repositories/loan_repository.dart';
import 'package:loghr_mobile/data/repositories/expense_repository.dart';
import 'package:loghr_mobile/data/repositories/profile_repository.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/attendance_provider.dart';
import 'package:loghr_mobile/logic/leave_provider.dart';
import 'package:loghr_mobile/logic/loan_provider.dart';
import 'package:loghr_mobile/logic/expense_provider.dart';
import 'package:loghr_mobile/logic/profile_provider.dart';
import 'package:loghr_mobile/logic/admin_provider.dart';
import 'package:loghr_mobile/logic/notification_provider.dart';
import 'package:loghr_mobile/logic/theme_provider.dart';
import 'package:loghr_mobile/logic/announcement_provider.dart';
import 'package:loghr_mobile/logic/task_provider.dart';
import 'package:loghr_mobile/logic/loyalty_provider.dart';
import 'package:loghr_mobile/logic/policy_provider.dart';
import 'package:loghr_mobile/data/services/announcement_service.dart';
import 'package:loghr_mobile/data/services/admin_service.dart';
import 'package:loghr_mobile/data/services/policy_service.dart';
import 'package:loghr_mobile/data/models/user.dart';
import 'package:loghr_mobile/ui/theme/app_theme.dart';
import 'package:loghr_mobile/ui/screens/auth/login_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/employee_main_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_main_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/payslip_screen.dart';
import 'package:loghr_mobile/config/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:loghr_mobile/ui/screens/error_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: '.env');
    await api.initialize();
    
    // Initialize Notification Service
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    runApp(const LogHRApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class LogHRApp extends StatelessWidget {
  const LogHRApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize services
    final authService = AuthService();
    final attendanceService = AttendanceService();
    final leaveService = LeaveService();
    final loanService = LoanService();
    final expenseService = ExpenseService();
    final adminService = AdminService();
    final notificationService = NotificationService();

    // Initialize repositories
    final authRepository = AuthRepository(authService);
    final attendanceRepository = AttendanceRepository(attendanceService);
    final leaveRepository = LeaveRepository(leaveService);
    final loanRepository = LoanRepository(loanService);
    final expenseRepository = ExpenseRepository(expenseService);
    final profileRepository = ProfileRepository();

    // Initialize providers
    final authProvider = AuthProvider(authRepository);
    final attendanceProvider = AttendanceProvider(attendanceRepository);
    final leaveProvider = LeaveProvider(leaveRepository);
    final loanProvider = LoanProvider(loanRepository);
    final expenseProvider = ExpenseProvider(expenseRepository);
    final profileProvider = ProfileProvider();
    final adminProvider = AdminProvider(adminService);
    final notificationProvider = NotificationProvider(notificationService);
    final themeProvider = ThemeProvider();

    // Trigger profile loading as soon as we have a user
    authProvider.addListener(() {
      if (authProvider.user != null && profileProvider.profileData == null) {
        profileProvider.loadProfile(authProvider.user!.id);
      }
    });

    // Check session if not already initialized
    if (authProvider.user == null && authProvider.isInitializing) {
       // already handled in constructor, but double check
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: attendanceProvider),
        ChangeNotifierProvider.value(value: leaveProvider),
        ChangeNotifierProvider.value(value: loanProvider),
        ChangeNotifierProvider.value(value: expenseProvider),
        ChangeNotifierProvider.value(value: profileProvider),
        ChangeNotifierProvider.value(value: adminProvider),
        ChangeNotifierProvider.value(value: notificationProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider(AnnouncementService())),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => LoyaltyProvider()),
        ChangeNotifierProvider(create: (_) => PolicyProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'LogHR Mobile',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: GoRouter(
              refreshListenable: authProvider,
              initialLocation: '/splash',
              redirect: (context, state) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final user = auth.user;
                final isInitializing = auth.isInitializing;
                final isLoggingIn = state.matchedLocation == '/login';
                final isSplash = state.matchedLocation == '/splash';

                if (isInitializing) return isSplash ? null : '/splash';

                if (user == null) {
                  return isLoggingIn ? null : '/login';
                }

                if (isLoggingIn || isSplash) {
                  return user.role == UserRole.admin ? '/admin' : '/employee';
                }

                return null;
              },
              routes: [
                GoRoute(
                  path: '/splash',
                  builder: (context, state) => const SplashScreen(),
                ),
                GoRoute(
                  path: '/login',
                  builder: (context, state) => const LoginScreen(),
                ),
                GoRoute(
                  path: '/employee',
                  builder: (context, state) => const EmployeeMainScreen(),
                ),
                GoRoute(
                  path: '/admin',
                  builder: (context, state) => const AdminMainScreen(),
                ),
                GoRoute(
                  path: '/payslip',
                  builder: (context, state) => const PayslipScreen(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, _) {
          final orgData = profileProvider.organizationData;
          final logoUrl = orgData?['logo_url'] as String? ??
                       orgData?['company_logo'] as String? ??
                       orgData?['organization_logo'] as String?;
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (logoUrl != null && logoUrl.isNotEmpty)
                  Container(
                    width: 120,
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 40),
                    child: Image.network(
                      logoUrl,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const CircularProgressIndicator(color: Color(0xFF2196F3));
                      },
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.business, size: 80, color: Color(0xFF2196F3)),
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                const CircularProgressIndicator(
                  color: Color(0xFF2196F3),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  orgData?['name'] as String? ?? 'LogHR',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
