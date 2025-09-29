// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:overlay_support/overlay_support.dart';
import 'screens/home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  /// Глобальный ключ навигатора — доступен из любого места:
  /// App.navigatorKey.currentState?.push(...);
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        title: 'Touch NoteBook',
        debugShowCheckedModeBanner: false, // 🔔 убирает "DEBUG" в углу
        navigatorKey: navigatorKey, // <-- ВАЖНО: подключили ключ
        navigatorObservers: [routeObserver],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
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
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
        ],
        locale: const Locale('ru'),
        home: const HomeScreen(),
      ),
    );
  }
}
