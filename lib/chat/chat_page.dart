import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../auth/auth_service.dart';
import '../services/gemini_service.dart';
import 'chat_bubble.dart';
import 'chat_history_repository.dart';
import 'chat_message.dart';
import 'chat_session.dart';
import 'chat_sidebar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.user});

  final User user;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _service = GeminiService();
  final ChatHistoryRepository _repository = ChatHistoryRepository();

  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  ChatSession? _session;
  List<ChatMessage> _messages = <ChatMessage>[];

  bool _isSessionLoading = true;
  bool _isLoading = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSession() async {
    try {
      final ChatSession session = await _repository.getOrCreateLatestSession(widget.user.uid);
      if (!mounted) {
        return;
      }

      await _activateSession(session);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSessionLoading = false;
        _connectionStatus = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _activateSession(ChatSession session) async {
    await _messagesSubscription?.cancel();
    _messagesSubscription = _repository.watchMessages(widget.user.uid, session.id).listen(
      (List<ChatMessage> messages) {
        if (!mounted) {
          return;
        }

        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _connectionStatus = error.toString().replaceFirst('Exception: ', '');
        });
      },
    );

    setState(() {
      _session = session;
      _isSessionLoading = false;
      _connectionStatus = null;
      _messages = <ChatMessage>[];
    });
  }

  Future<void> _startNewSession() async {
    if (_isSessionLoading || _isLoading) {
      return;
    }

    try {
      final ChatSession session = await _repository.createSession(widget.user.uid);
      if (!mounted) {
        return;
      }

      await _activateSession(session);
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connectionStatus = error.toString().replaceFirst('Exception: ', '');
      });
    }
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
    final ChatSession? session = _session;
    if (message.isEmpty || _isLoading || session == null) {
      return;
    }

    final String? geminiKey1 = dotenv.env['GEMINI_API_KEY_1'];
    final String? geminiKey2 = dotenv.env['GEMINI_API_KEY_2'];
    if ((geminiKey1 == null || geminiKey1.isEmpty) && (geminiKey2 == null || geminiKey2.isEmpty)) {
      setState(() {
        _messages = <ChatMessage>[
          ..._messages,
          const ChatMessage(
            role: ChatRole.assistant,
            text: 'Set GEMINI_API_KEY_1 and GEMINI_API_KEY_2 in .env before sending a message.',
          ),
        ];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _connectionStatus = null;
      _controller.clear();
    });

    try {
      final ChatMessage userMessage = ChatMessage(role: ChatRole.user, text: message);
      setState(() {
        _messages = <ChatMessage>[..._messages, userMessage];
      });
      await _repository.addMessage(widget.user.uid, session.id, userMessage);

      final String reply = await _service.sendMessage(
        message,
        onFallback: (String status) {
          if (!mounted) {
            return;
          }

          setState(() {
            _connectionStatus = status;
          });
        },
      );

      final ChatMessage assistantMessage = ChatMessage(role: ChatRole.assistant, text: reply);
      await _repository.addMessage(widget.user.uid, session.id, assistantMessage);
    } catch (error) {
      final String messageText = error.toString().replaceFirst('Exception: ', '');
      final ChatMessage errorMessage = ChatMessage(role: ChatRole.assistant, text: messageText);

      if (mounted) {
        setState(() {
          _messages = <ChatMessage>[..._messages, errorMessage];
          _connectionStatus = messageText;
        });
      }

      try {
        await _repository.addMessage(widget.user.uid, session.id, errorMessage);
      } catch (_) {
        // Keep the local error visible when Firestore is also unavailable.
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() => AuthService.signOut();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasMessages = _messages.isNotEmpty || _isLoading;

    return Scaffold(
      drawer: StreamBuilder<List<ChatSession>>(
        stream: _repository.watchSessions(widget.user.uid),
        builder: (BuildContext context, AsyncSnapshot<List<ChatSession>> snapshot) {
          final List<ChatSession> sessions = snapshot.data ?? <ChatSession>[];

          return ChatSidebar(
            user: widget.user,
            sessions: sessions,
            activeSessionId: _session?.id,
            onSessionSelected: (ChatSession session) {
              Navigator.of(context).maybePop();
              _activateSession(session);
            },
            onNewSession: _startNewSession,
            onSignOut: _signOut,
          );
        },
      ),
      appBar: AppBar(
        title: const Text('W1 Chatbot'),
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _session == null ? 'Ready to chat' : 'Active session',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_connectionStatus != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          _connectionStatus!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _isSessionLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !hasMessages
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No messages yet. Start the conversation.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemBuilder: (BuildContext context, int index) {
                              if (index == _messages.length && _isLoading) {
                                return const ChatBubble(
                                  message: ChatMessage(
                                    role: ChatRole.assistant,
                                    text: '',
                                    isLoading: true,
                                  ),
                                );
                              }

                              final ChatMessage message = _messages[index];
                              return ChatBubble(message: message);
                            },
                            separatorBuilder: (BuildContext context, int index) {
                              return const SizedBox(height: 12);
                            },
                            itemCount: _messages.length + (_isLoading ? 1 : 0),
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
                          onPressed: _isLoading || _isSessionLoading ? null : _sendMessage,
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
