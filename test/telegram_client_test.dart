import 'dart:convert';

import 'package:flutter_warden/src/core/options.dart';
import 'package:flutter_warden/src/transport/telegram_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'retries as plain text when Telegram returns parse entities error',
    () async {
      final requests = <Map<String, dynamic>>[];

      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        if (requests.length == 1) {
          return http.Response(
            '{"ok":false,"error_code":400,"description":"Bad Request: can\\\'t parse entities: Can\\\'t find end tag corresponding to start tag \\"pre\\""}',
            400,
          );
        }
        return http.Response('{"ok":true,"result":{}}', 200);
      });

      final client = TelegramClient(
        const WardenOptions(
          botToken: 'token',
          chatId: 'chat',
          sendInDebug: true,
          includeDeviceContext: false,
          includeIp: false,
        ),
        httpClient: mock,
      );

      await client.send('<b>Hello</b>\n<pre>line 1\nline 2</pre>');

      expect(requests.length, 2);
      expect(requests[0]['parse_mode'], 'HTML');
      expect(requests[1].containsKey('parse_mode'), isFalse);
      expect(requests[1]['text'], 'Hello\nline 1\nline 2');
    },
  );

  test('sends plain text directly for unbalanced html tags', () async {
    final requests = <Map<String, dynamic>>[];

    final mock = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      return http.Response('{"ok":true,"result":{}}', 200);
    });

    final client = TelegramClient(
      const WardenOptions(
        botToken: 'token',
        chatId: 'chat',
        sendInDebug: true,
        includeDeviceContext: false,
        includeIp: false,
      ),
      httpClient: mock,
    );

    await client.send('<b>Oops</b>\n<pre>broken');

    expect(requests.length, 1);
    expect(requests[0].containsKey('parse_mode'), isFalse);
    expect(requests[0]['text'], 'Oops\nbroken');
  });

  test('does not send in debug when sendInDebug is false', () async {
    var called = false;

    final mock = MockClient((request) async {
      called = true;
      return http.Response('{"ok":true,"result":{}}', 200);
    });

    final client = TelegramClient(
      const WardenOptions(
        botToken: 'token',
        chatId: 'chat',
        sendInDebug: false,
        includeDeviceContext: false,
        includeIp: false,
      ),
      httpClient: mock,
    );

    await client.send('test');
    expect(called, isFalse);
  });
}
