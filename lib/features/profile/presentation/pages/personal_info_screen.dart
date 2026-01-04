import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/di/injection_container.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  String? _gender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) {
      final user = state.user;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _weightController.text = user.weightKg?.toString() ?? '';
      _heightController.text = user.heightCm?.toString() ?? '';
      _ageController.text = user.age?.toString() ?? '';
      _gender = user.gender;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = getIt<AuthApiService>();
      
      final updates = <String, dynamic>{};
      updates['name'] = _nameController.text.trim();
      
      if (_weightController.text.isNotEmpty) {
        updates['weightKg'] = double.tryParse(_weightController.text);
      }
      if (_heightController.text.isNotEmpty) {
        updates['heightCm'] = double.tryParse(_heightController.text);
      }
      if (_ageController.text.isNotEmpty) {
        updates['age'] = int.tryParse(_ageController.text);
      }
      if (_gender != null) {
        updates['gender'] = _gender;
      }
      
      await authService.updateProfile(updates);

      // Refresh auth state
      if (mounted) {
        context.read<AuthBloc>().add(CheckAuthStatus());
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF7FE87A),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Information',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Name
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Email (read-only)
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              enabled: false,
            ),
            const SizedBox(height: 20),

            // Weight
            _buildTextField(
              controller: _weightController,
              label: 'Weight (kg)',
              icon: Icons.monitor_weight_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Height
            _buildTextField(
              controller: _heightController,
              label: 'Height (cm)',
              icon: Icons.height,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Age
            _buildTextField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.cake_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Gender
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.wc, color: Color(0xFF6B7280)),
                title: Text(
                  _gender ?? 'Select Gender',
                  style: TextStyle(
                    color: _gender == null ? Color(0xFF9CA3AF) : Color(0xFF111827),
                    fontSize: 16,
                  ),
                ),
                trailing: const Icon(Icons.arrow_drop_down, color: Color(0xFF9CA3AF)),
                onTap: () => _showGenderPicker(),
              ),
            ),
            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF7FE87A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      style: TextStyle(
        color: enabled ? Color(0xFF111827) : Color(0xFF9CA3AF),
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: Color(0xFF6B7280)),
        filled: true,
        fillColor: Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF7FE87A), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Gender',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 20),
            _buildGenderOption('Male'),
            _buildGenderOption('Female'),
            _buildGenderOption('Other'),
            _buildGenderOption('Prefer not to say'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderOption(String gender) {
    final isSelected = _gender == gender;
    return ListTile(
      title: Text(
        gender,
        style: TextStyle(
          color: isSelected ? Color(0xFF7FE87A) : Color(0xFF111827),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF7FE87A))
          : null,
      onTap: () {
        setState(() => _gender = gender);
        Navigator.pop(context);
      },
    );
  }
}
