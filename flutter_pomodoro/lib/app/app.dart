import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/app/theme/app_theme.dart';
import 'package:flutter_pomodoro/features/auth/presentation/magic_link_sign_in_screen.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_controller.dart';
import 'package:flutter_pomodoro/features/pomodoro/data/pomodoro_database.dart';
import 'package:flutter_pomodoro/features/pomodoro/data/pomodoro_sync.dart';
import 'package:flutter_pomodoro/features/pomodoro/data/powersync_pomodoro_repository.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/screens/pomodoro_screen.dart';
import 'package:flutter_pomodoro/shared/services/app_clock.dart';
import 'package:flutter_pomodoro/shared/services/app_lifecycle_service.dart';

class PomogotchiApp extends StatelessWidget {
  const PomogotchiApp({super.key, this.databaseOwner, this.authClient});

  final PomodoroDatabaseOwner? databaseOwner;
  final PomodoroAuthClient? authClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomogotchi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _PomogotchiBootstrap(
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
  late final PomodoroDatabaseOwner _databaseOwner;
  late final PomodoroAuthClient _authClient;
  FlutterAppLifecycleService? _lifecycleService;
  PomodoroController? _controller;
  StreamSubscription<PomodoroAuthEvent>? _authSubscription;
  Object? _bootstrapError;
  bool _authReady = false;
  bool _isBootstrappingPomodoro = false;

  @override
  void initState() {
    super.initState();
    _databaseOwner = widget.databaseOwner ?? PomodoroDatabaseOwner();
    _authClient = widget.authClient ?? pomodoroAuthClient;
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      await _authClient.initialize();
      await _authSubscription?.cancel();
      _authSubscription = _authClient.authStateChanges.listen((event) {
        unawaited(_handleAuthEvent(event));
      });
      if (_authClient.isLoggedIn) {
        await _bootstrapPomodoro();
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
        await _bootstrapPomodoro();
      }
      return;
    }

    if (event == PomodoroAuthEvent.signedOut) {
      await _disposePomodoroState(clearDatabase: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _authReady = true;
        _bootstrapError = null;
      });
    }
  }

  Future<void> _bootstrapPomodoro() async {
    if (_isBootstrappingPomodoro) {
      return;
    }

    setState(() {
      _isBootstrappingPomodoro = true;
      _bootstrapError = null;
      _authReady = true;
    });

    try {
      final database = await _databaseOwner.initialize();
      final lifecycle = FlutterAppLifecycleService();
      final controller = PomodoroController(
        repository: PowerSyncPomodoroRepository(database),
        clock: const SystemAppClock(),
        lifecycleService: lifecycle,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        lifecycle.dispose();
        return;
      }
      await _disposePomodoroState(clearDatabase: false);
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
          _isBootstrappingPomodoro = false;
        });
      }
    }
  }

  Future<void> _disposePomodoroState({required bool clearDatabase}) async {
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    final controller = _controller;
    final lifecycle = _lifecycleService;
    _controller = null;
    _lifecycleService = null;
    controller?.dispose();
    lifecycle?.dispose();
    _databaseOwner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pomogotchi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Initialization failed: $_bootstrapError',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_authReady || _isBootstrappingPomodoro) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final controller = _controller;
    if (controller == null) {
      return MagicLinkSignInScreen(
        onRequestMagicLink: _requestMagicLink,
        onVerifyEmailCode: _verifyEmailCode,
      );
    }

    return PomodoroScreen(controller: controller, onSignOut: _signOut);
  }
}
