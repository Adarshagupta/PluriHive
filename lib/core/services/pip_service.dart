import 'package:flutter/services.dart';

/// Service for managing Picture-in-Picture (PiP) mode for specific screens
/// Currently supports: permission screen and map screen
class PipService {
  static final PipService _instance = PipService._internal();
  factory PipService() => _instance;
  PipService._internal();

  static const MethodChannel _channel = MethodChannel('territory_fitness/pip');

  bool _isInPipMode = false;
  String _currentScreen = '';
  final List<Function(bool, String)> _pipModeListeners = [];

  /// Initialize the PiP service and set up listeners
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    _isInPipMode = await isInPipMode();
    print('🖼️ PiP Service initialized. Current PiP mode: $_isInPipMode');
  }

  /// Handle method calls from native code
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPipModeChanged':
        final args = call.arguments as Map;
        final bool isInPip = args['isInPip'] as bool;
        final String screen = args['screen'] as String? ?? '';

        _isInPipMode = isInPip;
        _currentScreen = screen;

        print('🖼️ PiP mode changed: $isInPip for screen: $screen');

        // Notify all listeners
        for (var listener in _pipModeListeners) {
          listener(isInPip, screen);
        }
        break;
      default:
        print('⚠️ Unknown method call from native: ${call.method}');
    }
  }

  /// Check if PiP is supported on this device
  Future<bool> isPipSupported() async {
    try {
      final bool? supported = await _channel.invokeMethod('isPipSupported');
      return supported ?? false;
    } catch (e) {
      print('❌ Error checking PiP support: $e');
      return false;
    }
  }

  /// Enter Picture-in-Picture mode
  Future<bool> enterPipMode() async {
    try {
      final bool? success = await _channel.invokeMethod('enterPipMode');
      if (success == true) {
        print('✅ Entered PiP mode successfully');
        return true;
      } else {
        print('❌ Failed to enter PiP mode');
        return false;
      }
    } catch (e) {
      print('❌ Error entering PiP mode: $e');
      return false;
    }
  }

  /// Check if currently in PiP mode
  Future<bool> isInPipMode() async {
    try {
      final bool? inPip = await _channel.invokeMethod('isInPipMode');
      return inPip ?? false;
    } catch (e) {
      print('❌ Error checking PiP mode: $e');
      return false;
    }
  }

  /// Enable PiP for a specific screen
  /// @param screenName - 'permission' or 'map'
  Future<bool> enablePipForScreen(String screenName) async {
    if (screenName != 'permission' && screenName != 'map') {
      print('⚠️ PiP only supported for permission and map screens');
      return false;
    }

    try {
      final bool? success =
          await _channel.invokeMethod('enablePipForScreen', screenName);
      if (success == true) {
        _currentScreen = screenName;
        print('✅ PiP enabled for $screenName screen');
        return true;
      } else {
        print('❌ Failed to enable PiP for $screenName screen');
        return false;
      }
    } catch (e) {
      print('❌ Error enabling PiP for screen: $e');
      return false;
    }
  }

  /// Disable PiP (call when leaving permission or map screens)
  Future<bool> disablePip() async {
    try {
      final bool? success = await _channel.invokeMethod('disablePip');
      if (success == true) {
        _currentScreen = '';
        print('✅ PiP disabled');
        return true;
      } else {
        print('❌ Failed to disable PiP');
        return false;
      }
    } catch (e) {
      print('❌ Error disabling PiP: $e');
      return false;
    }
  }

  /// Get the current PiP mode status (cached)
  bool get isInPip => _isInPipMode;

  /// Get the current screen name
  String get currentScreen => _currentScreen;

  /// Add a listener for PiP mode changes
  /// Callback receives (isInPip, screenName)
  void addPipModeListener(Function(bool, String) listener) {
    if (!_pipModeListeners.contains(listener)) {
      _pipModeListeners.add(listener);
      print(
          '🔔 Added PiP mode listener. Total listeners: ${_pipModeListeners.length}');
    }
  }

  /// Remove a PiP mode listener
  void removePipModeListener(Function(bool, String) listener) {
    _pipModeListeners.remove(listener);
    print(
        '🔕 Removed PiP mode listener. Total listeners: ${_pipModeListeners.length}');
  }

  /// Clear all PiP mode listeners
  void clearPipModeListeners() {
    _pipModeListeners.clear();
    print('🧹 Cleared all PiP mode listeners');
  }

  /// Dispose of the service
  void dispose() {
    clearPipModeListeners();
    print('🗑️ PiP Service disposed');
  }
}
