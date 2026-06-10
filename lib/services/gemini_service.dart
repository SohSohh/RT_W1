import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _defaultBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  static const Map<String, Object> _systemInstruction = <String, Object>{
    'parts': <Map<String, String>>[
      <String, String>{
        'text':
            'Reply in plain text only. Do not use markdown, bullets, headings, code fences, tables, emojis, or special formatting unless the user explicitly asks for them.',
      },
    ],
  };

  Future<String> sendMessage(String apiKey, String message) async {
    final String endpoint = dotenv.env['GEMINI_API_URL']?.trim().isNotEmpty == true
        ? dotenv.env['GEMINI_API_URL']!.trim()
        : _defaultBaseUrl;

    final Uri uri = Uri.parse(endpoint).replace(queryParameters: <String, String>{
      ...Uri.parse(endpoint).queryParameters,
      'key': apiKey,
    });

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'systemInstruction': _systemInstruction,
              'contents': <Map<String, Object>>[
                <String, Object>{
                  'role': 'user',
                  'parts': <Map<String, String>>[
                    <String, String>{'text': message},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw Exception('UNAVAILABLE: Gemini is temporarily unreachable. Check your connection and try again.');
    } on TimeoutException {
      throw Exception('UNAVAILABLE: Gemini took too long to respond. Please try again.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_friendlyApiError(response.statusCode, response.body));
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

    String? content;

    if (data.containsKey('candidates')) {
      final List<dynamic> candidates = data['candidates'] as List<dynamic>;
      if (candidates.isNotEmpty) {
        final first = candidates.first as Map<String, dynamic>;
        final Map<String, dynamic>? candidateContent = first['content'] as Map<String, dynamic>?;
        final List<dynamic>? parts = candidateContent?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final Map<String, dynamic> firstPart = parts.first as Map<String, dynamic>;
          content = firstPart['text'] as String?;
        }
      }
    }

    if (content == null || content.trim().isEmpty) {
      throw Exception('Gemini API returned unexpected response: ${response.body}');
    }

    return content.trim();
  }

  String _friendlyApiError(int statusCode, String body) {
    final String upperBody = body.toUpperCase();
    if (statusCode == 503 || upperBody.contains('UNAVAILABLE')) {
      return 'UNAVAILABLE: Gemini is temporarily unavailable. Please try again.';
    }

    if (statusCode == 429 || upperBody.contains('RESOURCE_EXHAUSTED')) {
      return 'UNAVAILABLE: Gemini is busy right now. Please retry in a moment.';
    }

    if (statusCode == 401 || upperBody.contains('UNAUTHENTICATED')) {
      return 'UNAVAILABLE: Authentication failed. Check GEMINI_API_KEY in .env.';
    }

    if (statusCode == 404 || upperBody.contains('NOT_FOUND')) {
      return 'UNAVAILABLE: The configured Gemini model or endpoint was not found.';
    }

    return 'UNAVAILABLE: Gemini request failed with status $statusCode.';
  }
}
