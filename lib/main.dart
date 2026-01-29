import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_config.dart';
import 'core/services/update_service.dart';
import 'core/services/code_push_service.dart';
import 'core/navigation/app_route_observer.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/mapbox_config.dart';
import 'features/tracking/data/datasources/activity_local_data_source.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'features/tracking/presentation/bloc/location_bloc.dart';
import 'features/territory/presentation/bloc/territory_bloc.dart';
import 'features/game/presentation/bloc/game_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize API configuration
  await ApiConfig.initialize();

  // Initialize Mapbox (optional)
  await MapboxConfig.initialize();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize dependency injection
  await initializeDependencies();

  // Warm home widget data from cache on launch
  await HomeWidgetService.syncFromCache();

  // Seed widget with last activity if available
  try {
    final activitySource = ActivityLocalDataSourceImpl();
    final activities = await activitySource.getAllActivities();
    if (activities.isNotEmpty) {
      final latest = activities.first;
      final distanceKm = latest.distanceMeters / 1000;
      final steps = latest.steps;
      final progressPercent =
          ((distanceKm / 5.0) * 100).round().clamp(0, 100);
      await HomeWidgetService.updateStats(
        distanceKm: distanceKm,
        steps: steps,
        progressPercent: progressPercent.toInt(),
      );
      if (latest.routeMapSnapshot != null) {
        await HomeWidgetService.updateMapSnapshot(latest.routeMapSnapshot);
      }
    }
  } catch (_) {}
  
  runApp(const TerritoryFitnessApp());
}

class TerritoryFitnessApp extends StatefulWidget {
  const TerritoryFitnessApp({super.key});

  @override
  State<TerritoryFitnessApp> createState() => _TerritoryFitnessAppState();
}

class _TerritoryFitnessAppState extends State<TerritoryFitnessApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check for updates on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService().checkForUpdateOnStart(context);
      CodePushService().checkForUpdateOnStart(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      UpdateService().checkForUpdateIfNeeded(context);
      CodePushService().checkForUpdateIfNeeded(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AuthBloc>()..add(CheckAuthStatus())),
        BlocProvider(create: (_) => getIt<LocationBloc>()),
        BlocProvider(create: (_) => getIt<TerritoryBloc>()),
        BlocProvider(create: (_) => getIt<GameBloc>()..add(LoadGameData())),
      ],
      child: MaterialApp(
        title: 'Plurihive',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        navigatorObservers: [appRouteObserver],
        home: const SplashScreen(),
      ),
    );
  }
}
