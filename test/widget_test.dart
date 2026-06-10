import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:w1/main.dart';

void main() {
  testWidgets('renders the W1 chatbot screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('W1 Chatbot'), findsWidgets);
    expect(find.text('Plain text responses only'), findsOneWidget);
    expect(find.text('Hi, I am W1 Chatbot. Ask me anything and I will reply in plain text only.'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
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
