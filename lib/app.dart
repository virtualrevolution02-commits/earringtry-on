import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/ar_provider.dart';
import 'screens/ar_screen.dart';
import 'screens/splash_screen.dart';

class ARearringApp extends StatelessWidget {
  const ARearringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ARProvider(),
      child: MaterialApp(
        title: 'AR Earring Try-On',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D0D0D),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFC9A84C),
            secondary: Color(0xFFE8C96D),
            surface: Color(0xFF1A1A1A),
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
