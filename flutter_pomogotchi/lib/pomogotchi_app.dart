import 'dart:async';

import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pomogotchi/agents/narrative_agent.dart';
import 'package:pomogotchi/agents/pet_agent.dart';
import 'package:pomogotchi/controllers/pomogotchi_home_controller.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_controller.dart';
import 'package:pomogotchi/features/pomodoro/data/pomodoro_database.dart';
import 'package:pomogotchi/features/pomodoro/data/powersync_pomodoro_repository.dart';
import 'package:pomogotchi/screens/pomogotchi_home.dart';
import 'package:pomogotchi/services/animal_catalog.dart';
import 'package:pomogotchi/shared/services/app_clock.dart';
import 'package:pomogotchi/shared/services/app_lifecycle_service.dart';

class PomogotchiApp extends StatelessWidget {
  const PomogotchiApp({super.key, this.controller, this.databaseOwner});

  final PomogotchiHomeController? controller;
  final PomodoroDatabaseOwner? databaseOwner;

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
      home: controller != null
          ? PomogotchiHome(controller: controller!)
          : _PomogotchiBootstrap(databaseOwner: databaseOwner),
    );
  }
}

class _PomogotchiBootstrap extends StatefulWidget {
  const _PomogotchiBootstrap({this.databaseOwner});

  final PomodoroDatabaseOwner? databaseOwner;

  @override
  State<_PomogotchiBootstrap> createState() => _PomogotchiBootstrapState();
}

class _PomogotchiBootstrapState extends State<_PomogotchiBootstrap> {
  late final PomodoroDatabaseOwner _databaseOwner;
  FlutterAppLifecycleService? _lifecycleService;
  PomogotchiHomeController? _controller;
  Object? _bootstrapError;
  bool _isBootstrapping = false;

  @override
  void initState() {
    super.initState();
    _databaseOwner = widget.databaseOwner ?? PomodoroDatabaseOwner();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_isBootstrapping) {
      return;
    }

    setState(() {
      _isBootstrapping = true;
      _bootstrapError = null;
    });

    try {
      final database = await _databaseOwner.initialize();
      final lifecycle = FlutterAppLifecycleService();
      final controller = PomogotchiHomeController(
        pomodoroController: PomodoroController(
          repository: PowerSyncPomodoroRepository(database),
          clock: const SystemAppClock(),
          lifecycleService: lifecycle,
        ),
        petSessionController: _buildPetSessionController(),
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        lifecycle.dispose();
        return;
      }
      setState(() {
        _lifecycleService = lifecycle;
        _controller = controller;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bootstrapError = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  PetSessionController _buildPetSessionController() {
    const cactusToken = String.fromEnvironment('CACTUS_TOKEN');
    const cactusModel = String.fromEnvironment('CACTUS_MODEL');
    const cactusNarrativeModel = String.fromEnvironment(
      'CACTUS_NARRATIVE_MODEL',
    );
    const cactusPetModel = String.fromEnvironment('CACTUS_PET_MODEL');
    final token = cactusToken.isEmpty ? null : cactusToken;
    final sharedModelOverride = cactusModel.isEmpty ? null : cactusModel;
    final narrativeModelOverride = cactusNarrativeModel.isEmpty
        ? sharedModelOverride
        : cactusNarrativeModel;
    final petModelOverride = cactusPetModel.isEmpty
        ? sharedModelOverride
        : cactusPetModel;
    final completionMode = token == null
        ? CompletionMode.local
        : CompletionMode.hybrid;
    final narrativeAgent = narrativeModelOverride == null
        ? CactusNarrativeAgent(
            completionMode: completionMode,
            cactusToken: token,
          )
        : CactusNarrativeAgent(
            model: narrativeModelOverride,
            completionMode: completionMode,
            cactusToken: token,
          );
    final petAgent = petModelOverride == null
        ? CactusPetAgent(completionMode: completionMode, cactusToken: token)
        : CactusPetAgent(
            model: petModelOverride,
            completionMode: completionMode,
            cactusToken: token,
          );

    return PetSessionController(
      narrativeAgent: narrativeAgent,
      petAgent: petAgent,
      animalLoader: () => discoverAnimalSpecs(rootBundle),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _lifecycleService?.dispose();
    unawaited(_databaseOwner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Initialization failed: $_bootstrapError',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_isBootstrapping || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PomogotchiHome(controller: _controller!);
  }
}
