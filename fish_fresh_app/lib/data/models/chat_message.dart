class ChatMessage {
  final String text;
  final bool isUser;
  final String? category;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.category,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
