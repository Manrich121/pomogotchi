import 'package:pomogotchi/features/pomodoro/data/schema/pomodoro_schema.dart';
import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_bio.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/session_phase.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

enum PetEventSource { macos, ios }

extension PetEventSourceX on PetEventSource {
  String get sqlValue {
    return switch (this) {
      PetEventSource.macos => 'macos',
      PetEventSource.ios => 'ios',
    };
  }

  static PetEventSource fromSql(String rawValue) {
    return switch (rawValue) {
      'macos' => PetEventSource.macos,
      'ios' => PetEventSource.ios,
      _ => throw FormatException('Unsupported pet event source: $rawValue'),
    };
  }
}

enum PetEventStatus { pending, processing, completed, failed }

extension PetEventStatusX on PetEventStatus {
  String get sqlValue {
    return switch (this) {
      PetEventStatus.pending => 'pending',
      PetEventStatus.processing => 'processing',
      PetEventStatus.completed => 'completed',
      PetEventStatus.failed => 'failed',
    };
  }

  static PetEventStatus fromSql(String rawValue) {
    return switch (rawValue) {
      'pending' => PetEventStatus.pending,
      'processing' => PetEventStatus.processing,
      'completed' => PetEventStatus.completed,
      'failed' => PetEventStatus.failed,
      _ => throw FormatException('Unsupported pet event status: $rawValue'),
    };
  }
}

class PetSyncSessionRecord {
  const PetSyncSessionRecord({
    required this.id,
    required this.animalId,
    required this.bioName,
    required this.bioSummary,
    required this.latestSpeech,
    required this.latestEventId,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String animalId;
  final String bioName;
  final String bioSummary;
  final String latestSpeech;
  final String? latestEventId;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnimalSpec get animalSpec =>
      AnimalSpec.fromAnimalAsset('assets/animals/$animalId.png');

  PetBio get bio => PetBio(name: bioName, summary: bioSummary);
}

class PetSyncEventRecord {
  const PetSyncEventRecord({
    required this.id,
    required this.petSessionId,
    required this.event,
    required this.source,
    required this.status,
    required this.reactionSpeech,
    required this.errorMessage,
    required this.createdAt,
    required this.claimedAt,
    required this.completedAt,
  });

  final String id;
  final String petSessionId;
  final PetEvent event;
  final PetEventSource source;
  final PetEventStatus status;
  final String? reactionSpeech;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? claimedAt;
  final DateTime? completedAt;
}

class PetSyncRepository {
  PetSyncRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase _database;
  final Uuid _uuid;

  Future<PetSyncSessionRecord?> loadCurrentPetSession() async {
    final row = await _database.getOptional('''
      SELECT * FROM $petSessionsTable
      ORDER BY updated_at DESC
      LIMIT 1
      ''');
    return row == null ? null : _sessionFromRow(row);
  }

  Stream<PetSyncSessionRecord?> watchCurrentPetSession() {
    return _database
        .watch('''
          SELECT * FROM $petSessionsTable
          ORDER BY updated_at DESC
          LIMIT 1
          ''')
        .map((rows) => rows.isEmpty ? null : _sessionFromRow(rows.first));
  }

  Stream<PetSyncEventRecord?> watchActiveEvent() {
    return _database
        .watch(
          '''
          SELECT * FROM $petEventsTable
          WHERE status IN (?, ?)
          ORDER BY created_at DESC
          LIMIT 1
          ''',
          parameters: [
            PetEventStatus.pending.sqlValue,
            PetEventStatus.processing.sqlValue,
          ],
        )
        .map((rows) => rows.isEmpty ? null : _eventFromRow(rows.first));
  }

  Future<PetSyncEventRecord?> loadActiveEvent() async {
    final row = await _database.getOptional(
      '''
      SELECT * FROM $petEventsTable
      WHERE status IN (?, ?)
      ORDER BY created_at DESC
      LIMIT 1
      ''',
      [PetEventStatus.pending.sqlValue, PetEventStatus.processing.sqlValue],
    );
    return row == null ? null : _eventFromRow(row);
  }

  Stream<List<PetSyncEventRecord>> watchPendingPetEvents() {
    return _database
        .watch(
          '''
          SELECT * FROM $petEventsTable
          WHERE status = ?
          ORDER BY created_at ASC
          ''',
          parameters: [PetEventStatus.pending.sqlValue],
        )
        .map((rows) => rows.map(_eventFromRow).toList(growable: false));
  }

  Future<PetSyncEventRecord?> loadOldestPendingPetEvent() async {
    final row = await _database.getOptional(
      '''
      SELECT * FROM $petEventsTable
      WHERE status = ?
      ORDER BY created_at ASC
      LIMIT 1
      ''',
      [PetEventStatus.pending.sqlValue],
    );
    return row == null ? null : _eventFromRow(row);
  }

  Future<PetSyncEventRecord?> loadPetEvent(String eventId) async {
    final row = await _database.getOptional(
      'SELECT * FROM $petEventsTable WHERE id = ?',
      [eventId],
    );
    return row == null ? null : _eventFromRow(row);
  }

  Stream<SessionPhase> watchCurrentPhase() {
    return _database
        .watch('''
          SELECT type
          FROM $sessionsTable
          WHERE state IN ('active', 'paused')
          ORDER BY started_at DESC
          LIMIT 1
          ''')
        .map((rows) {
          if (rows.isEmpty) {
            return SessionPhase.idle;
          }

          final type = (rows.first['type'] as String?) ?? 'focus';
          return type == 'break'
              ? SessionPhase.breakInProgress
              : SessionPhase.focusInProgress;
        });
  }

  Future<SessionPhase> loadCurrentPhase() async {
    final row = await _database.getOptional('''
      SELECT type
      FROM $sessionsTable
      WHERE state IN ('active', 'paused')
      ORDER BY started_at DESC
      LIMIT 1
      ''');
    if (row == null) {
      return SessionPhase.idle;
    }

    final type = (row['type'] as String?) ?? 'focus';
    return type == 'break'
        ? SessionPhase.breakInProgress
        : SessionPhase.focusInProgress;
  }

  Future<PetSyncSessionRecord> seedPetSession({
    required AnimalSpec animalSpec,
    required PetBio bio,
    required DateTime now,
  }) async {
    final existing = await loadCurrentPetSession();
    final recordId = existing?.id ?? _uuid.v4();
    final timestamp = now.toUtc().toIso8601String();

    await _database.writeTransaction((tx) async {
      if (existing == null) {
        await tx.execute(
          '''
          INSERT INTO $petSessionsTable (
            id, animal_id, bio_name, bio_summary, latest_speech,
            latest_event_id, last_error, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            recordId,
            animalSpec.id,
            bio.name,
            bio.summary,
            bio.summary,
            null,
            null,
            timestamp,
            timestamp,
          ],
        );
      } else {
        await tx.execute(
          '''
          UPDATE $petSessionsTable
          SET animal_id = ?,
              bio_name = ?,
              bio_summary = ?,
              latest_speech = ?,
              latest_event_id = NULL,
              last_error = NULL,
              updated_at = ?
          WHERE id = ?
          ''',
          [
            animalSpec.id,
            bio.name,
            bio.summary,
            bio.summary,
            timestamp,
            recordId,
          ],
        );
      }
    });

    return (await loadCurrentPetSession())!;
  }

  Future<PetSyncEventRecord> enqueueEvent({
    required PetEvent event,
    required PetEventSource source,
    required DateTime createdAt,
  }) async {
    final session = await loadCurrentPetSession();
    if (session == null) {
      throw StateError('Cannot enqueue a pet event before the pet is seeded.');
    }

    final id = _uuid.v4();
    await _database.execute(
      '''
      INSERT INTO $petEventsTable (
        id, pet_session_id, event_type, source_device, status,
        reaction_speech, error_message, created_at, claimed_at, completed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        session.id,
        event.wireValue,
        source.sqlValue,
        PetEventStatus.pending.sqlValue,
        null,
        null,
        createdAt.toUtc().toIso8601String(),
        null,
        null,
      ],
    );

    return (await loadPetEvent(id))!;
  }

  Future<void> markEventProcessing({
    required String eventId,
    required DateTime claimedAt,
  }) async {
    await _database.execute(
      '''
      UPDATE $petEventsTable
      SET status = ?, claimed_at = ?, error_message = NULL
      WHERE id = ? AND status = ?
      ''',
      [
        PetEventStatus.processing.sqlValue,
        claimedAt.toUtc().toIso8601String(),
        eventId,
        PetEventStatus.pending.sqlValue,
      ],
    );
  }

  Future<void> completeEvent({
    required String eventId,
    required String speech,
    required DateTime completedAt,
  }) async {
    final timestamp = completedAt.toUtc().toIso8601String();
    await _database.writeTransaction((tx) async {
      await tx.execute(
        '''
        UPDATE $petEventsTable
        SET status = ?, reaction_speech = ?, error_message = NULL, completed_at = ?
        WHERE id = ?
        ''',
        [PetEventStatus.completed.sqlValue, speech, timestamp, eventId],
      );
      await tx.execute(
        '''
        UPDATE $petSessionsTable
        SET latest_speech = ?,
            latest_event_id = ?,
            last_error = NULL,
            updated_at = ?
        WHERE id = (
          SELECT pet_session_id
          FROM $petEventsTable
          WHERE id = ?
        )
        ''',
        [speech, eventId, timestamp, eventId],
      );
    });
  }

  Future<void> failEvent({
    required String eventId,
    required String errorMessage,
    required DateTime completedAt,
  }) async {
    final timestamp = completedAt.toUtc().toIso8601String();
    await _database.writeTransaction((tx) async {
      await tx.execute(
        '''
        UPDATE $petEventsTable
        SET status = ?, error_message = ?, completed_at = ?
        WHERE id = ?
        ''',
        [PetEventStatus.failed.sqlValue, errorMessage, timestamp, eventId],
      );
      await tx.execute(
        '''
        UPDATE $petSessionsTable
        SET latest_event_id = ?, last_error = ?, updated_at = ?
        WHERE id = (
          SELECT pet_session_id
          FROM $petEventsTable
          WHERE id = ?
        )
        ''',
        [eventId, errorMessage, timestamp, eventId],
      );
    });
  }

  Future<void> reset() async {
    await _database.writeTransaction((tx) async {
      await tx.execute('DELETE FROM $petEventsTable');
      await tx.execute('DELETE FROM $petSessionsTable');
    });
  }

  PetSyncSessionRecord _sessionFromRow(Map<String, dynamic> row) {
    return PetSyncSessionRecord(
      id: row['id'] as String,
      animalId: row['animal_id'] as String,
      bioName: row['bio_name'] as String,
      bioSummary: row['bio_summary'] as String,
      latestSpeech: (row['latest_speech'] as String?) ?? '',
      latestEventId: row['latest_event_id'] as String?,
      lastError: row['last_error'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  }

  PetSyncEventRecord _eventFromRow(Map<String, dynamic> row) {
    return PetSyncEventRecord(
      id: row['id'] as String,
      petSessionId: row['pet_session_id'] as String,
      event: PetEvent.values.byName(
        _petEventNameFromWireValue(row['event_type'] as String),
      ),
      source: PetEventSourceX.fromSql(row['source_device'] as String),
      status: PetEventStatusX.fromSql(row['status'] as String),
      reactionSpeech: row['reaction_speech'] as String?,
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      claimedAt: _nullableDateTime(row['claimed_at']),
      completedAt: _nullableDateTime(row['completed_at']),
    );
  }

  DateTime? _nullableDateTime(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    return DateTime.parse(rawValue as String).toUtc();
  }

  String _petEventNameFromWireValue(String wireValue) {
    for (final event in PetEvent.values) {
      if (event.wireValue == wireValue) {
        return event.name;
      }
    }

    throw FormatException('Unsupported pet event type: $wireValue');
  }
}
