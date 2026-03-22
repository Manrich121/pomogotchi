import 'dart:async';

import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pomogotchi/agents/narrative_agent.dart';
import 'package:pomogotchi/agents/pet_agent.dart';
import 'package:pomogotchi/controllers/ios_pet_session_controller.dart';
import 'package:pomogotchi/controllers/macos_pet_session_controller.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/controllers/pomogotchi_home_controller.dart';
import 'package:pomogotchi/features/auth/presentation/magic_link_sign_in_screen.dart';
import 'package:pomogotchi/features/pet/data/pet_sync_repository.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_controller.dart';
import 'package:pomogotchi/features/pomodoro/data/pomodoro_database.dart';
import 'package:pomogotchi/features/pomodoro/data/pomodoro_sync.dart';
import 'package:pomogotchi/features/pomodoro/data/powersync_pomodoro_repository.dart';
import 'package:pomogotchi/screens/pomogotchi_home.dart';
import 'package:pomogotchi/services/animal_catalog.dart';
import 'package:pomogotchi/shared/services/app_clock.dart';
import 'package:pomogotchi/shared/services/app_lifecycle_service.dart';
import 'package:powersync/powersync.dart';

class PomogotchiApp extends StatelessWidget {
  const PomogotchiApp({
    super.key,
    this.controller,
    this.databaseOwner,
    this.authClient,
  });

  final PomogotchiHomeController? controller;
  final PomodoroDatabaseOwner? databaseOwner;
  final PomodoroAuthClient? authClient;

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
          : _PomogotchiBootstrap(
              databaseOwner: databaseOwner,
              authClient: authClient,
            ),
    );
  }
}

class _PomogotchiBootstrap extends StatefulWidget {
  const _PomogotchiBootstrap({this.databaseOwner, this.authClient});

  final PomodoroDatabaseOwner? databaseOwner;
  final PomodoroAuthClient? authClient;

  @override
  State<_PomogotchiBootstrap> createState() => _PomogotchiBootstrapState();
}

class _PomogotchiBootstrapState extends State<_PomogotchiBootstrap> {
  static const MethodChannel _statusBarMenuChannel = MethodChannel(
    'pomogotchi/status_bar_menu',
  );

  late final PomodoroDatabaseOwner _databaseOwner;
  late final PomodoroAuthClient _authClient;
  FlutterAppLifecycleService? _lifecycleService;
  PomogotchiHomeController? _controller;
  StreamSubscription<PomodoroAuthEvent>? _authSubscription;
  Object? _bootstrapError;
  bool _authReady = false;
  bool _isBootstrappingPomogotchi = false;

  @override
  void initState() {
    super.initState();
    _databaseOwner = widget.databaseOwner ?? PomodoroDatabaseOwner();
    _authClient = widget.authClient ?? pomodoroAuthClient;
    if (_usesStatusBarSignOut) {
      _statusBarMenuChannel.setMethodCallHandler(_handleStatusBarMethodCall);
    }
    _initializeAuth();
  }

  bool get _usesStatusBarSignOut =>
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _initializeAuth() async {
    try {
      await _authClient.initialize();
      await _authSubscription?.cancel();
      _authSubscription = _authClient.authStateChanges.listen((event) {
        unawaited(_handleAuthEvent(event));
      });
      if (_authClient.isLoggedIn) {
        await _bootstrapPomogotchi();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _authReady = true;
        _bootstrapError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bootstrapError = error;
      });
    }
  }

  Future<void> _handleAuthEvent(PomodoroAuthEvent event) async {
    if (event == PomodoroAuthEvent.signedIn) {
      if (_controller == null) {
        await _bootstrapPomogotchi();
      }
      return;
    }

    if (event == PomodoroAuthEvent.signedOut) {
      await _disposePomogotchiState(clearDatabase: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _authReady = true;
        _bootstrapError = null;
      });
    }
  }

  Future<void> _bootstrapPomogotchi() async {
    if (_isBootstrappingPomogotchi) {
      return;
    }

    setState(() {
      _isBootstrappingPomogotchi = true;
      _bootstrapError = null;
      _authReady = true;
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
        petSessionController: _buildPetSessionController(database),
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        lifecycle.dispose();
        return;
      }

      await _disposePomogotchiState(clearDatabase: false);
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
          _isBootstrappingPomogotchi = false;
        });
      }
    }
  }

  Future<void> _disposePomogotchiState({required bool clearDatabase}) async {
    final controller = _controller;
    final lifecycle = _lifecycleService;
    _controller = null;
    _lifecycleService = null;
    controller?.dispose();
    lifecycle?.dispose();
    if (clearDatabase) {
      await _databaseOwner.clearForSignOut();
    }
  }

  Future<void> _requestMagicLink(String email) {
    return _authClient.requestMagicLink(email);
  }

  Future<void> _verifyEmailCode(String email, String code) {
    return _authClient.verifyEmailOtp(email: email, token: code);
  }

  Future<void> _signOut() async {
    await _authClient.signOut();
  }

  Future<void> _handleStatusBarMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'signOut':
        await _signOut();
        return;
      default:
        throw MissingPluginException('Unhandled method: ${call.method}');
    }
  }

  PetSessionController _buildPetSessionController(PowerSyncDatabase database) {
    final repository = PetSyncRepository(database);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return IosPetSessionController(repository: repository);
    }

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

    return MacosPetSessionController(
      repository: repository,
      narrativeAgent: narrativeAgent,
      petAgent: petAgent,
      animalLoader: () => discoverAnimalSpecs(rootBundle),
    );
  }

  @override
  void dispose() {
    if (_usesStatusBarSignOut) {
      _statusBarMenuChannel.setMethodCallHandler(null);
    }
    _authSubscription?.cancel();
    final controller = _controller;
    final lifecycle = _lifecycleService;
    _controller = null;
    _lifecycleService = null;
    controller?.dispose();
    lifecycle?.dispose();
    unawaited(_databaseOwner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pomogotchi')),
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

    if (!_authReady || _isBootstrappingPomogotchi) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final controller = _controller;
    if (controller == null) {
      return MagicLinkSignInScreen(
        onRequestMagicLink: _requestMagicLink,
        onVerifyEmailCode: _verifyEmailCode,
      );
    }

    return PomogotchiHome(controller: controller, onSignOut: _signOut);
  }
}
