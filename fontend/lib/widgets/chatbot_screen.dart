import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({"sender": "user", "text": _controller.text.trim()});
      _isTyping = true;
    });

    String userMessage = _controller.text.trim();
    _controller.clear();

    // 💬 Simulate AI typing delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add({
          "sender": "bot",
          "text":
              "Hello! 👋 I'm *AI JRMSU OJT Assistant.*\nYou said: \"$userMessage\""
        });
        _isTyping = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: const NetworkImage(
                "https://cdn-icons-png.flaticon.com/512/4712/4712035.png",
              ),
              backgroundColor: Colors.blue.shade100,
              radius: 18,
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI JRMSU Assistant",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Online",
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 🗨️ Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }

                final msg = _messages[index];
                bool isUser = msg["sender"] == "user";
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(14),
                    constraints:
                        const BoxConstraints(maxWidth: 280, minHeight: 40),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              colors: [Color(0xFF0078FF), Color(0xFF00C6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUser
                          ? null
                          : const Color.fromARGB(255, 235, 237, 241),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 3,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  )
                      .animate()
                      .fade(duration: 300.ms)
                      .slideX(begin: isUser ? 0.3 : -0.3, curve: Curves.easeOut),
                );
              },
            ),
          ),

          // 💬 Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      prefixIcon:
                          const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF0078FF), Color(0xFF00C6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🕒 Typing indicator animation
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 235, 237, 241),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(duration: 300.ms, delay: (index * 150).ms)
                  .fadeOut(duration: 300.ms, delay: (index * 150 + 300).ms),
            );
          }),
        ),
      ),
    );
  }
}
