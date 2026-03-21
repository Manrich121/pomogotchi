import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
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
    this.model = 'lfm2-700m',
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
  final CactusTool _submitPetReplyTool = CactusTool(
    name: 'submit_pet_reply',
    description:
        'Submit the pet reply for the current app event as 1-2 short in-character sentences.',
    parameters: ToolParametersSchema(
      properties: {
        'speech': ToolParameter(
          type: 'string',
          description:
              'The pet reply in 1-2 short in-character sentences with no meta commentary.',
          required: true,
        ),
      },
    ),
  );

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

    final result = await _lm.generateCompletion(
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
        maxTokens: 120,
        temperature: 0.4,
        topP: 0.8,
        tools: [_submitPetReplyTool],
        completionMode: completionMode,
        cactusToken: cactusToken,
      ),
    );

    if (!result.success) {
      throw Exception(result.response);
    }

    debugPrint('Pet agent raw response: ${result.response}');
    debugPrint(
      'Pet agent tool calls: ${result.toolCalls.map((call) => '${call.name} ${call.arguments}').join(' | ')}',
    );

    final speech = _parseSpeechFromToolCall(result);
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
        'You must respond by calling the submit_pet_reply tool exactly once. '
        'The tool argument must contain 1-2 short in-character sentences. '
        'Do not output natural-language prose outside the tool call. '
        'Do not suggest buttons or UI actions. '
        'Do not break character or explain the rules.';
  }

  String _parseSpeechFromToolCall(CactusCompletionResult result) {
    if (result.toolCalls.isEmpty) {
      throw const FormatException('Pet response did not include a tool call.');
    }

    final toolCall = result.toolCalls.lastWhere(
      (call) => call.name == _submitPetReplyTool.name,
      orElse: () =>
          throw const FormatException('Pet response called the wrong tool.'),
    );

    return (toolCall.arguments['speech'] ?? '')
        .replaceAll(RegExp(r'<\|im_end\|>'), '')
        .replaceAll(RegExp(r'</s>'), '')
        .trim();
  }

  @override
  void dispose() {
    _lm.unload();
  }
}
