// HTML templates for Telegram messages (errors and info) with emojis.
// All user content is escaped when interpolated; only structure uses HTML.

const String _header = '🛡️ <b>Flutter Warden</b>';

/// Keys for [deviceContext] map (device/app context).
const List<String> deviceContextKeys = [
  'Platform',
  'OS',
  'Device',
  'Brand',
  'App',
  'Version',
  'Build',
  'IP',
  'Locale',
];

void _appendDeviceContext(
  StringBuffer buffer,
  Map<String, String?>? deviceContext,
  String Function(String text) escape,
) {
  if (deviceContext == null || deviceContext.isEmpty) return;
  buffer.writeln();
  buffer.writeln('📱 <b>Device / Context</b>');
  for (final key in deviceContextKeys) {
    final value = deviceContext[key];
    if (value != null && value.isNotEmpty) {
      buffer.writeln('  $key: <code>${escape(value)}</code>');
    }
  }
}

String formatExceptionTemplate({
  required String exceptionType,
  required String exceptionMessage,
  required String? stackTrace,
  required String? environment,
  required String? release,
  Map<String, String?>? deviceContext,
  required String Function(String text) escape,
}) {
  final buffer = StringBuffer();
  buffer.writeln(_header);
  buffer.writeln('━━━━━━━━━━━━━━━━');
  buffer.writeln('💥 <b>Exception</b>');
  buffer.writeln();
  buffer.writeln('📌 <b>Type:</b> <code>${escape(exceptionType)}</code>');
  buffer.writeln('📝 <b>Message:</b>');
  buffer.writeln(escape(exceptionMessage));
  if (stackTrace != null && stackTrace.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('📋 <b>Stack trace:</b>');
    buffer.writeln('<pre>${escape(stackTrace)}</pre>');
  }
  if (environment != null || release != null) {
    buffer.writeln();
    buffer.writeln('🏷️');
    if (environment != null) buffer.writeln('  Env: <code>${escape(environment)}</code>');
    if (release != null) buffer.writeln('  Release: <code>${escape(release)}</code>');
  }
  _appendDeviceContext(buffer, deviceContext, escape);
  return buffer.toString();
}

/// Template for a simple message (info / custom event).
String formatMessageTemplate({
  required String message,
  required String? environment,
  required String? release,
  Map<String, String?>? deviceContext,
  required String Function(String text) escape,
}) {
  final buffer = StringBuffer();
  buffer.writeln(_header);
  buffer.writeln('━━━━━━━━━━━━━━━━');
  buffer.writeln('📢 <b>Message</b>');
  buffer.writeln();
  buffer.writeln('💬 ${escape(message)}');
  if (environment != null || release != null) {
    buffer.writeln();
    buffer.writeln('🏷️');
    if (environment != null) buffer.writeln('  Env: <code>${escape(environment)}</code>');
    if (release != null) buffer.writeln('  Release: <code>${escape(release)}</code>');
  }
  _appendDeviceContext(buffer, deviceContext, escape);
  return buffer.toString();
}

/// Template for HTTP request/response errors (Dio, http, etc.).
String formatHttpErrorTemplate({
  required String method,
  required String url,
  int? statusCode,
  String? requestBody,
  String? responseBody,
  String? exceptionMessage,
  String? stackTrace,
  required String? environment,
  required String? release,
  Map<String, String?>? deviceContext,
  required String Function(String text) escape,
}) {
  final buffer = StringBuffer();
  buffer.writeln(_header);
  buffer.writeln('━━━━━━━━━━━━━━━━');
  buffer.writeln('🌐 <b>HTTP Error</b>');
  buffer.writeln();
  buffer.writeln('📤 <b>Request</b>');
  buffer.writeln('  <code>${escape(method)}</code> ${escape(url)}');
  if (requestBody != null && requestBody.isNotEmpty) {
    buffer.writeln('  <b>Body:</b>');
    buffer.writeln('  <pre>${escape(_truncate(requestBody, 500))}</pre>');
  }
  buffer.writeln();
  buffer.writeln('📥 <b>Response</b>');
  if (statusCode != null) {
    final emoji = statusCode >= 500 ? '🔴' : (statusCode >= 400 ? '🟠' : '🟡');
    buffer.writeln('  $emoji <b>Status:</b> <code>$statusCode</code>');
  }
  if (responseBody != null && responseBody.isNotEmpty) {
    buffer.writeln('  <b>Body:</b>');
    buffer.writeln('  <pre>${escape(_truncate(responseBody, 800))}</pre>');
  }
  if (exceptionMessage != null && exceptionMessage.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('💥 <b>Exception:</b>');
    buffer.writeln(escape(exceptionMessage));
  }
  if (stackTrace != null && stackTrace.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('📋 <b>Stack trace:</b>');
    buffer.writeln('<pre>${escape(_truncate(stackTrace, 600))}</pre>');
  }
  if (environment != null || release != null) {
    buffer.writeln();
    buffer.writeln('🏷️');
    if (environment != null) buffer.writeln('  Env: <code>${escape(environment)}</code>');
    if (release != null) buffer.writeln('  Release: <code>${escape(release)}</code>');
  }
  _appendDeviceContext(buffer, deviceContext, escape);
  return buffer.toString();
}

String _truncate(String s, int maxLen) {
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen)}\n… [truncated ${s.length - maxLen} chars]';
}
