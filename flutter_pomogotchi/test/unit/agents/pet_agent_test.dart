import 'package:flutter_test/flutter_test.dart';
import 'package:pomogotchi/agents/pet_agent.dart';

void main() {
  group('CactusPetAgent.parseSpeechFromResponse', () {
    test('strips a leading double quote from plain text output', () {
      final speech = CactusPetAgent.parseSpeechFromResponse(
        '"Your gentle touch brings a smile to my face.',
      );

      expect(speech, 'Your gentle touch brings a smile to my face.');
    });

    test('strips wrapping double quotes from json speech output', () {
      final speech = CactusPetAgent.parseSpeechFromResponse(
        '{"speech":"\\"Your gentle touch brings a smile to my face.\\""}',
      );

      expect(speech, 'Your gentle touch brings a smile to my face.');
    });
  });
}
