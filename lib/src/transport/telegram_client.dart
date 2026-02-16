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

  /// Sends [text] to the configured Telegram chat.
  /// Telegram message length limit is 4096; longer text is truncated.
  Future<void> send(String text) async {
    if (!_options.enabled) return;

    const maxLength = 4096;
    final payload = text.length > maxLength
        ? '${text.substring(0, maxLength - 20)}…\n[truncated]'
        : text;

    final uri = Uri.parse('$_baseUrl${_options.botToken}/sendMessage');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _options.chatId,
          'text': payload,
          'parse_mode': 'HTML',
          'disable_web_page_preview': true,
        }),
      ).timeout(const Duration(seconds: 10));

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

  Future<Map<String, String?>?> _deviceContext() async {
    if (!_options.includeDeviceContext) return null;
    final ctx = await ReportContext.collect(includeIp: _options.includeIp);
    if (ctx == null || ctx.isEmpty) return null;
    return ctx.toMap();
  }

  /// Builds a readable error report from exception and optional stack trace.
  Future<String> formatException(Object exception, [StackTrace? stackTrace]) async {
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
}
