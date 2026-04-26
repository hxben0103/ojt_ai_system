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
import '../services/api_service.dart';
import '../core/ai_config.dart';

class ChatBotScreen extends StatefulWidget {
  final Map<String, dynamic>? dashboardData;

  const ChatBotScreen({
    super.key,
    this.dashboardData,
  });

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
    
    _focusNode.onKeyEvent = (node, event) {
      if (!mounted) return KeyEventResult.ignored;
      if (event is KeyDownEvent && 
          event.logicalKey == LogicalKeyboardKey.enter && 
          !HardwareKeyboard.instance.isShiftPressed) {
        _sendMessage();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    // Load greeting when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGreeting();
    });
  }

  @override
  void dispose() {
    _focusNode.onKeyEvent = null; // Detach hotkey listener first
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

      // ── Load auth token for authenticated endpoint ──
      final token = prefs.getString('auth_token');
      
      final client = http.Client();
      final request = http.Request('POST', Uri.parse(apiUrl))
        ..headers['Content-Type'] = 'application/json'
        ..headers['Authorization'] = 'Bearer ${token ?? ''}'
        ..body = json.encode({
          "message": userMessage,
          "session_id": sessionId,
          "student_data": widget.dashboardData,
          "stream": true, // Request streaming
        });

      final response = await client.send(request).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final messageId = DateTime.now().millisecondsSinceEpoch.toString();
        final streamingMsg = ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          messageId: messageId,
        );

        setState(() {
          _streamingMessage = streamingMsg;
          _messages.add(streamingMsg);
          _isTyping = true;
          _streamingText = '';
        });

        // Parse NDJSON stream
        bool hasReceivedData = false;
        await response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) {
          if (line.trim().isEmpty) return;
          try {
            final data = json.decode(line);
            if (data['success'] == true) {
              hasReceivedData = true;
              final botReply = data["answer"] as String? ?? 
                              data["response"] as String? ?? 
                              data["message"] as String?;
              
              if (botReply != null) {
                _updateStreamingMessage(messageId, botReply);
              }
            } else {
              _showErrorMessage(data['message'] ?? 'Service Error');
            }
          } catch (e) {
            debugPrint('Error parsing streaming line: $e');
          }
        });

        if (!hasReceivedData) {
          _showErrorMessage("Received empty response from server");
        } else if (_streamingText.isNotEmpty) {
          // Send log to the backend for AI payload metrics
          try {
            await ApiService.post('/chatbot/log', {
              'query': userMessage,
              'response': _streamingText,
              'model_used': 'gemma2:2b'
            });
          } catch (error) {
            debugPrint('Failed to log chatbot interaction: $error');
          }
        }

        setState(() {
          _isTyping = false;
          _streamingMessage = null;
          _streamingText = '';
        });
      } else {
        _showErrorMessage("Server error: ${response.statusCode}");
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

  void _updateStreamingMessage(String messageId, String text) {
    if (!mounted) return;
    setState(() {
      int index = -1;
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].messageId == messageId) {
          index = i;
          break;
        }
      }

      if (index != -1) {
        _messages[index] = ChatMessage(
          text: text,
          isUser: false,
          timestamp: _messages[index].timestamp,
          messageId: messageId,
        );
      }
      _streamingText = text;
    });
    _scrollToBottom();
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: "⚠️ $message",
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isTyping = false;
    });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.smart_toy_rounded, 
                      color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "JRMSU AI Assistant",
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        _StatusPulsingDot(),
                        SizedBox(width: 6),
                        Text(
                          "Active Now",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty && !_hasShownGreeting
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isTyping && _streamingMessage == null && index == _messages.length) {
                          return _buildTypingIndicator();
                        }
                        if (index >= _messages.length) return const SizedBox.shrink();
                        
                        final msg = _messages[index];
                        return _buildMessageBubble(msg, index);
                      },
                    ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

  Widget _buildMessageBubble(ChatMessage msg, int index) {
    final isUser = msg.isUser;
    
    return Container(
      key: ValueKey(msg.messageId ?? 'msg_$index'), // Stabilize widget in list
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _buildAvatar(true),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser 
                        ? const Color(0xFF6366F1).withOpacity(0.15)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isUser ? null : Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content
                  isUser
                      ? Text(
                          msg.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
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
                                color: Color(0xFF1E293B),
                                fontSize: 15,
                                height: 1.6,
                              ),
                            )
                          : (msg.text.isEmpty 
                             ? _BlinkingCursorIndicator()
                             : MarkdownBody(
                                data: msg.text,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 15,
                                    height: 1.6,
                                  ),
                                  strong: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  code: TextStyle(
                                    backgroundColor: const Color(0xFFF8FAFC),
                                    color: const Color(0xFF6366F1),
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  blockquote: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  listBullet: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                                  h3: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                  a: const TextStyle(
                                    color: Color(0xFF4F46E5),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                onTapLink: (text, href, title) {
                                  if (href != null) {
                                    launchUrl(Uri.parse(href));
                                  }
                                },
                              ))),
                  const SizedBox(height: 8),
                  // Timestamp and actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.timestamp),
                        style: TextStyle(
                          color: isUser
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
            _buildAvatar(false),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(true),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const _BlinkingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isBot) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isBot ? null : const Color(0xFFE2E8F0),
        gradient: isBot ? const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
          color: isBot ? Colors.white : const Color(0xFF64748B),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                hintText: "Ask about your progress...",
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSendButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return InkWell(
      onTap: _isTyping ? null : _sendMessage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isTyping
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
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

// --- Helper UI Components ---

class _StatusPulsingDot extends StatefulWidget {
  const _StatusPulsingDot();

  @override
  State<_StatusPulsingDot> createState() => _StatusPulsingDotState();
}

class _StatusPulsingDotState extends State<_StatusPulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF10B981),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BlinkingCursorIndicator extends StatefulWidget {
  const _BlinkingCursorIndicator();

  @override
  State<_BlinkingCursorIndicator> createState() => _BlinkingCursorIndicatorState();
}

class _BlinkingCursorIndicatorState extends State<_BlinkingCursorIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
class _BlinkingDots extends StatefulWidget {
  const _BlinkingDots();

  @override
  State<_BlinkingDots> createState() => _BlinkingDotsState();
}

class _BlinkingDotsState extends State<_BlinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            double value = (_controller.value - delay).clamp(0.0, 1.0);
            if (value > 0.5) value = 1.0 - value;
            value *= 2; // Normalize to 0-1 range for the pulse
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: (0.3 + (0.7 * value)).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: (0.8 + (0.3 * value)).clamp(0.0, 1.0),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

