import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_warden/flutter_warden.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterWarden.init(
    (options) {
      options.botToken = 'YOUR_BOT_TOKEN'; // Replace with your Telegram bot token
      options.chatId = 'YOUR_CHAT_ID'; // Replace with your Telegram chat ID
      options.environment = 'development';
    },
    appRunner: () => runApp(const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Warden Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _ExamplePage(),
    );
  }
}

class _ExamplePage extends StatefulWidget {
  const _ExamplePage();

  @override
  State<_ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<_ExamplePage> {
  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio();
    _dio.interceptors.add(WardenDioInterceptor());
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Warden'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Error capture → Telegram',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await FlutterWarden.captureException(
                    StateError('Example exception'),
                    stackTrace: StackTrace.current,
                  );
                  _showSnack('Exception sent to Telegram');
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Capture exception'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await FlutterWarden.captureMessage(
                      'Example message from Flutter Warden');
                  _showSnack('Message sent to Telegram');
                },
                icon: const Icon(Icons.message),
                label: const Text('Capture message'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  throw StateError(
                      'Uncaught error (should be sent to Telegram)');
                },
                icon: const Icon(Icons.warning),
                label: const Text('Throw uncaught error'),
              ),
              const SizedBox(height: 32),
              const Text(
                'HTTP errors',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    await _dio.get(
                        'https://httpstat.us/404'); // returns 404
                  } on DioException {
                    _showSnack('Dio 404 → reported to Telegram');
                  }
                },
                icon: const Icon(Icons.http),
                label: const Text('Dio: trigger 404 (interceptor reports)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final response = await http.get(
                      Uri.parse('https://httpstat.us/500'));
                  if (response.statusCode >= 400) {
                    await FlutterWarden.captureHttpErrorFromResponse(response);
                    _showSnack('http 500 → reported to Telegram');
                  }
                },
                icon: const Icon(Icons.wifi),
                label: const Text('http: trigger 500 & capture'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
