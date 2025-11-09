class ChatbotLog {
  final int? chatId;
  final int userId;
  final String? userName;
  final String query;
  final String response;
  final String modelUsed;
  final DateTime? timestamp;

  ChatbotLog({
    this.chatId,
    required this.userId,
    this.userName,
    required this.query,
    required this.response,
    required this.modelUsed,
    this.timestamp,
  });

  factory ChatbotLog.fromJson(Map<String, dynamic> json) {
    return ChatbotLog(
      chatId: json['chat_id'] as int?,
      userId: json['user_id'] as int,
      userName: json['full_name'] as String?,
      query: json['query'] as String,
      response: json['response'] as String,
      modelUsed: json['model_used'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (chatId != null) 'chat_id': chatId,
      'user_id': userId,
      'query': query,
      'response': response,
      'model_used': modelUsed,
    };
  }
}

