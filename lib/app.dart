// lib/app.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  /// Глобальный ключ навигатора — доступен из любого места:
  /// App.navigatorKey.currentState?.push(...);
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Touch NoteBook',
      debugShowCheckedModeBanner: false, // 🔔 убирает "DEBUG" в углу
      navigatorKey: navigatorKey, // <-- ВАЖНО: подключили ключ
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
