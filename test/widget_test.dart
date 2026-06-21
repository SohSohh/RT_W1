import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:w1/chat/chat_bubble.dart';
import 'package:w1/chat/chat_message.dart';
import 'package:w1/chat/thinking_indicator.dart';

void main() {
  testWidgets('renders a chat bubble', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: ChatMessage(role: ChatRole.user, text: 'Hello'),
          ),
        ),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('builds the thinking indicator', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ThinkingIndicator(),
        ),
      ),
    );

    expect(find.text('W1 Chatbot is thinking'), findsOneWidget);
  });
}
