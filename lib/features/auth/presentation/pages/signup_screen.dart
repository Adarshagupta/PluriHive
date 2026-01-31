import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../settings/presentation/pages/legal_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/google_signin_service.dart';
import '../../../../core/widgets/auth_backdrop.dart';
import '../bloc/auth_bloc.dart';
import '../../../game/presentation/bloc/game_bloc.dart';
import 'onboarding_screen.dart';
import 'signin_screen.dart';
import '../../domain/entities/user.dart';
import '../../../dashboard/presentation/pages/main_dashboard.dart';
import '../../../../core/services/shortcut_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      context.read<AuthBloc>().add(
        SignUpUser(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final googleSignInService = GoogleSignInService();
      final account = await googleSignInService.signIn();

      if (account != null) {
        final idToken = await googleSignInService.getIdToken();

        if (idToken != null) {
          if (mounted) {
            context.read<AuthBloc>().add(
                  SignInWithGoogle(idToken: idToken),
                );
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to get Google authentication token'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e')),
        );
      }
    }
  }

  void _routeAfterAuth(User user) {
    final target = user.hasCompletedOnboarding
        ? DashboardScreen(initialTabIndex: ShortcutService.consumeInitialTab())
        : const OnboardingScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          // Reload game data from backend after successful signup
          context.read<GameBloc>().add(LoadGameData());

          _routeAfterAuth(state.user);
        } else if (state is AuthError) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is Unauthenticated) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      },
      child: Scaffold(
        body: AuthBackdrop(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create your squad',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set up your profile and start capturing territories today.',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 8),
                    _authCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: _authDecoration(
                              label: 'Full name',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _authDecoration(
                              label: 'Email',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _authDecoration(
                              label: 'Password',
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF111827),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Continue',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.2,
                          ),
                          backgroundColor: Colors.white.withOpacity(0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 22,
                          height: 22,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.login, size: 22);
                          },
                        ),
                        label: Text(
                          'Continue with Google',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                              ..onTap = () => _openLegalDoc(LegalDocType.terms),
                            ),
                          const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                              ..onTap = () => _openLegalDoc(LegalDocType.privacy),
                            ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.dmSans(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignInScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign In',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _authDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black, width: 1.4),
      ),
    );
  }

  Widget _authCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  void _openLegalDoc(LegalDocType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDetailScreen(type: type),
      ),
    );
  }
}
