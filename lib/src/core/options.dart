/// Configuration for FlutterWarden (Telegram bot token and chat).
class WardenOptions {
  /// Creates [WardenOptions].
  ///
  /// [botToken] - Telegram Bot API token from @BotFather.
  /// [chatId] - Telegram chat ID where errors will be sent (user or group).
  const WardenOptions({
    required this.botToken,
    required this.chatId,
    this.environment,
    this.release,
    this.enabled = true,
    this.sendInDebug = false,
    this.includeDeviceContext = true,
    this.includeIp = true,
    this.attachScreenshotOnError = false,
  });

  /// Telegram Bot API token.
  final String botToken;

  /// Telegram chat ID (numeric or @username for public channels).
  final String chatId;

  /// Optional environment name (e.g. 'production', 'staging').
  final String? environment;

  /// Optional release/version identifier.
  final String? release;

  /// When false, capture methods no-op (useful for disabling in debug).
  final bool enabled;

  /// When true, allows sending events in debug builds.
  ///
  /// Defaults to false, so debug builds don't send Telegram reports.
  final bool sendInDebug;

  /// When true (default), device/app/OS context is included in reports.
  final bool includeDeviceContext;

  /// When true (default), public IP is fetched and included in reports.
  final bool includeIp;

  /// When true, FlutterWarden tries to attach a screenshot for captured errors.
  final bool attachScreenshotOnError;
}

/// Mutable builder for [WardenOptions], used with [FlutterWarden.init] callback.
class WardenOptionsBuilder {
  /// Telegram Bot API token (from @BotFather).
  String botToken = '';

  /// Telegram chat ID (user or group).
  String chatId = '';

  /// Optional environment name.
  String? environment;

  /// Optional release/version.
  String? release;

  /// When false, capture is disabled. Defaults to true.
  bool enabled = true;

  /// When true, allows sending events in debug builds. Defaults to false.
  bool sendInDebug = false;

  /// When false, device/OS/app context is omitted from reports. Defaults to true.
  bool includeDeviceContext = true;

  /// When false, IP is not fetched. Defaults to true.
  bool includeIp = true;

  /// When true, FlutterWarden tries to attach a screenshot for captured errors.
  bool attachScreenshotOnError = false;

  /// Builds immutable [WardenOptions].
  WardenOptions build() => WardenOptions(
    botToken: botToken,
    chatId: chatId,
    environment: environment,
    release: release,
    enabled: enabled,
    sendInDebug: sendInDebug,
    includeDeviceContext: includeDeviceContext,
    includeIp: includeIp,
    attachScreenshotOnError: attachScreenshotOnError,
  );
}
