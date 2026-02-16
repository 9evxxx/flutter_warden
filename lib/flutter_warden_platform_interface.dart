import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_warden_method_channel.dart';

abstract class FlutterWardenPlatform extends PlatformInterface {
  /// Constructs a FlutterWardenPlatform.
  FlutterWardenPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterWardenPlatform _instance = MethodChannelFlutterWarden();

  /// The default instance of [FlutterWardenPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterWarden].
  static FlutterWardenPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterWardenPlatform] when
  /// they register themselves.
  static set instance(FlutterWardenPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
