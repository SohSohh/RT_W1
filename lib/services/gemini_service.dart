import 'dart:async';
import 'dart:convert';
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

  Future<String> sendMessage(
    String message, {
    void Function(String message)? onFallback,
  }) async {
    final List<String> apiKeys = <String>[
      dotenv.env['GEMINI_API_KEY_1']?.trim() ?? '',
      dotenv.env['GEMINI_API_KEY_2']?.trim() ?? '',
    ].where((String value) => value.isNotEmpty).toList(growable: false);

    if (apiKeys.isEmpty) {
      throw Exception('Set GEMINI_API_KEY_1 and GEMINI_API_KEY_2 in .env before sending a message.');
    }

    Exception? lastError;
    for (int index = 0; index < apiKeys.length; index++) {
      final String apiKey = apiKeys[index];
      try {
        return await _sendWithKey(apiKey, message);
      } catch (error) {
        lastError = error is Exception ? error : Exception(error.toString());
        if (index == 0 && apiKeys.length > 1) {
          onFallback?.call('Primary Gemini key failed. Retrying with backup key...');
        }
      }
    }

    throw lastError ?? Exception('Gemini request failed.');
  }

  Future<String> _sendWithKey(String apiKey, String message) async {
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
    final List<dynamic>? candidates = data['candidates'] as List<dynamic>?;
    final Map<String, dynamic>? firstCandidate = candidates != null && candidates.isNotEmpty
        ? candidates.first as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? contentObject = firstCandidate?['content'] as Map<String, dynamic>?;
    final List<dynamic>? parts = contentObject?['parts'] as List<dynamic>?;
    final Map<String, dynamic>? firstPart = parts != null && parts.isNotEmpty
        ? parts.first as Map<String, dynamic>
        : null;
    final String? content = firstPart?['text'] as String?;

    if (content == null || content.trim().isEmpty) {
      throw Exception('Gemini API returned unexpected response: ${response.body}');
    }

    return content.trim();
  }

  String _friendlyApiError(int statusCode, String body) {
    final String upperBody = body.toUpperCase();
    final String details = _extractErrorMessage(body);
    if (statusCode == 503 || upperBody.contains('UNAVAILABLE')) {
      return 'UNAVAILABLE: Gemini is temporarily unavailable. $details';
    }

    if (statusCode == 429 || upperBody.contains('RESOURCE_EXHAUSTED')) {
      return 'UNAVAILABLE: Gemini is busy right now. $details';
    }

    if (statusCode == 400 || upperBody.contains('INVALID_ARGUMENT')) {
      return 'UNAVAILABLE: Gemini rejected the request. $details';
    }

    if (statusCode == 401 || statusCode == 403 || upperBody.contains('UNAUTHENTICATED')) {
      return 'UNAVAILABLE: Gemini authentication failed. Check GEMINI_API_KEY_1 and GEMINI_API_KEY_2 in .env. $details';
    }

    if (statusCode == 404 || upperBody.contains('NOT_FOUND')) {
      return 'UNAVAILABLE: The configured Gemini model or endpoint was not found. $details';
    }

    return 'UNAVAILABLE: Gemini request failed with status $statusCode. $details';
  }

  String _extractErrorMessage(String body) {
    if (body.trim().isEmpty) {
      return 'No error details were returned.';
    }

    try {
      final Object decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final Object? error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final Object? message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }

        final Object? message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      // Fall through to compact raw body.
    }

    final String compactBody = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return compactBody.length <= 240 ? compactBody : '${compactBody.substring(0, 237)}...';
  }
}
