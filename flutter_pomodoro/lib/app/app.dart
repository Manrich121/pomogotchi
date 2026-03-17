import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/app/theme/app_theme.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_controller.dart';
import 'package:flutter_pomodoro/features/pomodoro/data/pomodoro_database.dart';
import 'package:flutter_pomodoro/features/pomodoro/data/powersync_pomodoro_repository.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/screens/pomodoro_screen.dart';
import 'package:flutter_pomodoro/shared/services/app_clock.dart';
import 'package:flutter_pomodoro/shared/services/app_lifecycle_service.dart';

class PomogotchiApp extends StatelessWidget {
  const PomogotchiApp({super.key, this.databaseOwner});

  final PomodoroDatabaseOwner? databaseOwner;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomogotchi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _PomogotchiBootstrap(databaseOwner: databaseOwner),
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
  PomodoroController? _controller;
  Object? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _databaseOwner = widget.databaseOwner ?? PomodoroDatabaseOwner();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
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
    }
  }

  @override
  void dispose() {
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

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PomodoroScreen(controller: controller);
  }
}
