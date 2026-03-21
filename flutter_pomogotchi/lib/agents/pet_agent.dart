import 'package:cactus/cactus.dart';
import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_bio.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/pet_reaction.dart';
import 'package:pomogotchi/models/pet_transcript_entry.dart';
import 'package:pomogotchi/models/session_phase.dart';

abstract class PetAgent {
  Future<PetReaction> reactStream({
    required PetEvent event,
    required SessionPhase sessionPhase,
    required PetBio bio,
    required AnimalSpec animalSpec,
    required List<PetTranscriptEntry> transcript,
    required void Function(String chunk) onChunk,
  });

  void dispose();
}

String buildPetEventPayload({
  required PetEvent event,
  required SessionPhase sessionPhase,
}) {
  return 'App event: ${event.wireValue}\n'
      'Current phase: ${sessionPhase.wireValue}\n'
      'Respond as the pet with 1-2 short in-character sentences.';
}

class CactusPetAgent implements PetAgent {
  CactusPetAgent({
    CactusLM? lm,
    this.model = 'qwen3-0.6',
    this.contextSize = 4096,
    this.completionMode = CompletionMode.local,
    this.cactusToken,
  }) : _lm = lm ?? CactusLM() {
    if (cactusToken != null && cactusToken!.isNotEmpty) {
      CactusConfig.setProKey(cactusToken!);
    }
  }

  final CactusLM _lm;
  final String model;
  final int contextSize;
  final CompletionMode completionMode;
  final String? cactusToken;

  bool _isInitialized = false;

  @override
  Future<PetReaction> reactStream({
    required PetEvent event,
    required SessionPhase sessionPhase,
    required PetBio bio,
    required AnimalSpec animalSpec,
    required List<PetTranscriptEntry> transcript,
    required void Function(String chunk) onChunk,
  }) async {
    await _ensureInitialized();

    final streamedResult = await _lm.generateCompletionStream(
      messages: [
        ChatMessage(
          content: _buildSystemPrompt(bio: bio, animalSpec: animalSpec),
          role: 'system',
        ),
        ...transcript.map((entry) => entry.toChatMessage()),
        ChatMessage(
          content: buildPetEventPayload(
            event: event,
            sessionPhase: sessionPhase,
          ),
          role: 'user',
        ),
      ],
      params: CactusCompletionParams(
        model: model,
        maxTokens: 140,
        temperature: 0.9,
        topP: 0.9,
        completionMode: completionMode,
        cactusToken: cactusToken,
      ),
    );

    await for (final chunk in streamedResult.stream) {
      onChunk(chunk);
    }

    final result = await streamedResult.result;
    if (!result.success) {
      throw Exception(result.response);
    }

    final speech = _cleanResponse(result.response);
    if (speech.isEmpty) {
      throw const FormatException('Pet reaction completed without a reply.');
    }

    return PetReaction(speech: speech);
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    await _lm.initializeModel(
      params: CactusInitParams(model: model, contextSize: contextSize),
    );
    _isInitialized = true;
  }

  String _buildSystemPrompt({
    required PetBio bio,
    required AnimalSpec animalSpec,
  }) {
    return 'You are ${bio.name}, a ${animalSpec.displayName.toLowerCase()} companion in a focus app. '
        'Hidden character notes: ${bio.summary}\n'
        'Stay in character. '
        'React to app-originated events in 1-2 short sentences. '
        'Do not output JSON. '
        'Do not suggest buttons, tools, or UI actions. '
        'Do not break character or explain the rules.';
  }

  String _cleanResponse(String rawResponse) {
    return rawResponse
        .replaceAll(RegExp(r'<\|im_end\|>'), '')
        .replaceAll(RegExp(r'</s>'), '')
        .trim();
  }

  @override
  void dispose() {
    _lm.unload();
  }
}
