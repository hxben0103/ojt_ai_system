import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/prediction_service.dart';
import '../services/auth_service.dart';
import '../core/ai_config.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? messageId;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.messageId,
  });
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  String _streamingText = '';
  ChatMessage? _streamingMessage;
  final FocusNode _focusNode = FocusNode();
  bool _hasShownGreeting = false;
  String? _lastUserMessage; // stored for retry

  // Use centralized AI config for chatbot URL
  final String apiUrl = AiConfig.chatEndpoint;

  @override
  void initState() {
    super.initState();
    // Load greeting when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGreeting();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadGreeting() async {
    if (_hasShownGreeting || !mounted) return;

    try {
      // Get or generate session ID
      final prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString('chatbot_session_id');
      if (sessionId == null) {
        sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString('chatbot_session_id', sessionId);
      }

      final response = await http.post(
        Uri.parse(AiConfig.greetingEndpoint),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": sessionId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final greeting = data["answer"] as String?;

        if (greeting != null && greeting.isNotEmpty && mounted) {
          // Create greeting message
          final greetingMsg = ChatMessage(
            text: '',
            isUser: false,
            timestamp: DateTime.now(),
            messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          );

          setState(() {
            _hasShownGreeting = true;
            _streamingMessage = greetingMsg;
            _messages.add(greetingMsg);
            _isTyping = true;
          });

          // Stream the greeting for better UX
          await _streamResponse(greeting, greetingMsg);

          if (mounted) {
            setState(() {
              _isTyping = false;
              _streamingMessage = null;
            });
          }
          _scrollToBottom();
        }
      }
    } catch (e) {
      // Silently fail - greeting is not critical, but mark as shown to avoid retries
      debugPrint('Failed to load greeting: $e');
      if (mounted) {
        setState(() {
          _hasShownGreeting = true; // Prevent retry loops
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    _controller.clear();
    _focusNode.unfocus();
    _lastUserMessage = userMessage;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      ));
      _isTyping = true;
      _streamingText = '';
    });

    _scrollToBottom();

    try {
      // Get or generate session ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString('chatbot_session_id');
      if (sessionId == null) {
        sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString('chatbot_session_id', sessionId);
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "message": userMessage,
          "session_id": sessionId, // Include session ID for conversation context
        }),
      ).timeout(const Duration(seconds: 120)); // Increased timeout for RAG + Ollama processing

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle new structured response format
        if (data.containsKey("success") && data["success"] == false) {
          // Error response from backend
          final errorMsg = data["message"] as String? ?? 
                          data["error"] as String? ?? 
                          "Chatbot service unavailable";
          
          setState(() {
            _messages.add(ChatMessage(
              text: "⚠️ $errorMsg",
              isUser: false,
              timestamp: DateTime.now(),
            ));
            _isTyping = false;
          });
          _scrollToBottom();
          return;
        }
        
        // Success response - get answer from structured format (supports both old and new formats)
        final botReply = data["answer"] as String? ?? 
                        data["response"] as String? ?? 
                        data["message"] as String?;
        
        // Check if this is a fallback response (low confidence) - new format only
        final isFallback = data["is_fallback"] as bool? ?? false;
        final confidenceScore = data["confidence_score"] as double?;
        
        if (botReply != null && botReply.isNotEmpty) {
          // Add warning if this is a low-confidence response (structured format)
          String displayText = botReply;
          if (isFallback) {
            displayText = "$botReply\n\n⚠️ Note: This is a low-confidence answer. Please consult your OJT coordinator for confirmation.";
            debugPrint('[CHATBOT] Received fallback response (low confidence: ${confidenceScore ?? "unknown"})');
          }
          debugPrint('[CHATBOT] Bot reply received: ${botReply.length} characters');
          debugPrint('[CHATBOT] Bot reply preview: ${botReply.substring(0, botReply.length > 150 ? 150 : botReply.length)}...');
          
          // Check if the reply is actually an error message
          if (botReply.startsWith("⚠️") || botReply.startsWith("🚫") || botReply.startsWith("Error:")) {
            debugPrint('[CHATBOT] Warning: Response looks like an error: $botReply');
          }
          
          // Create streaming message and show it word by word
          final messageId = DateTime.now().millisecondsSinceEpoch.toString();
          final streamingMsg = ChatMessage(
            text: '',
            isUser: false,
            timestamp: DateTime.now(),
            messageId: messageId,
          );
          
          debugPrint('[CHATBOT] Creating streaming message with ID: $messageId');
          setState(() {
            _streamingMessage = streamingMsg;
            _messages.add(streamingMsg);
            _isTyping = true;
            _streamingText = '';
          });
          
          debugPrint('[CHATBOT] Starting to stream ${displayText.split(' ').length} words...');
          // Stream the response word by word
          await _streamResponse(displayText, streamingMsg);
          debugPrint('[CHATBOT] Streaming completed');
          
          setState(() {
            _isTyping = false;
            _streamingMessage = null;
            _streamingText = '';
          });

          // Log the interaction to backend (non-blocking)
          // Use original botReply (without fallback warning) for logging
          _logChatbotInteraction(userMessage, botReply);
        } else {
          setState(() {
            _messages.add(ChatMessage(
              text: "⚠️ Received empty response from server",
              isUser: false,
              timestamp: DateTime.now(),
            ));
            _isTyping = false;
          });
        }
      } else {
        // Server returned non-200 status - handle structured error response
        String errorMsg = "⚠️ Server error: ${response.statusCode}";
        try {
          final errorData = json.decode(response.body);
          
          // Handle new structured error format
          if (errorData.containsKey("success") && errorData["success"] == false) {
            errorMsg = errorData["message"] as String? ?? 
                      errorData["error"] as String? ?? 
                      "Chatbot service unavailable";
          } else if (errorData.containsKey("message")) {
            errorMsg = errorData["message"] as String;
          } else if (errorData.containsKey("error")) {
            final errorText = errorData["error"];
            if (errorText is String && errorText.isNotEmpty) {
              errorMsg = "⚠️ $errorText";
            } else if (errorText is Map && errorText.containsKey("message")) {
              errorMsg = errorText["message"] as String;
            }
          } else if (errorData.containsKey("response")) {
            errorMsg = errorData["response"] as String;
          }
        } catch (e) {
          debugPrint('Failed to parse error response: $e');
        }
        
        debugPrint('Server error response: Status ${response.statusCode}, Message: $errorMsg');
        
        setState(() {
          _messages.add(ChatMessage(
            text: errorMsg,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isTyping = false;
        });
      }
    } on http.ClientException catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "🚫 Unable to reach the chatbot server. Tap **Retry** to try again.",
          isUser: false,
          timestamp: DateTime.now(),
          messageId: 'error_retry',
        ));
        _isTyping = false;
      });
      debugPrint('Chatbot connection error: $e');
    } on TimeoutException catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "⏱️ The server took too long to respond. Tap **Retry** to try again.",
          isUser: false,
          timestamp: DateTime.now(),
          messageId: 'error_retry',
        ));
        _isTyping = false;
      });
      debugPrint('Chatbot timeout error: $e');
    } catch (e) {
      debugPrint('Chatbot exception: $e');
      debugPrint('Exception type: ${e.runtimeType}');
      final errorMsg = e.toString();

    setState(() {
        _messages.add(ChatMessage(
          text: "🚫 Unexpected error: ${errorMsg.length > 100 ? errorMsg.substring(0, 100) + '...' : errorMsg}",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      _isTyping = false;
    });
    }

    _scrollToBottom();
  }

  Future<void> _streamResponse(String fullText, ChatMessage message) async {
    debugPrint('[STREAM] Starting to stream text: ${fullText.length} characters, ${fullText.split(' ').length} words');
    
    // Split text into words for natural streaming
    final words = fullText.split(' ');
    String currentText = '';
    
    // Find the message index by messageId (more reliable than object comparison)
    int messageIndex = -1;
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].messageId == message.messageId) {
        messageIndex = i;
        break;
      }
    }
    
    if (messageIndex == -1) {
      debugPrint('[STREAM] ERROR: Could not find streaming message in list. Total messages: ${_messages.length}');
      debugPrint('[STREAM] Looking for messageId: ${message.messageId}');
      for (int i = 0; i < _messages.length; i++) {
        debugPrint('[STREAM] Message $i ID: ${_messages[i].messageId}');
      }
      return;
    }
    
    debugPrint('[STREAM] Found message at index: $messageIndex');
    
    for (int i = 0; i < words.length; i++) {
      if (!mounted) break;
      
      // Add word with space (except first word)
      currentText += (i > 0 ? ' ' : '') + words[i];
      
      // Update the message text in real-time using the index
      setState(() {
        if (messageIndex < _messages.length && 
            _messages[messageIndex].messageId == message.messageId) {
          _messages[messageIndex] = ChatMessage(
            text: currentText,
            isUser: false,
            timestamp: message.timestamp,
            messageId: message.messageId,
          );
        }
        _streamingText = currentText;
      });
      
      // Auto-scroll as text streams
      _scrollToBottom();
      
      // Variable delay: faster for short words, slower for punctuation
      int delay = 30;
      if (words[i].endsWith('.') || words[i].endsWith('!') || words[i].endsWith('?')) {
        delay = 100; // Pause after sentences
      } else if (words[i].endsWith(',') || words[i].endsWith(';')) {
        delay = 60; // Shorter pause after commas
      } else if (words[i].length > 8) {
        delay = 20; // Faster for long words
      }
      
      await Future.delayed(Duration(milliseconds: delay));
    }
    
    // Ensure final text is complete
    if (mounted) {
      setState(() {
        // Re-find index in case list changed
        int finalIndex = -1;
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].messageId == message.messageId) {
            finalIndex = i;
            break;
          }
        }
        
        if (finalIndex != -1 && finalIndex < _messages.length) {
          _messages[finalIndex] = ChatMessage(
            text: fullText,
            isUser: false,
            timestamp: message.timestamp,
            messageId: message.messageId,
          );
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI JRMSU Assistant",
                  style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                ),
                Text(
                    "Online • Ready to help",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('Clear Chat'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _messages.clear();
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About'),
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('About AI Assistant'),
                              content: const Text(
                                'This AI assistant is powered by JRMSU OJT knowledge base. '
                                'It can help you with questions about OJT procedures, requirements, and more.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                ),
              ],
                            ),
                          );
                        },
            ),
          ],
        ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_hasShownGreeting
                ? _buildEmptyState()
                : ListView.builder(
              controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                      // Show typing indicator only if we're waiting for initial response
                      if (_isTyping && _streamingMessage == null && index == _messages.length) {
                  return _buildTypingIndicator();
                }

                      if (index >= _messages.length) {
                        return const SizedBox.shrink();
                      }

                final msg = _messages[index];
                      return _buildMessageBubble(msg);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'AI JRMSU Assistant',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about OJT procedures,\nrequirements, or guidelines.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('What are the OJT requirements?'),
              _buildSuggestionChip('How do I submit attendance?'),
              _buildSuggestionChip('What is the evaluation process?'),
            ],
            ),
        ],
          ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade400, Colors.indigo.shade600],
      ),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.indigo.shade600
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Message content with markdown support
                   // During streaming, show plain text to avoid markdown parsing issues
                   isUser
                       ? Text(
                           msg.text,
                           style: const TextStyle(
                             color: Colors.white,
                             fontSize: 15,
                             height: 1.5,
                           ),
                         )
                       : (_streamingMessage != null && 
                          msg.messageId == _streamingMessage?.messageId && 
                          _isTyping &&
                          msg.text.isNotEmpty
                           ? Text(
                               msg.text,
                               style: const TextStyle(
                                 color: Colors.black87,
                                 fontSize: 15,
                                 height: 1.6,
                               ),
                             )
                           : (msg.text.isEmpty 
                              ? const Text(
                                  '...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 15,
                                  ),
                                )
                              : MarkdownBody(
                               data: msg.text,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              height: 1.6,
                            ),
                            code: TextStyle(
                              backgroundColor: Colors.grey.shade200,
                              color: Colors.indigo.shade700,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            blockquote: TextStyle(
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                            listBullet: TextStyle(color: Colors.indigo.shade600),
                            h1: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            h2: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            h3: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            a: TextStyle(
                              color: Colors.indigo.shade600,
                              decoration: TextDecoration.underline,
                             ),
                           ),
                           onTapLink: (text, href, title) {
                             if (href != null) {
                               launchUrl(Uri.parse(href));
                             }
                           },
                         ))),
                  const SizedBox(height: 4),
                  // Timestamp and actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.timestamp),
                        style: TextStyle(
                          color: isUser
                              ? Colors.white70
                              : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _copyToClipboard(msg.text),
                          child: Icon(
                            Icons.copy,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        // Retry button for error messages
                        if (msg.messageId == 'error_retry' && _lastUserMessage != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              _controller.text = _lastUserMessage!;
                              _sendMessage();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 14, color: Colors.indigo.shade400),
                                const SizedBox(width: 2),
                                Text('Retry', style: TextStyle(fontSize: 11, color: Colors.indigo.shade400)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigo.shade100,
              ),
              child: Icon(
                Icons.person,
                color: Colors.indigo.shade700,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    ).animate().fade(duration: 300.ms).slideX(
          begin: isUser ? 0.2 : -0.2,
          curve: Curves.easeOut,
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.indigo.shade400, Colors.indigo.shade600],
              ),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Animate(
                effects: [
                  FadeEffect(
                        duration: 600.ms,
                        delay: (index * 200).ms,
                    curve: Curves.easeInOut,
                  ),
                  ScaleEffect(
                        duration: 600.ms,
                        delay: (index * 200).ms,
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    curve: Curves.easeInOut,
                  ),
                ],
                onPlay: (controller) => controller.repeat(reverse: true),
                child: Container(
                  width: 8,
                  height: 8,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.indigo.shade400, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isTyping ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    child: _isTyping
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  // Log chatbot interaction to backend
  Future<void> _logChatbotInteraction(String query, String response) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId != null) {
        await PredictionService.saveChatbotLog(
          userId: currentUser!.userId!,
          query: query,
          response: response,
          modelUsed: 'rag-ollama',
        );
      }
    } catch (e) {
      // Silently fail - logging should not break the user experience
        debugPrint('Failed to save chatbot log: ${e.toString()}');
    }
  }
}
