import 'package:cactus/cactus.dart';

enum PetTranscriptRole { user, assistant }

class PetTranscriptEntry {
  const PetTranscriptEntry({required this.role, required this.content});

  const PetTranscriptEntry.user(this.content) : role = PetTranscriptRole.user;

  const PetTranscriptEntry.assistant(this.content)
    : role = PetTranscriptRole.assistant;

  final PetTranscriptRole role;
  final String content;

  ChatMessage toChatMessage() {
    return ChatMessage(
      content: content,
      role: role == PetTranscriptRole.user ? 'user' : 'assistant',
    );
  }
}
