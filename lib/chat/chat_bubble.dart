import 'package:flutter/material.dart';

import 'chat_message.dart';
import 'thinking_indicator.dart';

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
