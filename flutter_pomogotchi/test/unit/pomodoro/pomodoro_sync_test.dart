import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pomogotchi/features/pomodoro/data/pomodoro_sync.dart';
import 'package:pomogotchi/features/pomodoro/data/schema/pomodoro_schema.dart';
import 'package:powersync/powersync.dart';

import '../../support/pomogotchi_sync_test_stubs.dart';

final _runPowerSyncDatabaseTests =
    Platform.environment['RUN_POWERSYNC_DB_TESTS'] == '1';
const _powerSyncDatabaseSkipReason =
    'Requires the PowerSync native test runtime. Set RUN_POWERSYNC_DB_TESTS=1 after installing libpowersync.dylib.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PomodoroSyncCoordinator', () {
    test(
      'attaches and detaches database sync on auth changes',
      () async {
        final authClient = FakePomodoroAuthClient();
        final tempDir = await Directory.systemTemp.createTemp('pomodoro-sync');
        final database = PowerSyncDatabase(
          schema: pomodoroSchema,
          path: p.join(tempDir.path, 'sync.db'),
        );
        await database.initialize();

        final connectCalls = <PowerSyncBackendConnector>[];
        var disconnectCalls = 0;
        final coordinator = PomodoroSyncCoordinator(
          authClient: authClient,
          connectDatabase: (db, connector, options) {
            expect(db, same(database));
            expect(options, pomodoroSyncOptions);
            connectCalls.add(connector);
          },
          disconnectDatabase: (db) {
            expect(db, same(database));
            disconnectCalls += 1;
          },
        );

        try {
          await coordinator.attach(database);

          expect(authClient.initializeCalls, 1);
          expect(connectCalls, isEmpty);

          authClient.emit(
            PomodoroAuthEvent.signedIn,
            session: const PomodoroAuthSession(
              accessToken: 'fresh-token',
              userId: 'fresh-user',
            ),
            isLoggedIn: true,
          );
          await Future<void>.delayed(Duration.zero);
          expect(connectCalls, hasLength(1));

          authClient.emit(PomodoroAuthEvent.signedOut, isLoggedIn: false);
          await Future<void>.delayed(Duration.zero);
          expect(disconnectCalls, 1);
        } finally {
          await coordinator.dispose();
          await authClient.dispose();
          await database.close();
          await tempDir.delete(recursive: true);
        }
      },
      skip: _runPowerSyncDatabaseTests ? false : _powerSyncDatabaseSkipReason,
    );
  });

  group('PomodoroSupabaseConnector', () {
    test(
      'maps queued CRUD operations to REST operations',
      () async {
        final restClient = RecordingRestClient();
        final authClient = FakePomodoroAuthClient(
          restClient: restClient,
          currentSession: const PomodoroAuthSession(
            accessToken: 'test-token',
            userId: 'user-1',
          ),
        );
        final connector = PomodoroSupabaseConnector(authClient);
        final tempDir = await Directory.systemTemp.createTemp(
          'pomodoro-upload',
        );
        final database = PowerSyncDatabase(
          schema: pomodoroSchema,
          path: p.join(tempDir.path, 'upload.db'),
        );
        await database.initialize();

        try {
          await database.execute(
            '''
          INSERT INTO $sessionsTable (
            id, day_key, type, planned_duration_seconds, state, outcome,
            started_at, last_resumed_at, paused_at, ended_at, remaining_seconds_at_pause
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
            [
              'session-1',
              '2026-01-01',
              'focus',
              1500,
              'active',
              null,
              '2026-01-01T09:00:00.000Z',
              '2026-01-01T09:00:00.000Z',
              null,
              null,
              null,
            ],
          );
          await connector.uploadData(database);

          expect(restClient.operations, hasLength(1));
          expect(restClient.operations.first.kind, 'upsert');
          expect(restClient.operations.first.table, sessionsTable);
          expect(restClient.operations.first.data?['id'], 'session-1');

          await database.execute(
            '''
          UPDATE $sessionsTable
          SET state = ?, paused_at = ?, remaining_seconds_at_pause = ?
          WHERE id = ?
          ''',
            ['paused', '2026-01-01T09:05:00.000Z', 1200, 'session-1'],
          );
          await connector.uploadData(database);

          expect(restClient.operations, hasLength(2));
          expect(restClient.operations[1].kind, 'update');
          expect(restClient.operations[1].id, 'session-1');
          expect(restClient.operations[1].data?['state'], 'paused');

          await database.execute('DELETE FROM $sessionsTable WHERE id = ?', [
            'session-1',
          ]);
          await connector.uploadData(database);

          expect(restClient.operations, hasLength(3));
          expect(restClient.operations[2].kind, 'delete');
          expect(restClient.operations[2].id, 'session-1');
        } finally {
          await authClient.dispose();
          await database.close();
          await tempDir.delete(recursive: true);
        }
      },
      skip: _runPowerSyncDatabaseTests ? false : _powerSyncDatabaseSkipReason,
    );
  });
}
