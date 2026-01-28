import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import 'welcome_screen.dart';
import 'onboarding_screen.dart';
import '../../../dashboard/presentation/pages/main_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _retryCount = 0;
  static const int _maxRetries = 10;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _controller.forward();
    
    // Check auth state after animation completes
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        print('🎯 SplashScreen: Checking state after delay: ${authState.runtimeType}');
        _handleAuthState(authState);
      }
    });
  }
  
  void _handleAuthState(AuthState state) {
    if (!mounted) return;

    print('???? SplashScreen: Handling state: ${state.runtimeType}');

    if (state is Authenticated) {
      print('???? SplashScreen: User authenticated, hasCompletedOnboarding: ${state.user.hasCompletedOnboarding}');
      if (state.user.hasCompletedOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    } else if (state is Unauthenticated) {
      print('???? SplashScreen: User not authenticated');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else if (state is AuthLoading || state is AuthInitial) {
      print('???? SplashScreen: Still loading, will retry...');
      if (_retryCount >= _maxRetries) {
        print('???? SplashScreen: Max retries hit, sending user to WelcomeScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
        return;
      }
      _retryCount += 1;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final newState = context.read<AuthBloc>().state;
          _handleAuthState(newState);
        }
      });
    } else if (state is AuthError) {
      print('???? SplashScreen: Auth error - redirecting to WelcomeScreen');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        print('🎯 SplashScreen BlocListener: State changed to ${state.runtimeType}');
        _handleAuthState(state);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Full screen illustration
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Image.asset(
                  'assets/illustrations/splashscreen.webp',
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width * 1.1,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // App name at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  'Plurihive',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
