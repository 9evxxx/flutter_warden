import 'package:dio/dio.dart';

import 'package:flutter_warden/flutter_warden.dart';

/// Dio interceptor that reports failed HTTP requests to Telegram via FlutterWarden.
///
/// Add to your Dio client:
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(WardenDioInterceptor());
/// ```
///
/// Only reports when [FlutterWarden.isInitialized] is true.
class WardenDioInterceptor extends Interceptor {
  /// Optional: report only when status code is in this range (e.g. 4xx, 5xx).
  /// If null, all Dio errors are reported.
  final bool Function(int? statusCode)? reportWhen;

  WardenDioInterceptor({this.reportWhen});

  /// Reports only when response status is 4xx or 5xx (not connection/timeout errors).
  factory WardenDioInterceptor.only4xx5xx() => WardenDioInterceptor(
        reportWhen: (statusCode) =>
            statusCode != null && statusCode >= 400 && statusCode < 600,
      );

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (FlutterWarden.isInitialized) {
      final statusCode = err.response?.statusCode;
      final shouldReport = reportWhen == null || reportWhen!(statusCode);
      if (shouldReport) {
        _report(err);
      }
    }
    handler.next(err);
  }

  void _report(DioException err) {
    final opts = err.requestOptions;
    String? requestBody;
    if (opts.data != null) {
      if (opts.data is String) {
        requestBody = opts.data as String;
      } else if (opts.data is Map || opts.data is List) {
        try {
          requestBody = opts.data.toString();
        } catch (_) {
          requestBody = null;
        }
      } else {
        requestBody = opts.data.toString();
      }
    }

    String? responseBody;
    final response = err.response;
    if (response?.data != null) {
      if (response!.data is String) {
        responseBody = response.data as String;
      } else {
        try {
          responseBody = response.data.toString();
        } catch (_) {
          responseBody = null;
        }
      }
    }

    FlutterWarden.captureHttpError(
      method: opts.method,
      url: opts.uri.toString(),
      statusCode: response?.statusCode,
      requestBody: requestBody,
      responseBody: responseBody,
      exception: err.error ?? err,
      stackTrace: err.stackTrace,
    );
  }
}
