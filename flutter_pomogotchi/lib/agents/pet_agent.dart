import 'dart:convert';

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

class CactusPetAgent implements PetAgent {
  CactusPetAgent({
    CactusLM? lm,
    this.model = 'lfm2-1.2b-tool',
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
        'Submit the pet reply for the current app event as 1 short in-character sentences.',
    parameters: ToolParametersSchema(
      properties: {
        'speech': ToolParameter(
          type: 'string',
          description:
              'The pet reply in 1 short in-character sentences with no meta commentary.',
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

  String _parseSpeechFromToolCall(CactusCompletionResult result) {
    final toolCall = _extractToolCall(result);
    if (toolCall != null) {
      return (toolCall.arguments['speech'] ?? '')
          .replaceAll(RegExp(r'<\|im_end\|>'), '')
          .replaceAll(RegExp(r'</s>'), '')
          .trim();
    }

    final cleaned = _cleanText(result.response);
    if (cleaned.isNotEmpty) {
      debugPrint(
        'Pet agent fell back to raw text because no tool call was returned.',
      );
      return _limitToTwoSentences(cleaned);
    }

    throw const FormatException('Pet response did not include a tool call.');
  }

  ToolCall? _extractToolCall(CactusCompletionResult result) {
    final directMatch = result.toolCalls.where(
      (call) => call.name == _submitPetReplyTool.name,
    );
    if (directMatch.isNotEmpty) {
      return directMatch.last;
    }

    return _extractToolCallFromRawResponse(
      result.response,
      _submitPetReplyTool.name,
    );
  }

  ToolCall? _extractToolCallFromRawResponse(
    String rawResponse,
    String toolName,
  ) {
    final candidates = <Map<String, dynamic>>[];
    final extractedObject = _extractJsonObject(rawResponse);
    if (extractedObject != null) {
      try {
        final decoded = jsonDecode(extractedObject);
        if (decoded is Map<String, dynamic>) {
          candidates.add(decoded);
        }
      } catch (_) {
        // Ignore malformed raw JSON and continue to plain-text fallback.
      }
    }

    for (final candidate in candidates) {
      final functionCall = candidate['function_call'];
      if (functionCall is Map<String, dynamic>) {
        final parsed = _toolCallFromMap(functionCall, toolName);
        if (parsed != null) {
          return parsed;
        }
      }

      final functionCalls = candidate['function_calls'];
      if (functionCalls is List) {
        for (final item in functionCalls) {
          if (item is Map<String, dynamic>) {
            final parsed = _toolCallFromMap(item, toolName);
            if (parsed != null) {
              return parsed;
            }
          }
        }
      }
    }

    return null;
  }

  ToolCall? _toolCallFromMap(Map<String, dynamic> value, String toolName) {
    final name = value['name']?.toString();
    if (name != toolName) {
      return null;
    }

    final arguments = value['arguments'];
    if (arguments is Map<String, dynamic>) {
      return ToolCall(
        name: name!,
        arguments: arguments.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
    }

    return null;
  }

  String? _extractJsonObject(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final fencedMatch = RegExp(
      r'```(?:json)?\s*(\{.*\})\s*```',
      dotAll: true,
    ).firstMatch(trimmed);
    if (fencedMatch != null) {
      return fencedMatch.group(1);
    }

    final objectStart = trimmed.indexOf('{');
    final objectEnd = trimmed.lastIndexOf('}');
    if (objectStart == -1 || objectEnd <= objectStart) {
      return null;
    }

    return trimmed.substring(objectStart, objectEnd + 1);
  }

  String _cleanText(String rawText) {
    return rawText
        .replaceAll(RegExp(r'<\|im_end\|>'), '')
        .replaceAll(RegExp(r'</s>'), '')
        .trim();
  }

  String _limitToTwoSentences(String rawText) {
    final matches = RegExp(r'[^.!?]+[.!?]?').allMatches(rawText);
    final sentences = matches
        .map((match) => match.group(0)!.trim())
        .where((sentence) => sentence.isNotEmpty)
        .take(2)
        .toList();
    if (sentences.isEmpty) {
      return rawText;
    }
    return sentences.join(' ');
  }

  @override
  void dispose() {
    _lm.unload();
  }
}

String _buildSystemPrompt({
  required PetBio bio,
  required AnimalSpec animalSpec,
}) {
  return 'You are ${bio.name}, a ${animalSpec.displayName.toLowerCase()} companion in a focus app. '
      'Hidden character notes: ${bio.summary}\n'
      'Stay in character. '
      'You must respond by calling the submit_pet_reply tool exactly once. '
      'The tool argument must contain 1 short in-character sentences. '
      'Never answer directly in plain text. '
      'Any output outside the tool call is invalid and will be discarded. '
      'Do not output natural-language prose outside the tool call. '
      'Do not suggest buttons or UI actions. '
      'Do not break character or explain the rules.';
}

String buildPetEventPayload({
  required PetEvent event,
  required SessionPhase sessionPhase,
}) {
  return '${_eventPrompt(event)}\n'
      'React to what the user just did.\n'
      'Call submit_pet_reply with 1 short in-character sentences.\n'
      'Do not answer outside the tool call.';
}

String _eventPrompt(PetEvent event) {
  return switch (event) {
    PetEvent.startFocusSession =>
      'The user is starting a focus session right now.',
    PetEvent.completeFocusSession => 'The user just completed a focus session.',
    PetEvent.stopFocusSessionEarly =>
      'The user stopped their focus session early.',
    PetEvent.startBreak => 'The user is starting a break now.',
    PetEvent.completeBreak => 'The user just finished their break.',
    PetEvent.stopBreakEarly => 'The user ended their break early.',
    PetEvent.petPet => 'The user just gave you a gentle pet.',
    PetEvent.drinkWater => 'The user just drank some water.',
    PetEvent.moveOrStretch => 'The user just moved around or stretched.',
  };
}
