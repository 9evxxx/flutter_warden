import 'dart:async' show runZoned, ZoneSpecification, unawaited;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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
  static final GlobalKey _screenshotBoundaryKey = GlobalKey(
    debugLabel: 'flutter_warden_screenshot_boundary',
  );

  /// Whether [init] has been called successfully.
  static bool get isInitialized => _options != null && _client != null;

  /// Key used by [WardenScreenshotBoundary] to capture screenshots.
  static GlobalKey get screenshotBoundaryKey => _screenshotBoundaryKey;

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
      unawaited(
        _sendExceptionWithOptionalScreenshot(
          details.exception,
          details.stack ?? StackTrace.current,
        ),
      );
      previousFlutterError?.call(details);
    };

    final previousOnError = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError =
        (Object error, StackTrace stackTrace) {
          unawaited(_sendExceptionWithOptionalScreenshot(error, stackTrace));
          final handled = previousOnError?.call(error, stackTrace) ?? false;
          return handled;
        };
  }

  /// Captures an [exception] and optional [stackTrace], formats it, and sends to Telegram.
  static Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
  }) async {
    await _sendExceptionWithOptionalScreenshot(exception, stackTrace);
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

  static Future<void> _sendExceptionWithOptionalScreenshot(
    Object exception,
    StackTrace? stackTrace,
  ) async {
    final client = _client;
    final options = _options;
    if (client == null || options == null) return;

    final text = await client.formatException(exception, stackTrace);
    if (!options.attachScreenshotOnError) {
      await client.send(text);
      return;
    }

    final screenshot = await _captureScreenshot();
    if (screenshot != null && screenshot.isNotEmpty) {
      await client.sendPhoto(screenshot, caption: text);
      await client.send(text);
      return;
    }

    await client.send(text);
  }

  static Future<Uint8List?> _captureScreenshot() async {
    try {
      final context = _screenshotBoundaryKey.currentContext;
      if (context == null) return null;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;
      final view = View.maybeOf(context);
      if (view == null) return null;

      if (renderObject.debugNeedsPaint) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      final image = await renderObject.toImage(
        pixelRatio: view.devicePixelRatio,
      );
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}

/// Wrap your app with this widget to enable screenshot attachments on errors.
class WardenScreenshotBoundary extends StatelessWidget {
  const WardenScreenshotBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: FlutterWarden.screenshotBoundaryKey,
      child: child,
    );
  }
}
