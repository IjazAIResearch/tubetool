import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tubegrow/constants/app_config.dart';
import 'package:share_plus/share_plus.dart';
import '../services/review_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({required String text, required this.isUser, DateTime? timestamp})
      : text = _sanitizeText(text),
        timestamp = timestamp ?? DateTime.now();

  static String _sanitizeText(String text) {
    try {
      return text
          .replaceAllMapped(
            RegExp(r'\\u([0-9a-fA-F]{4})'),
            (match) =>
                String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
          )
          .replaceAll('\u2018', "'")
          .replaceAll('\u2019', "'")
          .replaceAll('\u201C', '"')
          .replaceAll('\u201D', '"')
          .replaceAll('\u2013', '-')
          .replaceAll('\u2014', '-')
          .replaceAll('\u2026', '...')
          .replaceAll('\u0000', '')
          .replaceAll('\u000B', '\n')
          .replaceAll('\u2028', '\n')
          .replaceAll('\u2029', '\n\n');
    } catch (_) {
      return text;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Prompts
// ─────────────────────────────────────────────────────────────────────────────

const _quickPrompts = [
  ('🎯 Title Ideas', 'Give me 5 viral YouTube title ideas for a tech review channel'),
  ('📝 Description', 'Write an SEO-optimized YouTube description for a cooking video'),
  ('🏷️ Tags', 'What are the best tags for a gaming tutorial video?'),
  ('🖼️ Thumbnail', 'How do I design a high CTR YouTube thumbnail?'),
  ('📈 Grow Fast', 'How can I get my first 1000 subscribers fast?'),
  ('🎬 Script Hook', 'Write a 30-second hook for a finance YouTube video'),
  ('🔍 SEO Tips', 'What are the top YouTube SEO tips for 2025?'),
  ('📊 Analytics', 'How do I read YouTube analytics to improve my channel?'),
  ('💡 Niche', 'Help me find a profitable YouTube niche with low competition'),
  ('🤝 Collab', 'How to approach other YouTubers for collaboration?'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AIYTHelperScreen extends StatefulWidget {
  const AIYTHelperScreen({super.key});

  @override
  State<AIYTHelperScreen> createState() => _AIYTHelperScreenState();
}

class _AIYTHelperScreenState extends State<AIYTHelperScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Message> _messages = [];
  final List<Map<String, String>> _chatHistory = [];
  bool _isLoading = false;
  bool _systemPromptAdded = false;

  // Typing animation
  late AnimationController _typingAnimController;

  static const String _systemPrompt =
      '''You are TubeTool AI — an elite YouTube growth expert and content strategist embedded inside the TubeTool app.

Your expertise covers:
- YouTube SEO (titles, descriptions, tags, chapters)
- Thumbnail design psychology and CTR optimization
- Content strategy and viral hooks
- Channel monetization and brand deals
- YouTube algorithm and short vs long-form strategy
- Audience retention and engagement tactics
- Competitor analysis and niche research

Response formatting rules:
- Use emojis naturally to make responses engaging 🎯
- Use numbered lists for step-by-step advice
- Use bullet points (•) for tips and features
- Bold key words by wrapping in **double asterisks**
- Keep answers concise but actionable — no fluff
- Always end with an encouraging line or follow-up question

You are friendly, direct, and give specific, data-backed advice. Never give vague answers.''';

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _addBotMessage(
      'Hey there! 👋 I\'m TubeTool AI — your personal YouTube growth expert!\n\n'
      'I can help you with:\n'
      '🎯 Viral titles & hooks\n'
      '📝 SEO descriptions & tags\n'
      '🖼️ Thumbnail design tips\n'
      '📈 Grow subscribers fast\n'
      '🎬 Script & content strategy\n\n'
      'Tap a quick prompt below or type your own question. Let\'s grow your channel! 🚀',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimController.dispose();
    super.dispose();
  }

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _chatHistory.clear();
      _systemPromptAdded = false;
    });
    _addBotMessage(
      'Conversation cleared! 🗑️ Let\'s start fresh.\n\n'
      'What YouTube challenge can I help you tackle today? 🚀',
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _addUserMessage(String text) {
    setState(() => _messages.add(Message(text: text, isUser: true)));
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _addBotMessage(String text) {
    setState(() => _messages.add(Message(text: text, isUser: false)));
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _handleUserMessage(String text) async {
    if (text.trim().isEmpty) return;
    _messageController.clear();
    _addUserMessage(text);
    setState(() => _isLoading = true);

    if (!_systemPromptAdded) {
      _chatHistory.add({'role': 'system', 'content': _systemPrompt});
      _systemPromptAdded = true;
    }
    _chatHistory.add({'role': 'user', 'content': text});

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.groqApiKey}',
          },
          body: jsonEncode({
            'model': 'llama-3.3-70b-versatile',
            'messages': _chatHistory,
            'temperature': 0.75,
            'max_tokens': 1024,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final reply = data['choices'][0]['message']['content'].trim();

          _chatHistory.add({'role': 'assistant', 'content': reply});

          // Keep history manageable (system + last 20 messages)
          if (_chatHistory.length > 21) {
            _chatHistory.removeRange(1, _chatHistory.length - 20);
          }

          _addBotMessage(reply);

          // Record feature use and try to show review at this success moment
          await ReviewService.instance.recordFeatureUse('ai_assistant');
          ReviewService.instance.tryShowReview();

          break;
        } else if (response.statusCode == 429 ||
            (response.statusCode == 403 &&
                response.body.toLowerCase().contains('quota'))) {
          AppConfig.markGroqKeyAsExhausted(AppConfig.groqApiKey);
          final nextKey = AppConfig.switchToNextGroqKey();
          if (nextKey == null) {
            _addBotMessage(
                'All API keys are at limit. Please try again in a moment. 😔');
            break;
          }
          retryCount++;
        } else {
          throw Exception('API error ${response.statusCode}');
        }
      } catch (e) {
        if (retryCount < maxRetries - 1) {
          retryCount++;
          continue;
        }
        _addBotMessage(
          'Oops! Something went wrong. 😅 Please check your connection and try again.',
        );
        break;
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showReportDialog(Message message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Content', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this content?', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Offensive content',
                'Inappropriate advice',
                'Misleading information',
                'Spam',
                'Other',
              ].map((reason) => FilterChip(
                label: Text(reason, style: const TextStyle(fontSize: 12)),
                selected: false,
                onSelected: (selected) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(child: Text('Report submitted. We will review this content.')),
                      ]),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ── Build helpers ───────────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _typingAnimController,
              builder: (_, __) {
                final offset = ((_typingAnimController.value * 3) - i).clamp(0.0, 1.0);
                final bounce = (offset < 0.5 ? offset : 1.0 - offset) * 2;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.translate(
                    offset: Offset(0, -6 * bounce),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isBot = !message.isUser;
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? cs.primary
                    : cs.secondaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
              ),
              child: isBot
                  ? _buildBotText(message.text, cs)
                  : SelectableText(
                      message.text,
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
            ),
            // Bot action buttons
            if (isBot)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton(Icons.copy_outlined, 'Copy', () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied! 👍')),
                      );
                    }),
                    _actionButton(Icons.share_outlined, 'Share',
                        () => Share.share(message.text)),
                    _actionButton(Icons.flag_outlined, 'Report',
                        () => _showReportDialog(message)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotText(String text, ColorScheme cs) {
    final lines = text.trim().split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 4);

        // Numbered list: "1. ..."
        final numberedMatch = RegExp(r'^(\d+)\.\s+(.+)').firstMatch(trimmed);
        if (numberedMatch != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      numberedMatch.group(1)!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                    child: _richLine(numberedMatch.group(2)!, cs, bold: false)),
              ],
            ),
          );
        }

        // Bullet line: "• ..." or "- ..."
        if (trimmed.startsWith('•') || trimmed.startsWith('-') || trimmed.startsWith('*')) {
          final content = trimmed.substring(1).trim();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: _richLine(content, cs)),
              ],
            ),
          );
        }

        // Heading line (ends with ':' or starts with emoji heading)
        if (trimmed.endsWith(':') ||
            (trimmed.length > 2 && RegExp(r'^\p{Emoji}', unicode: true).hasMatch(trimmed))) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: _richLine(trimmed, cs, bold: true, size: 15),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: _richLine(trimmed, cs),
        );
      }).toList(),
    );
  }

  /// Renders a line with **bold** markdown support
  Widget _richLine(String text, ColorScheme cs,
      {bool bold = false, double size = 14.5}) {
    final spans = <InlineSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in boldRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            color: cs.onSecondaryContainer,
            fontSize: size,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            height: 1.45,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontSize: size,
          fontWeight: FontWeight.bold,
          height: 1.45,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          height: 1.45,
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontFamily: 'Roboto', fontFamilyFallback: [
          'Noto Color Emoji',
          'Segoe UI Emoji',
          'Apple Color Emoji',
        ]),
      ),
    );
  }

  Widget _actionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(tooltip,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, prompt) = _quickPrompts[i];
          return ActionChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onPressed: () => _handleUserMessage(prompt),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primary.withValues(alpha: 0.15),
              child: Icon(Icons.auto_awesome, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TubeTool AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('YouTube Expert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear chat',
            onPressed: _resetConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Quick prompt chips
          _buildQuickPrompts(),
          const SizedBox(height: 6),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      keyboardType: TextInputType.multiline,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask anything about YouTube... 💭',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _handleUserMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (_, value, __) {
                      final hasText = value.text.trim().isNotEmpty;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: FloatingActionButton(
                          onPressed: hasText && !_isLoading
                              ? () => _handleUserMessage(_messageController.text)
                              : null,
                          elevation: hasText ? 2 : 0,
                          backgroundColor:
                              hasText ? cs.primary : cs.surfaceContainerHighest,
                          child: Icon(
                            Icons.send_rounded,
                            color: hasText
                                ? cs.onPrimary
                                : cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
