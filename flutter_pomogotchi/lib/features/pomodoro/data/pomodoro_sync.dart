import 'dart:async';

import 'package:logging/logging.dart';
import 'package:pomogotchi/app_config.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('pomogotchi-powersync');

final List<RegExp> fatalResponseCodes = [
  RegExp(r'^22...$'),
  RegExp(r'^23...$'),
  RegExp(r'^42501$'),
];

const pomodoroSyncOptions = SyncOptions(
  syncImplementation: SyncClientImplementation.rust,
);

enum PomodoroAuthEvent { signedIn, signedOut, tokenRefreshed }

class PomodoroAuthSession {
  const PomodoroAuthSession({
    required this.accessToken,
    required this.userId,
    this.expiresAt,
  });

  final String accessToken;
  final String userId;
  final DateTime? expiresAt;
}

abstract class PomodoroRestTable {
  Future<void> upsert(Map<String, dynamic> data);

  Future<void> update(Map<String, dynamic> data, {required String id});

  Future<void> delete({required String id});
}

abstract class PomodoroRestClient {
  PomodoroRestTable from(String table);
}

abstract class PomodoroAuthClient {
  Future<void> initialize();

  bool get isLoggedIn;

  PomodoroAuthSession? get currentSession;

  String? get currentUserId;

  Stream<PomodoroAuthEvent> get authStateChanges;

  PomodoroRestClient get restClient;

  Future<void> requestMagicLink(String email);

  Future<void> verifyEmailOtp({required String email, required String token});

  Future<void> signOut();

  Future<void> refreshSession();
}

class SupabasePomodoroAuthClient implements PomodoroAuthClient {
  static Future<void>? _initializeFuture;

  @override
  Future<void> initialize() {
    return _initializeFuture ??= Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  @override
  bool get isLoggedIn =>
      Supabase.instance.client.auth.currentSession?.accessToken != null;

  @override
  PomodoroAuthSession? get currentSession {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return null;
    }

    return PomodoroAuthSession(
      accessToken: session.accessToken,
      userId: session.user.id,
      expiresAt: session.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
    );
  }

  @override
  String? get currentUserId =>
      Supabase.instance.client.auth.currentSession?.user.id;

  @override
  Stream<PomodoroAuthEvent> get authStateChanges => Supabase
      .instance
      .client
      .auth
      .onAuthStateChange
      .where((data) {
        return data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.signedOut ||
            data.event == AuthChangeEvent.tokenRefreshed;
      })
      .map((data) {
        switch (data.event) {
          case AuthChangeEvent.signedIn:
            return PomodoroAuthEvent.signedIn;
          case AuthChangeEvent.signedOut:
            return PomodoroAuthEvent.signedOut;
          case AuthChangeEvent.tokenRefreshed:
            return PomodoroAuthEvent.tokenRefreshed;
          default:
            throw StateError('Unsupported auth event: ${data.event}');
        }
      });

  @override
  PomodoroRestClient get restClient =>
      SupabaseRestClientAdapter(Supabase.instance.client.rest);

  @override
  Future<void> requestMagicLink(String email) async {
    _log.info('Requesting magic link for $email');
    await Supabase.instance.client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: AppConfig.authRedirectUrl,
      shouldCreateUser: true,
    );
  }

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    _log.info('Verifying email OTP for $email');
    await Supabase.instance.client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  @override
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Future<void> refreshSession() async {
    await Supabase.instance.client.auth.refreshSession();
  }
}

class SupabaseRestClientAdapter implements PomodoroRestClient {
  SupabaseRestClientAdapter(this._client);

  final PostgrestClient _client;

  @override
  PomodoroRestTable from(String table) {
    return SupabaseRestTableAdapter(_client.from(table));
  }
}

class SupabaseRestTableAdapter implements PomodoroRestTable {
  SupabaseRestTableAdapter(this._table);

  final dynamic _table;

  @override
  Future<void> upsert(Map<String, dynamic> data) async {
    await _table.upsert(data);
  }

  @override
  Future<void> update(Map<String, dynamic> data, {required String id}) async {
    await _table.update(data).eq('id', id);
  }

  @override
  Future<void> delete({required String id}) async {
    await _table.delete().eq('id', id);
  }
}

final PomodoroAuthClient pomodoroAuthClient = SupabasePomodoroAuthClient();

String? currentPomodoroUserId() => pomodoroAuthClient.currentUserId;

class PomodoroSupabaseConnector extends PowerSyncBackendConnector {
  PomodoroSupabaseConnector(this._authClient);

  final PomodoroAuthClient _authClient;
  Future<void>? _refreshFuture;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    await _refreshFuture;

    final session = _authClient.currentSession;
    if (session == null) {
      return null;
    }

    return PowerSyncCredentials(
      endpoint: AppConfig.powersyncUrl,
      token: session.accessToken,
      userId: session.userId,
      expiresAt: session.expiresAt,
    );
  }

  @override
  void invalidateCredentials() {
    _refreshFuture = _authClient
        .refreshSession()
        .timeout(const Duration(seconds: 5))
        .then((_) => null, onError: (_) => null);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    CrudEntry? lastOp;
    try {
      for (final op in transaction.crud) {
        lastOp = op;
        final table = _authClient.restClient.from(op.table);
        if (op.op == UpdateType.put) {
          final data = Map<String, dynamic>.of(op.opData!);
          data['id'] = op.id;
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!, id: op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete(id: op.id);
        }
      }

      await transaction.complete();
    } on PostgrestException catch (error) {
      if (error.code != null &&
          fatalResponseCodes.any((re) => re.hasMatch(error.code!))) {
        _log.severe(
          'Discarding unrecoverable upload transaction for $lastOp',
          error,
        );
        await transaction.complete();
        return;
      }

      rethrow;
    }
  }
}

typedef PomodoroDatabaseConnect =
    FutureOr<void> Function(
      PowerSyncDatabase database,
      PowerSyncBackendConnector connector,
      SyncOptions options,
    );

typedef PomodoroDatabaseDisconnect =
    FutureOr<void> Function(PowerSyncDatabase database);

class PomodoroSyncCoordinator {
  PomodoroSyncCoordinator({
    PomodoroAuthClient? authClient,
    PomodoroDatabaseConnect? connectDatabase,
    PomodoroDatabaseDisconnect? disconnectDatabase,
  }) : _authClient = authClient ?? pomodoroAuthClient,
       _connectDatabase = connectDatabase ?? _defaultConnectDatabase,
       _disconnectDatabase = disconnectDatabase ?? _defaultDisconnectDatabase;

  final PomodoroAuthClient _authClient;
  final PomodoroDatabaseConnect _connectDatabase;
  final PomodoroDatabaseDisconnect _disconnectDatabase;

  StreamSubscription<PomodoroAuthEvent>? _authSubscription;
  PomodoroSupabaseConnector? _connector;

  Future<void> attach(PowerSyncDatabase database) async {
    await _authClient.initialize();
    if (_authClient.isLoggedIn) {
      _connector = PomodoroSupabaseConnector(_authClient);
      await _connectDatabase(database, _connector!, pomodoroSyncOptions);
    }

    await _authSubscription?.cancel();
    _authSubscription = _authClient.authStateChanges.listen((event) {
      unawaited(_handleAuthEvent(database, event));
    });
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    _connector = null;
  }

  Future<void> _handleAuthEvent(
    PowerSyncDatabase database,
    PomodoroAuthEvent event,
  ) async {
    if (event == PomodoroAuthEvent.signedIn) {
      _connector = PomodoroSupabaseConnector(_authClient);
      await _connectDatabase(database, _connector!, pomodoroSyncOptions);
      return;
    }

    if (event == PomodoroAuthEvent.signedOut) {
      _connector = null;
      await _disconnectDatabase(database);
      return;
    }

    _connector?.prefetchCredentials();
  }

  static FutureOr<void> _defaultConnectDatabase(
    PowerSyncDatabase database,
    PowerSyncBackendConnector connector,
    SyncOptions options,
  ) {
    return database.connect(connector: connector, options: options);
  }

  static FutureOr<void> _defaultDisconnectDatabase(
    PowerSyncDatabase database,
  ) {
    return database.disconnect();
  }
}
