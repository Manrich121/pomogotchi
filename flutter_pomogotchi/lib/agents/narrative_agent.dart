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
  String? _lastDownloadLogLine;

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
        return _parseBioFromResponse(result.response);
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
    final message = 'Narrative agent model download: $status$percentage';

    if (_lastDownloadLogLine == message) {
      return;
    }
    _lastDownloadLogLine = message;

    if (isError) {
      debugPrint('ERROR: $message');
      return;
    }

    debugPrint(message);
  }

  PetBio _parseBioFromResponse(String rawResponse) {
    return parseNarrativeBioResponse(rawResponse);
  }

  @override
  void dispose() {
    _lm.unload();
  }
}

@visibleForTesting
PetBio parseNarrativeBioResponse(String rawResponse) {
  final cleanedResponse = _stripThinking(rawResponse);
  final extractedObject = _extractJsonObject(cleanedResponse);

  if (extractedObject != null) {
    try {
      return _parseBioFromJsonObject(extractedObject);
    } on FormatException {
      final recoveredBio = _parseBioFromLooseFields(extractedObject);
      if (recoveredBio != null) {
        return recoveredBio;
      }
    }
  }

  final fallbackBio =
      _parseBioFromLabeledText(cleanedResponse) ??
      _parseBioFromLooseFields(cleanedResponse) ??
      _parseBioFromColonSummary(cleanedResponse);
  if (fallbackBio != null) {
    return fallbackBio;
  }

  throw const FormatException(
    'Narrative response did not include a usable name and summary.',
  );
}

PetBio _parseBioFromJsonObject(String extractedObject) {
  final decoded = jsonDecode(extractedObject);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Narrative response JSON was not an object.');
  }

  final name = (decoded['name'] ?? '').toString().trim();
  final summary = (decoded['summary'] ?? '').toString().trim();
  return _validatedBio(name: name, summary: summary);
}

PetBio? _parseBioFromLabeledText(String rawResponse) {
  final nameMatch = RegExp(
    r'^\s*name\s*:\s*(.+)$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(rawResponse);
  final summaryMatch = RegExp(
    r'^\s*summary\s*:\s*(.+)$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(rawResponse);

  if (nameMatch == null || summaryMatch == null) {
    return null;
  }

  final name = nameMatch.group(1)?.trim() ?? '';
  final summary = summaryMatch.group(1)?.trim() ?? '';
  try {
    return _validatedBio(name: name, summary: summary);
  } on FormatException {
    return null;
  }
}

PetBio? _parseBioFromLooseFields(String rawResponse) {
  final nameMatch = RegExp(
    r'''["']?-?name["']?\s*:\s*["']?([A-Za-z][A-Za-z0-9_-]*)["']?''',
    caseSensitive: false,
  ).firstMatch(rawResponse);
  final summaryMatch = RegExp(
    r'''["']?-?summary["']?\s*:\s*["']([^"\r\n}]+)["']?''',
    caseSensitive: false,
  ).firstMatch(rawResponse);

  if (nameMatch == null || summaryMatch == null) {
    return null;
  }

  final name = nameMatch.group(1)?.trim() ?? '';
  final summary = summaryMatch.group(1)?.trim() ?? '';
  try {
    return _validatedBio(name: name, summary: summary);
  } on FormatException {
    return null;
  }
}

PetBio? _parseBioFromColonSummary(String rawResponse) {
  for (final line in rawResponse.split('\n')) {
    final match = RegExp(
      r'^\s*([A-Za-z][A-Za-z0-9_-]*)\s*:\s*(.+)$',
    ).firstMatch(line.trim());
    if (match == null) {
      continue;
    }

    final name = match.group(1)?.trim() ?? '';
    final summary = match.group(2)?.trim() ?? '';
    try {
      return _validatedBio(name: name, summary: summary);
    } on FormatException {
      continue;
    }
  }

  return null;
}

PetBio _validatedBio({required String name, required String summary}) {
  final normalizedName = name.trim();
  final normalizedSummary = summary
      .trim()
      .replaceAll(RegExp(r'^\s*[-:"]+\s*'), '')
      .replaceAll(RegExp(r'\s*,\s*$'), '')
      .replaceAll(RegExp(r'\s*//.*$'), '')
      .trim();

  if (normalizedName.isEmpty || normalizedName.contains(RegExp(r'\s'))) {
    throw const FormatException('Narrative response returned an invalid name.');
  }

  if (normalizedSummary.isEmpty) {
    throw const FormatException(
      'Narrative response returned an empty summary.',
    );
  }

  return PetBio(name: normalizedName, summary: normalizedSummary);
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

String _stripThinking(String rawResponse) {
  return rawResponse
      .replaceAll(
        RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
        '',
      )
      .trim();
}

String _buildSystemPrompt() {
  return '''
Role: You create hidden pet bios for a focus companion app.

Task:
- Invent one cute pet name.
- Invent one short personality summary.

Rules:
- The name must be one word.
- The name must not be the animal species.
- The summary must be 8 to 16 words.
- The summary should describe temperament, voice, and affection style.
- Keep the personality warm, playful, and suitable for a cozy focus companion.
- Use English only.
- Do not output <think> tags.
- Do not explain your reasoning.
- Answer with the final output immediately.

Output:
- Return JSON only.
- Use exactly this shape: {"name":"...", "summary":"..."}
- Do not add markdown, code fences, or extra text.
- If JSON fails, return exactly:
  NAME: one-word-name
  SUMMARY: short summary
''';
}

String _buildPrompt(AnimalSpec animalSpec) {
  return '''
Animal species: ${animalSpec.displayName}

Create one hidden pet bio for this animal.
Return JSON only.
''';
}
