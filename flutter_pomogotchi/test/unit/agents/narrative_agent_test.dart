import 'package:flutter_test/flutter_test.dart';
import 'package:pomogotchi/agents/narrative_agent.dart';

void main() {
  group('parseNarrativeBioResponse', () {
    test('parses strict JSON output', () {
      final bio = parseNarrativeBioResponse(
        '{"name":"Bernie","summary":"A scrappy little hype machine with a soft spot for effort."}',
      );

      expect(bio.name, 'Bernie');
      expect(
        bio.summary,
        'A scrappy little hype machine with a soft spot for effort.',
      );
    });

    test('recovers from malformed fenced pseudo-json output', () {
      final bio = parseNarrativeBioResponse(r'''
```json
{
  "$schema": {
    "type": "object",
    "properties": {
      "-name":"Luna"
      -summary":"Playful and intelligent, Luna loves to explore with gentle nibbles on your fingers when you're not looking.",
      // Add more details if needed within the summary constraint
    }
  }
}
```
''');

      expect(bio.name, 'Luna');
      expect(
        bio.summary,
        "Playful and intelligent, Luna loves to explore with gentle nibbles on your fingers when you're not looking.",
      );
    });

    test('falls back to colon summary text', () {
      final bio = parseNarrativeBioResponse(
        'Luna: A cunning and curious monkey with a penchant for mischief.',
      );

      expect(bio.name, 'Luna');
      expect(
        bio.summary,
        'A cunning and curious monkey with a penchant for mischief.',
      );
    });
  });
}
