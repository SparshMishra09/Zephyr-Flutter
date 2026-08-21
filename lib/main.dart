import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/database/app_database.dart';
import 'features/chat/presentation/viewmodels/chat_viewmodel.dart';
import 'features/documents/presentation/viewmodels/documents_viewmodel.dart';
import 'features/home/presentation/viewmodels/home_viewmodel.dart';
import 'features/onboarding/presentation/viewmodels/onboarding_viewmodel.dart';
import 'features/settings/presentation/viewmodels/settings_viewmodel.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'theme/zephyr_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force full-screen and status bar styling
  await SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize shared preferences and database
  final prefs = await SharedPreferences.getInstance();
  final db = await AppDatabase.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingViewModel(prefs)..init()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel(prefs)..init()),
        ChangeNotifierProvider(create: (_) => HomeViewModel(db)..init()),
        ChangeNotifierProvider(create: (_) => ChatViewModel(db)),
        ChangeNotifierProvider(create: (_) => DocumentsViewModel(db)),
      ],
      child: const ZephyrApp(),
    ),
  );
}

class ZephyrApp extends StatelessWidget {
  const ZephyrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ZephyrTheme.darkTheme,
      darkTheme: ZephyrTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingViewModel>();

    if (!onboarding.isComplete) {
      return const OnboardingScreen();
    }
    return const HomeScreen();
  }
}