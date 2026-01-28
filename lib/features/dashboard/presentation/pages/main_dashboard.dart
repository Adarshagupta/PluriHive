import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../tracking/presentation/pages/map_screen.dart';
import '../../../profile/presentation/pages/profile_screen.dart';
import '../../../leaderboard/presentation/pages/leaderboard_screen.dart';
import '../../../history/presentation/pages/activity_history_screen.dart';
import '../../../tracking/presentation/bloc/location_bloc.dart';
import '../../../../core/services/persistent_step_counter_service.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/services/pip_service.dart';
import 'home_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _permissionsChecked = false;
  bool _isInPipMode = false;
  final PipService _pipService = PipService();
  late final PageController _pageController;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _initializePipListener();
    _requestLocationPermissions();
    _pipService.disablePip();
    // Disabled: Auto-start of step counter (was showing unwanted notification)
    // _initializePersistentStepCounter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipService.removePipModeListener(_handlePipModeChange);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // PiP is handled by individual screens (permission and map)
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
  }

  void _handlePipModeChange(bool isInPip, String screen) {
    if (mounted) {
      setState(() {
        _isInPipMode = isInPip;
      });
    }
  }

  void _setCurrentIndex(int index) {
    if (_currentIndex == index) return;
    final trackingActive = context.read<LocationBloc>().state is LocationTracking;

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

  Future<void> _initializePersistentStepCounter() async {
    await PersistentStepCounterService.initialize();
    await PersistentStepCounterService.startBackgroundService();
    print('✅ Persistent step counter initialized in dashboard');
  }

  Future<void> _requestLocationPermissions() async {
    if (_permissionsChecked) return;
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
          'Please enable location services to use Plurihive. '
          'This app requires your location to track your runs and capture territories.',
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
          'Please grant location permission to use the app.',
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
          'Please go to app settings and grant location permission to use Plurihive.',
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
    return PermissionGate(
      child: BlocListener<LocationBloc, LocationState>(
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
                  final trackingActive =
                      context.read<LocationBloc>().state is LocationTracking;
                  setState(() {
                    _currentIndex = index;
                    if (index != 1) {
                      _isInPipMode = false;
                    }
                  });
                  if (index != 1) {
                    if (trackingActive) {
                      _pipService.enablePipForScreen('map');
                    } else {
                      _pipService.disablePip();
                    }
                  } else {
                    _pipService.enablePipForScreen('map');
                  }
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
                          _buildNavItem(0, Icons.cottage_rounded),
                          _buildNavItem(1, Icons.explore_rounded),
                          _buildNavItem(2, Icons.menu_book_rounded),
                          _buildNavItem(3, Icons.emoji_events_rounded),
                          _buildNavItem(4, Icons.sentiment_satisfied_rounded),
                        ],
                      ),
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
    final colors = [
      Color(0xFF2D2D2D), // dark for home
      Color(0xFFB0B0B0), // gray for map
      Color(0xFF4CAF50), // green for history
      Color(0xFFB0B0B0), // gray for leaderboard
      Color(0xFF7B68EE), // purple for profile
    ];

    return GestureDetector(
      onTap: () {
        _setCurrentIndex(index);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? colors[index] : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : colors[index],
          size: 26,
        ),
      ),
    );
  }
}
