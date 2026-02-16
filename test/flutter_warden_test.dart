import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_warden/flutter_warden.dart';
import 'package:http/http.dart' as http;

void main() {
  test('attachScreenshotOnError defaults to false and is configurable', () {
    const defaults = WardenOptions(botToken: 'a', chatId: 'b');
    expect(defaults.attachScreenshotOnError, isFalse);
    expect(defaults.sendInDebug, isFalse);

    final builder = WardenOptionsBuilder()
      ..botToken = 'a'
      ..chatId = 'b'
      ..sendInDebug = true
      ..attachScreenshotOnError = true;
    final built = builder.build();
    expect(built.attachScreenshotOnError, isTrue);
    expect(built.sendInDebug, isTrue);
  });

  test('isInitialized is false before init', () {
    expect(FlutterWarden.isInitialized, isFalse);
  });

  test('captureException does not throw when not initialized', () async {
    await FlutterWarden.captureException(
      StateError('test'),
      stackTrace: StackTrace.current,
    );
  });

  test('captureMessage does not throw when not initialized', () async {
    await FlutterWarden.captureMessage('test message');
  });

  test('captureHttpError does not throw when not initialized', () async {
    await FlutterWarden.captureHttpError(
      method: 'GET',
      url: 'https://example.com',
      statusCode: 500,
    );
  });

  test('init with options sets isInitialized and runs appRunner', () async {
    var appRunnerCalled = false;
    await FlutterWarden.initWithOptions(
      const WardenOptions(botToken: 'test_token', chatId: 'test_chat'),
      appRunner: () {
        appRunnerCalled = true;
      },
    );
    expect(FlutterWarden.isInitialized, isTrue);
    expect(appRunnerCalled, isTrue);
  });

  test('init then captureException sends error (no throw)', () async {
    await FlutterWarden.initWithOptions(
      const WardenOptions(botToken: 'test_token', chatId: 'test_chat'),
      appRunner: () {},
    );
    expect(FlutterWarden.isInitialized, isTrue);

    await FlutterWarden.captureException(
      StateError('Test error for unit test'),
      stackTrace: StackTrace.current,
    );

    await FlutterWarden.captureMessage('Test message for unit test');
  });

  test('init then captureHttpError sends (no throw)', () async {
    await FlutterWarden.initWithOptions(
      const WardenOptions(botToken: '', chatId: ''),
      appRunner: () {},
    );
    await FlutterWarden.captureHttpError(
      method: 'POST',
      url: 'https://api.example.com/upload',
      statusCode: 503,
      requestBody: '{"test": true}',
      responseBody: 'Service Unavailable',
    );
  });

  test('captureHttpErrorFromResponse (no throw)', () async {
    await FlutterWarden.initWithOptions(
      const WardenOptions(botToken: 'test_token', chatId: 'test_chat'),
      appRunner: () {},
    );
    final request = http.Request(
      'GET',
      Uri.parse('https://example.com/not-found'),
    );
    final response = http.Response('Not Found', 404, request: request);
    await FlutterWarden.captureHttpErrorFromResponse(response);
  });
}
