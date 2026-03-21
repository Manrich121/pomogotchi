import 'dart:convert';

import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_bio.dart';

abstract class NarrativeAgent {
  Future<PetBio> generateBio(AnimalSpec animalSpec);

  void dispose();
}

class CactusNarrativeAgent implements NarrativeAgent {
  CactusNarrativeAgent({
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
  final CactusTool _submitPetBioTool = CactusTool(
    name: 'submit_pet_bio',
    description: 'Submit the hidden pet bio for this focus companion session.',
    parameters: ToolParametersSchema(
      properties: {
        'name': ToolParameter(
          type: 'string',
          description: 'A one-word pet name.',
          required: true,
        ),
        'summary': ToolParameter(
          type: 'string',
          description:
              'A brief summary describing the specific animal personality or vibe.',
          required: true,
        ),
      },
    ),
  );

  bool _isInitialized = false;

  @override
  Future<PetBio> generateBio(AnimalSpec animalSpec) async {
    await _ensureInitialized();

    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final result = await _lm.generateCompletion(
          messages: [
            ChatMessage(content: _buildSystemPrompt(), role: 'system'),
            ChatMessage(content: _buildPrompt(animalSpec), role: 'user'),
          ],
          params: CactusCompletionParams(
            model: model,
            maxTokens: 120,
            temperature: 0.3,
            topP: 0.8,
            tools: [_submitPetBioTool],
            completionMode: completionMode,
            cactusToken: cactusToken,
          ),
        );

        if (!result.success) {
          throw Exception(result.response);
        }

        debugPrint(
          'Narrative agent raw response (attempt ${attempt + 1}): ${result.response}',
        );
        debugPrint(
          'Narrative agent tool calls (attempt ${attempt + 1}): ${result.toolCalls.map((call) => '${call.name} ${call.arguments}').join(' | ')}',
        );
        return _parseBioFromToolCall(result);
      } catch (error) {
        debugPrint(
          'Narrative agent bio generation failed on attempt ${attempt + 1}: $error',
        );
        lastError = error;
      }
    }

    throw Exception('Failed to generate a usable pet bio: $lastError');
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

  PetBio _parseBioFromToolCall(CactusCompletionResult result) {
    final toolCall = _extractToolCall(result);
    if (toolCall == null) {
      throw const FormatException(
        'Narrative response did not include a tool call.',
      );
    }

    final name = (toolCall.arguments['name'] ?? '').trim();
    final summary = (toolCall.arguments['summary'] ?? '').trim();

    if (name.isEmpty || name.contains(RegExp(r'\s'))) {
      throw const FormatException(
        'Narrative response returned an invalid name.',
      );
    }

    if (summary.isEmpty) {
      throw const FormatException(
        'Narrative response returned an empty summary.',
      );
    }

    return PetBio(name: name, summary: summary);
  }

  ToolCall? _extractToolCall(CactusCompletionResult result) {
    final directMatch = result.toolCalls.where(
      (call) => call.name == _submitPetBioTool.name,
    );
    if (directMatch.isNotEmpty) {
      return directMatch.last;
    }

    final rawToolCall = _extractToolCallFromRawResponse(
      result.response,
      _submitPetBioTool.name,
    );
    if (rawToolCall != null) {
      debugPrint('Narrative agent recovered tool call from raw response.');
    }

    return rawToolCall;
  }

  ToolCall? _extractToolCallFromRawResponse(
    String rawResponse,
    String toolName,
  ) {
    final extractedObject = _extractJsonObject(rawResponse);
    if (extractedObject == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(extractedObject);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final functionCall = decoded['function_call'];
      if (functionCall is Map<String, dynamic>) {
        final parsed = _toolCallFromMap(functionCall, toolName);
        if (parsed != null) {
          return parsed;
        }
      }

      final functionCalls = decoded['function_calls'];
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

      if (decoded.containsKey('name') && decoded.containsKey('summary')) {
        return ToolCall(
          name: toolName,
          arguments: {
            'name': decoded['name'].toString(),
            'summary': decoded['summary'].toString(),
          },
        );
      }
    } catch (_) {
      return null;
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

  @override
  void dispose() {
    _lm.unload();
  }
}

String _buildSystemPrompt() {
  return 'You generate hidden pet bios for a focus companion app. '
      'You must respond by calling the submit_pet_bio tool exactly once. '
      'Never answer directly in plain text. '
      'Any output outside the tool call is invalid and will be discarded. '
      'Do not return JSON or natural-language prose outside the tool call. '
      'The pet name must be single word and may not just be the animal species. '
      'The summary must briefly describe the specific animal\'s personality or vibe.';
}


String _buildPrompt(AnimalSpec animalSpec) {
  return 'Animal species: ${animalSpec.displayName}\n'
      'Only valid output: call submit_pet_bio with a one-word name and a short summary.\n'
      'Any direct text response is invalid.';
}
