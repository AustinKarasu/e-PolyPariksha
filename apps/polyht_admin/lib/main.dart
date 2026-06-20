import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/role_selection_screen.dart';
import 'student_portal/providers/auth_provider.dart' as student;
import 'student_portal/services/notification_service.dart';
import 'services/app_error_reporter.dart';
import 'widgets/splash_screen.dart';
import 'widgets/update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await AppErrorReporter.instance.init();
  runZonedGuarded(
    () => runApp(const PolyHtAdminApp()),
    (error, stack) => unawaited(AppErrorReporter.instance.report(
      error.toString(),
      stackTrace: stack.toString(),
      severity: 'crash',
    )),
  );
}

class PolyHtAdminApp extends StatelessWidget {
  const PolyHtAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..restoreSession()),
        ChangeNotifierProvider(
            create: (_) => student.AuthProvider()..restoreSession()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'e-PolyPariksha HP',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.mode,
            navigatorObservers: [AppRouteObserver()],
            home: UpdateGate(
              child: Consumer2<AuthProvider, student.AuthProvider>(
                builder: (context, auth, studentAuth, _) {
                  if (auth.isLoading || studentAuth.isLoading) {
                    return const SplashScreen(subtitle: 'e-PolyPariksha HP');
                  }
                  return const RoleSelectionScreen();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
