import 'dart:async';

import 'package:home_widget/home_widget.dart';

class ShortcutService {
  static final StreamController<int> _tabController =
      StreamController<int>.broadcast();
  static int? _initialTab;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _initialTab = _tabIndexFromUri(initialUri);

    HomeWidget.widgetClicked.listen((uri) {
      final tab = _tabIndexFromUri(uri);
      if (tab != null) {
        _tabController.add(tab);
      }
    });
  }

  static int? consumeInitialTab() {
    final value = _initialTab;
    _initialTab = null;
    return value;
  }

  static Stream<int> get tabStream => _tabController.stream;

  static int? _tabIndexFromUri(Uri? uri) {
    if (uri == null) return null;
    final target = (uri.host.isNotEmpty
            ? uri.host
            : (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : ''))
        .toLowerCase();
    switch (target) {
      case 'map':
        return 1;
      case 'activity':
        return 2;
      case 'home':
      case 'progress':
        return 0;
      default:
        return null;
    }
  }
}
