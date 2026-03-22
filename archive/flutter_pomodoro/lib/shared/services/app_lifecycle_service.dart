import 'dart:async';

import 'package:flutter/widgets.dart';

abstract class AppLifecycleService {
  AppLifecycleState get currentState;
  Stream<AppLifecycleState> get stream;
}

class FlutterAppLifecycleService extends ChangeNotifier
    with WidgetsBindingObserver
    implements AppLifecycleService {
  FlutterAppLifecycleService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final StreamController<AppLifecycleState> _controller =
      StreamController<AppLifecycleState>.broadcast();
  AppLifecycleState _state = AppLifecycleState.resumed;

  @override
  AppLifecycleState get currentState => _state;

  @override
  Stream<AppLifecycleState> get stream => _controller.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    _controller.add(state);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
    super.dispose();
  }
}
