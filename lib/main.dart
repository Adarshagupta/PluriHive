import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'features/tracking/presentation/bloc/location_bloc.dart';
import 'features/territory/presentation/bloc/territory_bloc.dart';
import 'features/game/presentation/bloc/game_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize dependency injection
  await initializeDependencies();
  
  runApp(const TerritoryFitnessApp());
}

class TerritoryFitnessApp extends StatelessWidget {
  const TerritoryFitnessApp({super.key});

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
        home: const SplashScreen(),
      ),
    );
  }
}
