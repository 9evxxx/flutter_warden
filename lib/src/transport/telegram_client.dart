import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/options.dart';
import '../core/report_context.dart';
import '../formatters/telegram_templates.dart';

/// Sends formatted error/message payloads to Telegram via Bot API.
class TelegramClient {
  TelegramClient(this._options);

  final WardenOptions _options;

  static const String _baseUrl = 'https://api.telegram.org/bot';
  static const int _maxMessageLength = 4096;
  static const String _truncatedSuffix = '…\n[truncated]';

  /// Sends [text] to the configured Telegram chat.
  /// Telegram message length limit is 4096.
  /// For long messages we fallback to plain text to avoid cutting HTML tags.
  Future<void> send(String text) async {
    if (!_options.enabled) return;

    final payload = text.length > _maxMessageLength
        ? _truncate(_stripHtml(text), _maxMessageLength)
        : text;
    final useHtml = text.length <= _maxMessageLength;

    final uri = Uri.parse('$_baseUrl${_options.botToken}/sendMessage');
    try {
      final response = await _postMessage(
        uri: uri,
        text: payload,
        useHtml: useHtml,
      );

      if (response.statusCode == 400 &&
          useHtml &&
          response.body.contains("can't parse entities")) {
        final fallbackPayload = _truncate(_stripHtml(text), _maxMessageLength);
        await _postMessage(uri: uri, text: fallbackPayload, useHtml: false);
        return;
      }

      if (response.statusCode != 200 && kDebugMode) {
        debugPrint(
          'FlutterWarden: Telegram send failed ${response.statusCode} ${response.body}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FlutterWarden: Failed to send to Telegram: $e\n$st');
      }
    }
  }

  Future<http.Response> _postMessage({
    required Uri uri,
    required String text,
    required bool useHtml,
  }) {
    final body = <String, Object>{
      'chat_id': _options.chatId,
      'text': text,
      'disable_web_page_preview': true,
    };
    if (useHtml) {
      body['parse_mode'] = 'HTML';
    }

    return http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<Map<String, String?>?> _deviceContext() async {
    if (!_options.includeDeviceContext) return null;
    final ctx = await ReportContext.collect(includeIp: _options.includeIp);
    if (ctx == null || ctx.isEmpty) return null;
    return ctx.toMap();
  }

  /// Builds a readable error report from exception and optional stack trace.
  Future<String> formatException(
    Object exception, [
    StackTrace? stackTrace,
  ]) async {
    final type = exception.runtimeType.toString();
    final message = exception.toString();
    final deviceContext = await _deviceContext();
    return formatExceptionTemplate(
      exceptionType: type,
      exceptionMessage: message,
      stackTrace: stackTrace?.toString(),
      environment: _options.environment,
      release: _options.release,
      deviceContext: deviceContext,
      escape: _escape,
    );
  }

  /// Builds a simple message report.
  Future<String> formatMessage(String message) async {
    final deviceContext = await _deviceContext();
    return formatMessageTemplate(
      message: message,
      environment: _options.environment,
      release: _options.release,
      deviceContext: deviceContext,
      escape: _escape,
    );
  }

  /// Builds an HTTP error report (method, url, status, bodies, exception).
  Future<String> formatHttpError({
    required String method,
    required String url,
    int? statusCode,
    String? requestBody,
    String? responseBody,
    String? exceptionMessage,
    String? stackTrace,
  }) async {
    final deviceContext = await _deviceContext();
    return formatHttpErrorTemplate(
      method: method,
      url: url,
      statusCode: statusCode,
      requestBody: requestBody,
      responseBody: responseBody,
      exceptionMessage: exceptionMessage,
      stackTrace: stackTrace,
      environment: _options.environment,
      release: _options.release,
      deviceContext: deviceContext,
      escape: _escape,
    );
  }

  static String _escape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

  static String _truncate(String s, int maxLength) {
    if (s.length <= maxLength) return s;
    final keep = maxLength - _truncatedSuffix.length;
    if (keep <= 0) return s.substring(0, maxLength);
    return '${s.substring(0, keep)}$_truncatedSuffix';
  }
}
