import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_bio.dart';
import 'package:pomogotchi/models/pet_reaction.dart';
import 'package:pomogotchi/models/pet_transcript_entry.dart';
import 'package:pomogotchi/models/session_phase.dart';

const _unset = Object();

class PetSession {
  const PetSession({
    required this.animal,
    required this.bio,
    required this.phase,
    required this.transcript,
    required this.latestReaction,
    required this.pendingSpeech,
    required this.isInitializing,
    required this.isGeneratingBio,
    required this.isThinking,
    required this.isStreaming,
    required this.errorMessage,
  });

  factory PetSession.initial() {
    return const PetSession(
      animal: null,
      bio: null,
      phase: SessionPhase.idle,
      transcript: [],
      latestReaction: null,
      pendingSpeech: '',
      isInitializing: false,
      isGeneratingBio: false,
      isThinking: false,
      isStreaming: false,
      errorMessage: null,
    );
  }

  final AnimalSpec? animal;
  final PetBio? bio;
  final SessionPhase phase;
  final List<PetTranscriptEntry> transcript;
  final PetReaction? latestReaction;
  final String pendingSpeech;
  final bool isInitializing;
  final bool isGeneratingBio;
  final bool isThinking;
  final bool isStreaming;
  final String? errorMessage;

  bool get hasActiveSession => animal != null && bio != null;

  bool get isBusy => isInitializing || isThinking || isStreaming;

  PetSession copyWith({
    Object? animal = _unset,
    Object? bio = _unset,
    SessionPhase? phase,
    List<PetTranscriptEntry>? transcript,
    Object? latestReaction = _unset,
    String? pendingSpeech,
    bool? isInitializing,
    bool? isGeneratingBio,
    bool? isThinking,
    bool? isStreaming,
    Object? errorMessage = _unset,
  }) {
    return PetSession(
      animal: animal == _unset ? this.animal : animal as AnimalSpec?,
      bio: bio == _unset ? this.bio : bio as PetBio?,
      phase: phase ?? this.phase,
      transcript: transcript ?? this.transcript,
      latestReaction: latestReaction == _unset
          ? this.latestReaction
          : latestReaction as PetReaction?,
      pendingSpeech: pendingSpeech ?? this.pendingSpeech,
      isInitializing: isInitializing ?? this.isInitializing,
      isGeneratingBio: isGeneratingBio ?? this.isGeneratingBio,
      isThinking: isThinking ?? this.isThinking,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
