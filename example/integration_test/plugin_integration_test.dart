// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_warden/flutter_warden.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FlutterWarden init and capture', (WidgetTester tester) async {
    await FlutterWarden.initWithOptions(
      const WardenOptions(
        botToken: 'integration_test_token',
        chatId: 'integration_test_chat',
      ),
      appRunner: () => runApp(
        const MaterialApp(
          home: Scaffold(body: Text('Warden test')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(FlutterWarden.isInitialized, isTrue);

    // captureMessage should not throw (delivery may fail with fake token)
    await FlutterWarden.captureMessage('Integration test message');
  });
}
