import 'package:flutter/material.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/screens/pomogotchi_home.dart';

class PomogotchiApp extends StatelessWidget {
  const PomogotchiApp({super.key, this.controller});

  final PetSessionController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F1DD),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F5130),
        brightness: Brightness.light,
        primary: const Color(0xFF2F5130),
        secondary: const Color(0xFFDA6C4B),
        surface: const Color(0xFFFFFCF4),
      ),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: const Color(0xFF211A15),
        displayColor: const Color(0xFF211A15),
      ),
    );

    return MaterialApp(
      title: 'Pomogotchi',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: PomogotchiHome(controller: controller),
    );
  }
}
