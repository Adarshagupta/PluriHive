import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_backdrop.dart';
import '../../../../core/services/settings_api_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../dashboard/presentation/pages/main_dashboard.dart';
import '../../../../core/services/shortcut_service.dart';
import '../bloc/auth_bloc.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const List<String> _countryOptions = [
    'United States',
    'Canada',
    'United Kingdom',
    'Australia',
    'New Zealand',
    'India',
    'Germany',
    'France',
    'Italy',
    'Spain',
    'Netherlands',
    'Sweden',
    'Norway',
    'Denmark',
    'Finland',
    'Ireland',
    'Portugal',
    'Switzerland',
    'Austria',
    'Belgium',
    'Poland',
    'Czech Republic',
    'Romania',
    'Greece',
    'Turkey',
    'South Africa',
    'Nigeria',
    'Kenya',
    'Egypt',
    'Morocco',
    'Saudi Arabia',
    'United Arab Emirates',
    'Israel',
    'Japan',
    'South Korea',
    'China',
    'Singapore',
    'Thailand',
    'Vietnam',
    'Indonesia',
    'Malaysia',
    'Philippines',
    'Mexico',
    'Brazil',
    'Argentina',
    'Chile',
    'Colombia',
    'Peru',
  ];
  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
    'Unspecified',
  ];
  final _statsFormKey = GlobalKey<FormState>();
  final _prefsFormKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedCountry = 'United States';
  String _unitSystem = 'metric';
  bool _isLoading = false;
  bool _onboardingRequested = false;
  int _currentStep = 0;
  late final SettingsApiService _settingsApiService;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _settingsApiService = getIt<SettingsApiService>();
  }

  void _handleNext() {
    if (_statsFormKey.currentState?.validate() != true) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    setState(() => _currentStep = 1);
  }

  Future<void> _handleComplete() async {
    if (_prefsFormKey.currentState?.validate() != true) return;
    setState(() => _isLoading = true);
    _onboardingRequested = false;

    try {
      await _settingsApiService.updateSettings({'units': _unitSystem});
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
      );
      return;
    }

    context.read<AuthBloc>().add(
          UpdateUserProfile(
            weightKg: double.parse(_weightController.text),
            heightCm: double.parse(_heightController.text),
            age: int.parse(_ageController.text),
            gender: _normalizeGenderForApi(_selectedGender),
            country: _selectedCountry,
          ),
        );
  }

  String _normalizeGenderForApi(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'male':
        return 'male';
      case 'female':
        return 'female';
      case 'other':
        return 'other';
      case 'prefer not to say':
      case 'prefer_not_say':
        return 'prefer_not_say';
      case 'unspecified':
        return 'unspecified';
      default:
        return 'unspecified';
    }
  }

  String _formatBackendError(String message) {
    var cleaned = message;
    cleaned = cleaned.replaceAll('Exception: Update profile error: Exception:', '');
    cleaned = cleaned.replaceAll('Exception: Update profile error:', '');
    cleaned = cleaned.replaceAll('Exception:', '');
    cleaned = cleaned.replaceAll('[', '').replaceAll(']', '');
    cleaned = cleaned.trim();
    return cleaned.isEmpty ? 'Failed to update profile.' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!mounted) return;
        if (state is Authenticated && _isLoading) {
          if (!_onboardingRequested) {
            _onboardingRequested = true;
            context.read<AuthBloc>().add(CompleteOnboarding());
            return;
          }
          if (state.user.hasCompletedOnboarding) {
            setState(() => _isLoading = false);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  initialTabIndex: ShortcutService.consumeInitialTab(),
                ),
              ),
              (route) => false,
            );
          }
        } else if (state is AuthError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_formatBackendError(state.message))),
          );
        }
      },
      child: Scaffold(
        body: AuthBackdrop(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Profile setup',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          'Step ${_currentStep + 1} of 2',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildProgressBar(),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 420,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatsStep(),
                        _buildPrefsStep(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (_currentStep == 1)
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOut,
                                  );
                                  setState(() => _currentStep = 0);
                                },
                          child: Text(
                            'Back',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 64),
                      const Spacer(),
                      SizedBox(
                        width: 180,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_currentStep == 0 ? _handleNext : _handleComplete),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading && _currentStep == 1
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _currentStep == 0 ? 'Next' : 'Complete',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
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
    );
  }

  Widget _buildStatsStep() {
    return Form(
      key: _statsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finish your stats',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These basics keep calorie estimates accurate. You can edit them later.',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: _authDecoration(
              label: 'Weight (kg)',
              icon: Icons.monitor_weight_outlined,
              hint: 'Enter your weight',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your weight';
              }
              if (double.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            decoration: _authDecoration(
              label: 'Height (cm)',
              icon: Icons.height,
              hint: 'Enter your height',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your height';
              }
              final parsed = double.tryParse(value);
              if (parsed == null) {
                return 'Please enter a valid number';
              }
              if (parsed < 80) {
                return 'Height must be at least 80 cm';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: _authDecoration(
              label: 'Age',
              icon: Icons.cake_outlined,
              hint: 'Enter your age',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your age';
              }
              if (int.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: _authDecoration(
              label: 'Gender',
              icon: Icons.person_outline,
            ),
            items: _genderOptions.map((gender) {
              return DropdownMenuItem(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedGender = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrefsStep() {
    return Form(
      key: _prefsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location & units',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a country and choose your preferred units.',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            decoration: _authDecoration(
              label: 'Country',
              icon: Icons.public,
            ),
            items: _countryOptions.map((country) {
              return DropdownMenuItem(
                value: country,
                child: Text(country),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCountry = value);
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a country';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Units',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _unitChoice(
                label: 'Metric',
                icon: Icons.straighten,
                isSelected: _unitSystem == 'metric',
                onTap: () => setState(() => _unitSystem = 'metric'),
              ),
              const SizedBox(width: 12),
              _unitChoice(
                label: 'Imperial',
                icon: Icons.square_foot,
                isSelected: _unitSystem == 'imperial',
                onTap: () => setState(() => _unitSystem = 'imperial'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final progress = (_currentStep + 1) / 2;
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _unitChoice({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF111827)
                : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF111827)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _authDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
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
}
