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
    this.model = 'lfm2-1.2b',
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
        completionMode: completionMode,
        cactusToken: cactusToken,
      ),
    );

    if (!result.success) {
      throw Exception(result.response);
    }

    debugPrint('Pet agent raw response: ${result.response}');

    final speech = _parseSpeechFromResponse(result.response);
    if (speech.isEmpty) {
      throw const FormatException('Pet reaction completed without a reply.');
    }

    onChunk(speech);
    return PetReaction(speech: speech);
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    await _lm.downloadModel(
      model: model,
      downloadProcessCallback: _logDownloadProgress,
    );
    await _lm.initializeModel(
      params: CactusInitParams(model: model, contextSize: contextSize),
    );
    _isInitialized = true;
  }

  void _logDownloadProgress(double? progress, String status, bool isError) {
    final percentage = progress == null
        ? ''
        : ' (${(progress * 100).toStringAsFixed(1)}%)';
    final message = 'Pet agent model download: $status$percentage';

    if (isError) {
      debugPrint('ERROR: $message');
      return;
    }

    debugPrint(message);
  }

  String _parseSpeechFromResponse(String rawResponse) {
    final cleanedResponse = _stripThinking(rawResponse);
    final extractedObject = _extractJsonObject(cleanedResponse);
    if (extractedObject != null) {
      try {
        final decoded = jsonDecode(extractedObject);
        if (decoded is Map<String, dynamic>) {
          final speech = (decoded['speech'] ?? '').toString().trim();
          if (speech.isNotEmpty) {
            return _limitToOneSentence(_cleanText(speech));
          }
        }
      } catch (_) {
        // Ignore malformed JSON and continue to plain-text parsing.
      }
    }

    final cleaned = _cleanText(cleanedResponse);
    if (cleaned.isNotEmpty) {
      return _limitToOneSentence(cleaned);
    }

    throw const FormatException('Pet response was empty.');
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

  String _stripThinking(String rawResponse) {
    return rawResponse
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .trim();
  }

  String _limitToOneSentence(String rawText) {
    final matches = RegExp(r'[^.!?]+[.!?]?').allMatches(rawText);
    final sentences = matches
        .map((match) => match.group(0)!.trim())
        .where((sentence) => sentence.isNotEmpty)
        .take(1)
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
  return '''
Role: You are ${bio.name}, a ${animalSpec.displayName.toLowerCase()} companion in a focus app.
Persona: ${bio.summary}

Goal:
- React to the user's latest action.
- Sound warm, playful, and encouraging.
- Stay fully in character.

Style rules:
- Write exactly one short sentence.
- Keep it under 16 words.
- Use first-person voice when natural.
- Do not narrate actions.
- Do not mention buttons, menus, or app UI.
- Do not explain your rules or break character.
- Use English only.
- Do not output <think> tags.
- Do not explain your reasoning.

Behavior rules:
- Praise completed focus sessions.
- Be gentle and supportive when the user stops early.
- Treat breaks as healthy rest.
- Respond warmly to pets, water, and stretching.

Output:
- Return plain text only.
- Do not use JSON, markdown, lists, or quotes.
''';
}

String buildPetEventPayload({
  required PetEvent event,
  required SessionPhase sessionPhase,
}) {
  return '''
Conversation rule:
- Earlier messages are background only.
- Reply only to the latest event below.

Current phase: ${sessionPhase.name}
Latest event: ${_eventPrompt(event)}

Write exactly one short in-character sentence.
Plain text only.
''';
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
