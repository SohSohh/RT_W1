import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_session.dart';

class ChatSidebar extends StatelessWidget {
  const ChatSidebar({
    super.key,
    required this.user,
    required this.sessions,
    required this.activeSessionId,
    required this.onSessionSelected,
    required this.onNewSession,
    required this.onSignOut,
  });

  final User user;
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final ValueChanged<ChatSession> onSessionSelected;
  final VoidCallback onNewSession;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'W1 Chatbot',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? 'Signed in',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNewSession,
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('New session'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Session history',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: sessions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No sessions yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemBuilder: (BuildContext context, int index) {
                        final ChatSession session = sessions[index];
                        final bool isActive = session.id == activeSessionId;

                        return ListTile(
                          selected: isActive,
                          selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: Text(
                            session.lastMessagePreview.isEmpty ? 'New chat' : session.lastMessagePreview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatSessionDate(session.updatedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onSessionSelected(session),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 4),
                      itemCount: sessions.length,
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Log out'),
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSessionDate(DateTime date) {
    final DateTime local = date.toLocal();
    return '${local.month}/${local.day}/${local.year} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
