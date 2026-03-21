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
            ChatMessage(content: _systemPrompt, role: 'system'),
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

  String get _systemPrompt {
    return 'You generate hidden pet bios for a focus companion app. '
        'You must respond by calling the submit_pet_bio tool exactly once. '
        'Do not return JSON or natural-language prose outside the tool call. '
        'The name must be a single word. '
        'The summary must briefly describe the specific animal\'s personality or vibe.';
  }

  String _buildPrompt(AnimalSpec animalSpec) {
    return 'Animal species: ${animalSpec.displayName}\n'
        'Call submit_pet_bio with a one-word name and a short summary.\n'
        'Example name: Bernie\n'
        'Example summary: A scruffy optimist who celebrates every small win.';
  }

  PetBio _parseBioFromToolCall(CactusCompletionResult result) {
    if (result.toolCalls.isEmpty) {
      throw const FormatException(
        'Narrative response did not include a tool call.',
      );
    }

    final toolCall = result.toolCalls.lastWhere(
      (call) => call.name == _submitPetBioTool.name,
      orElse: () => throw const FormatException(
        'Narrative response called the wrong tool.',
      ),
    );

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

  @override
  void dispose() {
    _lm.unload();
  }
}
