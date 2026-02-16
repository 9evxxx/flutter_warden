import 'dart:async' show runZoned, ZoneSpecification, unawaited;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../transport/telegram_client.dart';
import 'options.dart';
import 'report_context.dart';

/// Error capture and reporting to Telegram.
///
/// Usage:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await FlutterWarden.init(
///     (options) {
///       options.botToken = 'YOUR_BOT_TOKEN';
///       options.chatId = 'YOUR_CHAT_ID';
///     },
///     appRunner: () => runApp(MyApp()),
///   );
/// }
/// ```
///
/// Manual capture:
/// ```dart
/// try {
///   // ...
/// } catch (e, st) {
///   await FlutterWarden.captureException(e, stackTrace: st);
/// }
/// await FlutterWarden.captureMessage('Something happened');
/// ```
class FlutterWarden {
  FlutterWarden._();

  static WardenOptions? _options;
  static TelegramClient? _client;

  /// Whether [init] has been called successfully.
  static bool get isInitialized => _options != null && _client != null;

  /// Initializes FlutterWarden with [optionsBuilder] and runs the app via [appRunner].
  ///
  /// Call this as early as possible (e.g. in [main] after
  /// [WidgetsFlutterBinding.ensureInitialized]). Sets up global error handlers
  /// so uncaught Flutter and Dart errors are sent to Telegram.
  ///
  /// Example:
  /// ```dart
  /// await FlutterWarden.init(
  ///   (options) {
  ///     options.botToken = 'YOUR_BOT_TOKEN';
  ///     options.chatId = 'YOUR_CHAT_ID';
  ///     options.environment = 'production';
  ///   },
  ///   appRunner: () => runApp(MyApp()),
  /// );
  /// ```
  static Future<void> init(
    void Function(WardenOptionsBuilder options) optionsBuilder, {
    required VoidCallback appRunner,
  }) async {
    final builder = WardenOptionsBuilder();
    optionsBuilder(builder);
    final options = builder.build();
    if (options.botToken.isEmpty || options.chatId.isEmpty) {
      throw ArgumentError('WardenOptions.botToken and chatId are required');
    }
    _options = options;
    ReportContext.clearCache();
    _client = TelegramClient(options);
    _installErrorHandlers();
    appRunner();
  }

  /// Initializes FlutterWarden with pre-built [options] and runs the app via [appRunner].
  static Future<void> initWithOptions(
    WardenOptions options, {
    required VoidCallback appRunner,
  }) async {
    if (options.botToken.isEmpty || options.chatId.isEmpty) {
      throw ArgumentError('WardenOptions.botToken and chatId are required');
    }
    _options = options;
    ReportContext.clearCache();
    _client = TelegramClient(options);
    _installErrorHandlers();
    appRunner();
  }

  static void _installErrorHandlers() {
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final client = _client;
      if (client != null) {
        unawaited(
          client
              .formatException(
                details.exception,
                details.stack ?? StackTrace.current,
              )
              .then(client.send),
        );
      }
      previousFlutterError?.call(details);
    };

    final previousOnError = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
      final client = _client;
      if (client != null) {
        unawaited(
          client.formatException(error, stackTrace).then(client.send),
        );
      }
      final handled = previousOnError?.call(error, stackTrace) ?? false;
      return handled;
    };
  }

  /// Captures an [exception] and optional [stackTrace], formats it, and sends to Telegram.
  static Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
  }) async {
    if (_client == null) return;
    final text = await _client!.formatException(exception, stackTrace);
    await _client!.send(text);
  }

  /// Captures a [message] and sends it to Telegram.
  static Future<void> captureMessage(String message) async {
    if (_client == null) return;
    final text = await _client!.formatMessage(message);
    await _client!.send(text);
  }

  /// Captures an HTTP error and sends it to Telegram (for Dio, http, etc.).
  ///
  /// Use [captureHttpErrorFromResponse] for package:http, or add
  /// [WardenDioInterceptor] for Dio.
  static Future<void> captureHttpError({
    required String method,
    required String url,
    int? statusCode,
    String? requestBody,
    String? responseBody,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    if (_client == null) return;
    final text = await _client!.formatHttpError(
      method: method,
      url: url,
      statusCode: statusCode,
      requestBody: requestBody,
      responseBody: responseBody,
      exceptionMessage: exception?.toString(),
      stackTrace: stackTrace?.toString(),
    );
    await _client!.send(text);
  }

  /// Captures an HTTP error from package:http [Response].
  /// Call when [response.statusCode] >= 400 or on exception.
  static Future<void> captureHttpErrorFromResponse(
    http.Response response, {
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    final request = response.request;
    final method = request is http.Request ? request.method : 'GET';
    await captureHttpError(
      method: method,
      url: request?.url.toString() ?? '',
      statusCode: response.statusCode,
      responseBody: response.body,
      exception: exception,
      stackTrace: stackTrace,
    );
  }

  /// Runs [callback] in a zone that reports uncaught async errors to Telegram.
  /// Use this if you want zone-based capture in addition to [init] (e.g. for tests).
  static R runZonedGuarded<R>(R Function() callback) {
    return runZoned<R>(
      callback,
      zoneValues: const {},
      zoneSpecification: ZoneSpecification(
        handleUncaughtError: (self, delegate, zone, error, stackTrace) {
          captureException(error, stackTrace: stackTrace);
        },
      ),
    );
  }
}
