import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/gemini_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'W1 Chatbot',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Color(0xFFF6F7FB),
        ),
      ),
      home: const ChatPage(),
    );
  }
}

enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage({required this.role, required this.text, this.isLoading = false});

  final ChatRole role;
  final String text;
  final bool isLoading;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _service = GeminiService();

  final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      role: ChatRole.assistant,
      text: 'Hi, I am W1 Chatbot. Ask me anything and I will reply in plain text only.',
    ),
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!_scrollController.hasClients) {
      return;
    }

    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final String message = _controller.text.trim();
    if (message.isEmpty || _isLoading) {
      return;
    }

    final String? apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          role: ChatRole.assistant,
          text: 'Set GEMINI_API_KEY in .env before sending a message.',
        ));
      });
      return;
    }

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: message));
      _messages.add(ChatMessage(role: ChatRole.assistant, text: '', isLoading: true));
      _isLoading = true;
      _controller.clear();
    });

    await _scrollToBottom();

    try {
      final String reply = await _service.sendMessage(apiKey, message);
      if (!mounted) {
        return;
      }

      setState(() {
        final int loadingIndex = _messages.lastIndexWhere((ChatMessage item) => item.isLoading);
        if (loadingIndex != -1) {
          _messages[loadingIndex] = ChatMessage(role: ChatRole.assistant, text: reply);
        } else {
          _messages.add(ChatMessage(role: ChatRole.assistant, text: reply));
        }
        _isLoading = false;
      });
      await _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        final int loadingIndex = _messages.lastIndexWhere((ChatMessage item) => item.isLoading);
        final String messageText = error.toString().replaceFirst('Exception: ', '');
        if (loadingIndex != -1) {
          _messages[loadingIndex] = ChatMessage(role: ChatRole.assistant, text: messageText);
        } else {
          _messages.add(ChatMessage(role: ChatRole.assistant, text: messageText));
        }
        _isLoading = false;
      });
      await _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('W1 Chatbot'),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF6F7FB), Color(0xFFEFF2FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'W1 Chatbot',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Plain text responses only',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemBuilder: (BuildContext context, int index) {
                    final ChatMessage message = _messages[index];
                    return ChatBubble(message: message);
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: _messages.length,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Write a message to W1 Chatbot',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.3),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Replies are generated as plain text only.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _sendMessage,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(_isLoading ? 'Sending' : 'Send'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == ChatRole.user;
    final ThemeData theme = Theme.of(context);
    final Color bubbleColor = isUser ? theme.colorScheme.primary : Colors.white;
    final Color textColor = isUser ? Colors.white : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 20),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: message.isLoading
                ? const ThinkingIndicator()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        isUser ? 'You' : 'CRAG',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: textColor.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (message.text.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          message.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'W1 Chatbot is thinking',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(3, (int index) {
                final double phase = (_controller.value * 1.6) - (index * 0.22);
                final double wave = (1 - ((phase % 1).abs() * 2)).clamp(0.0, 1.0);
                final double scale = 0.72 + (wave * 0.28);
                final double opacity = 0.35 + (wave * 0.65);

                return Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
