import 'package:flutter/material.dart';
import '../services/pip_service.dart';

/// Wrapper widget that handles PiP mode UI for map screen
/// Automatically shows compact view when in PiP mode
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

class _PipAwareWidgetState extends State<PipAwareWidget>
    with WidgetsBindingObserver {
  final PipService _pipService = PipService();
  bool _isInPipMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePipForMap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipService.removePipModeListener(_handlePipModeChange);
    _pipService.disablePip();
    super.dispose();
  }

  Future<void> _initializePipForMap() async {
    await _pipService.initialize();
    await _pipService.enablePipForScreen('map');
    _pipService.addPipModeListener(_handlePipModeChange);

    final isInPip = await _pipService.isInPipMode();
    if (mounted) {
      setState(() {
        _isInPipMode = isInPip;
      });
      print('🗺️ Map PiP initialized: $_isInPipMode');
    }
  }

  void _handlePipModeChange(bool isInPip, String screen) {
    if (screen == 'map' && mounted) {
      setState(() {
        _isInPipMode = isInPip;
      });
      print('🗺️ Map PiP mode changed: $isInPip');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // PiP state is handled by the service callbacks
  }

  @override
  Widget build(BuildContext context) {
    return _isInPipMode ? widget.pipChild : widget.child;
  }
}
