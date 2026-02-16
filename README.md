# flutter_warden

Error capture for Flutter with delivery to Telegram. Captures uncaught errors and manual reports, formats them, and sends them to a Telegram chat via the Bot API.

## Features

- **Init + global handlers** — Initialize once; uncaught Flutter and Dart errors are sent to Telegram.
- **Manual capture** — `captureException` and `captureMessage` for explicit reporting.
- **Simple API** — `init(options, appRunner:)`, `captureException`, `captureMessage`.
- **Device / context** — Each report includes device model, OS, app version, public IP, locale.

## Setup

1. Create a Telegram bot via [@BotFather](https://t.me/BotFather) and get the bot token.
2. Get your chat ID (e.g. send a message to the bot and call `getUpdates` on the Bot API).
3. Add the package and initialize in your app.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_warden/flutter_warden.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterWarden.init(
    (options) {
      options.botToken = 'YOUR_BOT_TOKEN';
      options.chatId = 'YOUR_CHAT_ID';  // numeric or @username
      options.environment = 'production';  // optional
      options.release = '1.0.0';  // optional
      options.enabled = true;  // set false to disable in debug
      options.includeDeviceContext = true;  // device, OS, app, IP, locale
      options.includeIp = true;  // fetch public IP (one-time, cached)
    },
    appRunner: () => runApp(MyApp()),
  );
}
```

### Manual capture

```dart
try {
  // ...
} catch (e, st) {
  await FlutterWarden.captureException(e, stackTrace: st);
}

await FlutterWarden.captureMessage('Something important happened');
```

### HTTP errors (Dio)

Add the interceptor to report failed requests to Telegram:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_warden/flutter_warden.dart';

final dio = Dio();
dio.interceptors.add(WardenDioInterceptor());

// Optional: report only 4xx/5xx
dio.interceptors.add(WardenDioInterceptor(
  reportWhen: (statusCode) => statusCode != null && statusCode >= 400,
));
```

### HTTP errors (package:http)

When a response indicates an error, call `captureHttpErrorFromResponse`:

```dart
import 'package:http/http.dart' as http;
import 'package:flutter_warden/flutter_warden.dart';

final response = await http.get(Uri.parse('https://api.example.com/data'));
if (response.statusCode >= 400) {
  await FlutterWarden.captureHttpErrorFromResponse(response);
}
```

For custom clients or other HTTP libraries, use the low-level API:

```dart
await FlutterWarden.captureHttpError(
  method: 'POST',
  url: 'https://api.example.com/upload',
  statusCode: 500,
  requestBody: '{"key": "value"}',
  responseBody: responseBody,
  exception: error,
  stackTrace: stackTrace,
);
```

### Init with pre-built options

```dart
await FlutterWarden.initWithOptions(
  WardenOptions(
    botToken: '...',
    chatId: '...',
    environment: 'production',
    release: '1.0.0',
    enabled: true,
  ),
  appRunner: () => runApp(MyApp()),
);
```

## Device / context

Each report (exception, message, HTTP error) can include a **Device / Context** block:

- **Platform** — android, ios, web, macos, windows, linux
- **OS** — OS version (from device_info_plus)
- **Device** — model (e.g. Pixel 6, iPhone14,2)
- **Brand** — manufacturer (e.g. Google, Apple)
- **App** — app name
- **Version** — app version (e.g. 1.2.0)
- **Build** — build number
- **IP** — public IP (from api.ipify.org, cached)
- **Locale** — e.g. en_US

Control via options:

```dart
options.includeDeviceContext = true;  // default: true
options.includeIp = true;             // default: true (set false to skip IP fetch)
```

## Project structure

```
lib/
  flutter_warden.dart              # Public API (single entry point)
  src/
    core/                           # Domain & configuration
      options.dart                  # WardenOptions, WardenOptionsBuilder
      report_context.dart           # Device/app/IP context collection
      warden.dart                   # FlutterWarden facade (init, capture*)
    transport/                      # Delivery layer
      telegram_client.dart          # Telegram Bot API client
    formatters/                     # Message formatting
      telegram_templates.dart       # Exception / message / HTTP templates
    integrations/                   # Third-party integrations
      dio_interceptor.dart          # WardenDioInterceptor
```

- **core** — configuration and main facade; no I/O.
- **transport** — sends formatted payloads to Telegram (HTTP).
- **formatters** — pure formatting; no dependencies on transport or core.
- **integrations** — optional adapters (Dio, etc.) that call the public API.

## API summary

| Method | Description |
|--------|-------------|
| `FlutterWarden.init(optionsBuilder, appRunner:)` | Initialize and run app; sets up global error handlers. |
| `FlutterWarden.initWithOptions(options, appRunner:)` | Same with a pre-built `WardenOptions`. |
| `FlutterWarden.captureException(exception, {stackTrace})` | Send exception (and optional stack trace) to Telegram. |
| `FlutterWarden.captureMessage(message)` | Send a text message to Telegram. |
| `FlutterWarden.captureHttpError(...)` | Send HTTP error (method, url, status, bodies) to Telegram. |
| `FlutterWarden.captureHttpErrorFromResponse(response)` | Build HTTP error from package:http `Response`. |
| `FlutterWarden.isInitialized` | Whether `init` has been called. |
| `FlutterWarden.runZonedGuarded(callback)` | Run callback in a zone that reports uncaught async errors. |
| `WardenDioInterceptor` | Dio interceptor that reports failed requests to Telegram. |

## License

See [LICENSE](LICENSE).
