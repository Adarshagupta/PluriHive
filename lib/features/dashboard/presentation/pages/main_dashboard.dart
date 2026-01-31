import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../tracking/presentation/pages/map_screen.dart';
import '../../../profile/presentation/pages/profile_screen.dart';
import '../../../leaderboard/presentation/pages/leaderboard_screen.dart';
import '../../../history/presentation/pages/activity_history_screen.dart';
import '../../../tracking/presentation/bloc/location_bloc.dart';
import '../../../../core/services/persistent_step_counter_service.dart';
import '../../../../core/services/strict_permission_service.dart';
import '../../../../core/services/pip_service.dart';
import '../../../../core/services/shortcut_service.dart';
import 'home_tab.dart';

class DashboardScreen extends StatefulWidget {
  final int? initialTabIndex;
  const DashboardScreen({super.key, this.initialTabIndex});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _permissionsChecked = false;
  bool _isInPipMode = false;
  final PipService _pipService = PipService();
  final StrictPermissionService _permissionService = StrictPermissionService();
  bool _permissionPromptVisible = false;
  late final PageController _pageController;
  late final List<Widget> _screens;
  late final StreamSubscription<int> _shortcutSubscription;
  static const List<_NavItem> _navItems = [
    _NavItem(index: 0, icon: Icons.cottage_rounded),
    _NavItem(index: 1, icon: Icons.explore_rounded),
    _NavItem(index: 3, icon: Icons.emoji_events_rounded),
    _NavItem(index: 4, icon: Icons.sentiment_satisfied_rounded),
  ];
  static const String _backgroundStepTrackingKey =
      'background_step_tracking_enabled';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = _normalizeIndex(widget.initialTabIndex);
    _pageController = PageController(initialPage: _currentIndex);
    _screens = [
      HomeTab(onNavigateToTab: (index) {
        _setCurrentIndex(index);
      }),
      MapScreen(onNavigateHome: () {
        _setCurrentIndex(0);
      }),
      ActivityHistoryScreen(),
      LeaderboardScreen(),
      ProfileScreen(),
    ];
    _shortcutSubscription = ShortcutService.tabStream.listen(_handleShortcut);
    _initializePipListener();
    _requestLocationPermissions();
    _pipService.disablePip();
    _initializePersistentStepCounter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptPermissionsIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipService.removePipModeListener(_handlePipModeChange);
    _pageController.dispose();
    _shortcutSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _promptPermissionsIfNeeded();
    }
  }

  Future<void> _promptPermissionsIfNeeded() async {
    if (!mounted || _permissionPromptVisible) return;

    final locationAndActivityGranted =
        await _permissionService.areAllPermissionsGranted();
    final notificationStatus = await Permission.notification.status;
    final notificationsGranted = notificationStatus.isGranted;

    if (locationAndActivityGranted && notificationsGranted) {
      return;
    }

    _permissionPromptVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permissions needed'),
          content: const Text(
            'Location and activity permissions power territory tracking. '
            'Precise location is required for the map. '
            'Notifications are optional but recommended for reminders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _permissionService.requestAllPermissions();
                await Permission.notification.request();
                _requestLocationPermissions();
              },
              child: const Text('Grant permissions'),
            ),
          ],
        );
      },
    );
    _permissionPromptVisible = false;
  }

  Future<void> _initializePipListener() async {
    await _pipService.initialize();
    _pipService.addPipModeListener(_handlePipModeChange);
    final inPip = await _pipService.isInPipMode();
    if (mounted) {
      setState(() {
        _isInPipMode = inPip;
      });
    }
    _syncPipForIndex(_currentIndex);
  }

  int _normalizeIndex(int? index) {
    if (index == null) return 0;
    if (index < 0 || index > 4) return 0;
    return index;
  }

  void _handleShortcut(int index) {
    _setCurrentIndex(index);
  }

  void _handlePipModeChange(bool isInPip, String screen) {
    if (mounted) {
      setState(() {
        _isInPipMode = isInPip;
      });
    }
  }

  void _syncPipForIndex(int index) {
    final trackingActive = context.read<LocationBloc>().state is LocationTracking;
    if (index != 1) {
      if (trackingActive) {
        _pipService.enablePipForScreen('map');
      } else {
        _pipService.disablePip();
      }
    } else {
      _pipService.enablePipForScreen('map');
    }
  }

  void _setCurrentIndex(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
      if (index != 1) {
        _isInPipMode = false;
      }
    });

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    _syncPipForIndex(index);
  }

  Future<void> _initializePersistentStepCounter() async {
    await PersistentStepCounterService.initialize();
    final prefs = await SharedPreferences.getInstance();
    final backgroundEnabled =
        prefs.getBool(_backgroundStepTrackingKey) ?? false;
    if (backgroundEnabled) {
      await PersistentStepCounterService.startBackgroundService(
        requestPermissions: false,
      );
    }
    print('✅ Persistent step counter initialized in dashboard');
  }

  Future<void> _requestLocationPermissions() async {
    if (_permissionsChecked) {
      final current = await Geolocator.checkPermission();
      if (current != LocationPermission.denied &&
          current != LocationPermission.deniedForever) {
        return;
      }
    }
    _permissionsChecked = true;

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showLocationServiceDialog();
      }
      return;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showPermissionDeniedForeverDialog();
      }
      return;
    }

    // Permission granted - initialize location tracking
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      if (mounted) {
        print(
            '📍 DASHBOARD: Location permission granted, loading initial location...');
        context.read<LocationBloc>().add(GetInitialLocation());
      }
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Service Disabled'),
        content: const Text(
          'Please enable location services to use tracking features. '
          'Location is used to draw routes and capture territories.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Plurihive needs location access to track your runs and capture territories. '
          'You can grant it now or later in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestLocationPermissions();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Permanently Denied'),
        content: const Text(
          'You have permanently denied location permission. '
          'Enable it in Settings to use tracking features.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        if (_currentIndex == 1) return;
        final trackingActive = state is LocationTracking;
        if (trackingActive) {
          _pipService.enablePipForScreen('map');
        } else {
          _pipService.disablePip();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: _currentIndex == 1
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (index) {
                if (_currentIndex == index) return;
                setState(() {
                  _currentIndex = index;
                  if (index != 1) {
                    _isInPipMode = false;
                  }
                });
                _syncPipForIndex(index);
              },
              children: _screens,
            ),
            _buildTrackingBanner(),
          ],
        ),
        bottomNavigationBar: _isInPipMode || _currentIndex == 1
            ? null
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final item in _navItems)
                          _buildNavItem(item.index, item.icon),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTrackingBanner() {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        final isTracking = state is LocationTracking;
        if (!isTracking || _currentIndex == 1 || _isInPipMode) {
          return const SizedBox.shrink();
        }

        final topInset = MediaQuery.of(context).padding.top;
        return Positioned(
          top: topInset + 12,
          left: 20,
          right: 20,
          child: GestureDetector(
            onTap: () => _setCurrentIndex(1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF7FE87A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tracking in background',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = _currentIndex == index;
    final colors = {
      0: Color(0xFF2D2D2D), // home
      1: Color(0xFF3B82F6), // map
      3: Color(0xFFF59E0B), // leaderboard
      4: Color(0xFF7B68EE), // profile
    };

    return GestureDetector(
      onTap: () {
        _setCurrentIndex(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected
              ? colors[index]!.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colors[index]!.withOpacity(0.5)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? colors[index]! : Colors.grey.shade400,
          size: 26,
        ),
      ),
    );
  }
}

class _NavItem {
  final int index;
  final IconData icon;

  const _NavItem({
    required this.index,
    required this.icon,
  });
}
