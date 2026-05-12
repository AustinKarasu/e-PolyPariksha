import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/test_list_screen.dart';
import 'services/notification_service.dart';
import 'widgets/splash_screen.dart';
import 'widgets/update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const PolyHtStudentApp());
}

class PolyHtStudentApp extends StatelessWidget {
  const PolyHtStudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..restoreSession()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'PolyH.T Student',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.mode,
            home: UpdateGate(
              child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isLoading) {
                  return const SplashScreen(subtitle: 'STUDENT');
                }
                return auth.isAuthenticated ? const TestListScreen() : const LoginScreen();
              },
            ),
            ),
          );
        },
      ),
    );
  }
}
