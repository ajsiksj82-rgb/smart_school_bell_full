import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../screens/home_screen.dart';
import 'app_state.dart';

const Color kPrimary = Color(0xFF0D2B5E);
const Color kSecondary = Color(0xFF4FA3E0);

class SmartSchoolBellApp extends StatelessWidget {
  const SmartSchoolBellApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'الجرس المدرسي الذكي',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, secondary: kSecondary),
          scaffoldBackgroundColor: const Color(0xFFF4F6FA),
          appBarTheme: const AppBarTheme(backgroundColor: kPrimary, foregroundColor: Colors.white),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
