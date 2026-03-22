import 'dart:async';

import 'package:pomogotchi/features/pomodoro/data/pomodoro_database.dart';
import 'package:pomogotchi/features/pomodoro/data/pomodoro_sync.dart';
import 'package:powersync/powersync.dart';

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
  int requestMagicLinkCalls = 0;
  int verifyEmailOtpCalls = 0;
  int signOutCalls = 0;
  int refreshCalls = 0;
  String? lastMagicLinkEmail;
  String? lastVerifiedEmail;
  String? lastVerifiedToken;

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
  Future<void> requestMagicLink(String email) async {
    requestMagicLinkCalls += 1;
    lastMagicLinkEmail = email;
  }

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    verifyEmailOtpCalls += 1;
    lastVerifiedEmail = email;
    lastVerifiedToken = token;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _isLoggedIn = false;
    _currentSession = null;
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

class PendingPomodoroDatabaseOwner extends PomodoroDatabaseOwner {
  PendingPomodoroDatabaseOwner();

  final Completer<PowerSyncDatabase> _initializeCompleter =
      Completer<PowerSyncDatabase>();

  @override
  Future<PowerSyncDatabase> initialize() => _initializeCompleter.future;
}
