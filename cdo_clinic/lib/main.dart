import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cdo_clinic/features/auth/login_screen.dart';

void main() {
  runApp(const CdoClinicApp());
}

class CdoClinicApp extends StatelessWidget {
  const CdoClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CDO Clinic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF05006B),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF05006B),
          brightness: Brightness.dark,
        ),
      ),
      // ═══════════════════════════════════════════════════════════════
      // LOCALIZACIONES NECESARIAS PARA showDatePicker EN ESPAÑOL
      // ═══════════════════════════════════════════════════════════════
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      home: const LoginScreen(),  // ← AHORA EMPIEZA EN LOGIN
    );
  }
}