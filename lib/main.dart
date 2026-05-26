import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/map_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'storage/hive_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline Hive storage and adapters
  await HiveStorage.init();

  final storage = HiveStorage();
  final isFirst = await storage.isFirstLaunch();

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
    return MaterialApp(
      title: 'Snap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF5E5CE6),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF1C1C1E),
        ),
        cupertinoOverrideTheme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: Color(0xFF5E5CE6),
          barBackgroundColor: Color(0xCCFFFFFF),
          scaffoldBackgroundColor: Color(0xFFFFFFFF),
          textTheme: CupertinoTextThemeData(primaryColor: Color(0xFF5E5CE6)),
        ),
      ),
      home: isFirstLaunch ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
