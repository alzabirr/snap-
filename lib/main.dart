import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/map_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/local_model_service.dart';
import 'storage/hive_storage.dart';
import 'themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar and system navigation bar transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize offline Hive storage and adapters
  await HiveStorage.init();

  final storage = HiveStorage();
  final isFirst = await storage.isFirstLaunch();
  
  // Load initial Dark Mode preference
  final isDark = storage.getSetting('darkMode', false) as bool;
  darkModeNotifier.value = isDark;

  unawaited(LocalModelService.ensureDefaultModelDownloaded());

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MapProvider())],
      child: SnapApp(isFirstLaunch: isFirst),
    ),
  );
}

class SnapApp extends StatelessWidget {
  final bool isFirstLaunch;

  const SnapApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'Snap',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            primaryColor: const Color(0xFF5E5CE6),
            scaffoldBackgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarContrastEnforced: false,
                systemStatusBarContrastEnforced: false,
              ),
            ),
            cupertinoOverrideTheme: CupertinoThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
              primaryColor: const Color(0xFF5E5CE6),
              barBackgroundColor: isDark ? const Color(0xCC121212) : const Color(0xCCFFFFFF),
              scaffoldBackgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
              textTheme: const CupertinoTextThemeData(primaryColor: Color(0xFF5E5CE6)),
            ),
          ),
          home: isFirstLaunch ? const OnboardingScreen() : const HomeScreen(),
        );
      },
    );
  }
}
