import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PictureInPictureManager {
  static const platform = MethodChannel('territory_fitness/pip');
  static Function(bool)? onPipModeChanged;
  
  static void initialize() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final isInPip = call.arguments as bool;
        onPipModeChanged?.call(isInPip);
      }
    });
  }
  
  /// Enter Picture-in-Picture mode (Android)
  static Future<bool> enterPipMode() async {
    try {
      final result = await platform.invokeMethod('enterPipMode');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to enter PiP mode: ${e.message}');
      return false;
    }
  }
  
  /// Check if device supports PiP
  static Future<bool> isPipSupported() async {
    try {
      final result = await platform.invokeMethod('isPipSupported');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check PiP support: ${e.message}');
      return false;
    }
  }
  
  /// Check if currently in PiP mode
  static Future<bool> isInPipMode() async {
    try {
      final result = await platform.invokeMethod('isInPipMode');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check PiP status: ${e.message}');
      return false;
    }
  }
}

/// Wrapper widget that handles PiP mode UI
class PipAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget pipChild;
  
  const PipAwareWidget({
    super.key,
    required this.child,
    required this.pipChild,
  });
  
  @override
  State<PipAwareWidget> createState() => _PipAwareWidgetState();
}

class _PipAwareWidgetState extends State<PipAwareWidget> with WidgetsBindingObserver {
  bool _isInPipMode = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PictureInPictureManager.initialize();
    PictureInPictureManager.onPipModeChanged = _onPipModeChanged;
    _checkPipStatus();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PictureInPictureManager.onPipModeChanged = null;
    super.dispose();
  }
  
  void _onPipModeChanged(bool isInPip) {
    if (mounted) {
      setState(() {
        _isInPipMode = isInPip;
      });
      print('PiP mode changed via callback: $_isInPipMode');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _checkPipStatus();
  }
  
  Future<void> _checkPipStatus() async {
    final inPip = await PictureInPictureManager.isInPipMode();
    if (mounted && inPip != _isInPipMode) {
      setState(() {
        _isInPipMode = inPip;
      });
      print('PiP mode checked: $_isInPipMode');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return _isInPipMode ? widget.pipChild : widget.child;
  }
}
