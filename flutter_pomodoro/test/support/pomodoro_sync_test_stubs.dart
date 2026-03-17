import 'dart:async';

import 'package:flutter_pomodoro/features/pomodoro/data/pomodoro_sync.dart';

class RecordedRestOperation {
  const RecordedRestOperation({
    required this.kind,
    required this.table,
    this.id,
    this.data,
  });

  final String kind;
  final String table;
  final String? id;
  final Map<String, dynamic>? data;
}

class RecordingRestClient implements PomodoroRestClient {
  final List<RecordedRestOperation> operations = [];

  @override
  PomodoroRestTable from(String table) {
    return _RecordingRestTable(table, operations);
  }
}

class _RecordingRestTable implements PomodoroRestTable {
  _RecordingRestTable(this._table, this._operations);

  final String _table;
  final List<RecordedRestOperation> _operations;

  @override
  Future<void> upsert(Map<String, dynamic> data) async {
    _operations.add(
      RecordedRestOperation(
        kind: 'upsert',
        table: _table,
        data: Map<String, dynamic>.from(data),
      ),
    );
  }

  @override
  Future<void> update(Map<String, dynamic> data, {required String id}) async {
    _operations.add(
      RecordedRestOperation(
        kind: 'update',
        table: _table,
        id: id,
        data: Map<String, dynamic>.from(data),
      ),
    );
  }

  @override
  Future<void> delete({required String id}) async {
    _operations.add(
      RecordedRestOperation(kind: 'delete', table: _table, id: id),
    );
  }
}

class FakePomodoroAuthClient implements PomodoroAuthClient {
  FakePomodoroAuthClient({
    RecordingRestClient? restClient,
    PomodoroAuthSession? currentSession,
    bool isLoggedIn = false,
  }) : _restClient = restClient ?? RecordingRestClient(),
       _currentSession = currentSession,
       _isLoggedIn = isLoggedIn || currentSession != null;

  final StreamController<PomodoroAuthEvent> _controller =
      StreamController<PomodoroAuthEvent>.broadcast();
  final RecordingRestClient _restClient;

  PomodoroAuthSession? _currentSession;
  bool _isLoggedIn;
  int initializeCalls = 0;
  int signInCalls = 0;
  int refreshCalls = 0;

  @override
  Stream<PomodoroAuthEvent> get authStateChanges => _controller.stream;

  @override
  PomodoroAuthSession? get currentSession => _currentSession;

  @override
  String? get currentUserId => _currentSession?.userId;

  @override
  bool get isLoggedIn => _isLoggedIn;

  @override
  PomodoroRestClient get restClient => _restClient;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<void> refreshSession() async {
    refreshCalls += 1;
  }

  @override
  Future<void> signInAnonymously() async {
    signInCalls += 1;
    _isLoggedIn = true;
    _currentSession ??= const PomodoroAuthSession(
      accessToken: 'anon-token',
      userId: 'anon-user',
    );
  }

  void emit(
    PomodoroAuthEvent event, {
    PomodoroAuthSession? session,
    bool? isLoggedIn,
  }) {
    _currentSession = session ?? _currentSession;
    _isLoggedIn = isLoggedIn ?? _isLoggedIn;
    _controller.add(event);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
