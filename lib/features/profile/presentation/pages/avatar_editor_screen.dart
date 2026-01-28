import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/avatar_preset_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  bool _isSaving = false;
  String? _pendingPresetId;
  final Random _random = Random();
  AvatarPreset? _initialPreset;
  List<AvatarPreset> _suggestedPresets = [];

  AvatarGender _gender = AvatarGender.male;
  AvatarSkinTone _skinTone = AvatarSkinTone.medium;
  AvatarHairColor _hairColor = AvatarHairColor.black;
  AvatarHairStyle _hairStyle = AvatarHairStyle.short;
  AvatarFaceShape _faceShape = AvatarFaceShape.round;
  AvatarEyeStyle _eyeStyle = AvatarEyeStyle.normal;
  AvatarMouthStyle _mouthStyle = AvatarMouthStyle.smile;
  AvatarAccessory _accessory = AvatarAccessory.none;

  @override
  void initState() {
    super.initState();
    _loadExistingSelection();
    _initialPreset ??= _currentPreset;
    _suggestedPresets = _buildSuggestedPresetList();
  }

  void _loadExistingSelection() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    final preset = AvatarPresetService.fromStored(
      avatarModelUrl: authState.user.avatarModelUrl,
      avatarImageUrl: authState.user.avatarImageUrl,
    );
    if (preset == null) return;
    _initialPreset = preset;
    _gender = preset.gender;
    _skinTone = preset.skinTone;
    _hairColor = preset.hairColor;
    _hairStyle = preset.hairStyle;
    _faceShape = preset.faceShape;
    _eyeStyle = preset.eyeStyle;
    _mouthStyle = preset.mouthStyle;
    _accessory = preset.accessory;
  }

  AvatarPreset get _currentPreset => AvatarPresetService.findPreset(
        gender: _gender,
        skinTone: _skinTone,
        hairColor: _hairColor,
        hairStyle: _hairStyle,
        faceShape: _faceShape,
        eyeStyle: _eyeStyle,
        mouthStyle: _mouthStyle,
        accessory: _accessory,
      );

  bool get _hasChanges =>
      _initialPreset != null && _currentPreset.id != _initialPreset!.id;

  void _setGender(AvatarGender gender) {
    setState(() {
      _gender = gender;
      _suggestedPresets = _buildSuggestedPresetList();
    });
  }

  void _applyPreset(AvatarPreset preset) {
    setState(() {
      _gender = preset.gender;
      _skinTone = preset.skinTone;
      _hairColor = preset.hairColor;
      _hairStyle = preset.hairStyle;
      _faceShape = preset.faceShape;
      _eyeStyle = preset.eyeStyle;
      _mouthStyle = preset.mouthStyle;
      _accessory = preset.accessory;
      _suggestedPresets = _buildSuggestedPresetList();
    });
  }

  T _randomFrom<T>(List<T> options) =>
      options[_random.nextInt(options.length)];

  void _randomizeAll() {
    setState(() {
      _gender = _randomFrom(AvatarGender.values);
      _skinTone = _randomFrom(AvatarSkinTone.values);
      _hairColor = _randomFrom(AvatarHairColor.values);
      _hairStyle = _randomFrom(AvatarHairStyle.values);
      _faceShape = _randomFrom(AvatarFaceShape.values);
      _eyeStyle = _randomFrom(AvatarEyeStyle.values);
      _mouthStyle = _randomFrom(AvatarMouthStyle.values);
      _accessory = _randomFrom(AvatarAccessory.values);
      _suggestedPresets = _buildSuggestedPresetList();
    });
  }

  void _randomizeColors() {
    setState(() {
      _skinTone = _randomFrom(AvatarSkinTone.values);
      _hairColor = _randomFrom(AvatarHairColor.values);
    });
  }

  void _randomizeStyle() {
    setState(() {
      _hairStyle = _randomFrom(AvatarHairStyle.values);
      _faceShape = _randomFrom(AvatarFaceShape.values);
      _accessory = _randomFrom(AvatarAccessory.values);
    });
  }

  void _randomizeExpression() {
    setState(() {
      _eyeStyle = _randomFrom(AvatarEyeStyle.values);
      _mouthStyle = _randomFrom(AvatarMouthStyle.values);
    });
  }

  void _resetToSaved() {
    if (_initialPreset == null || !_hasChanges) return;
    _applyPreset(_initialPreset!);
  }

  void _refreshSuggestedPresets() {
    setState(() => _suggestedPresets = _buildSuggestedPresetList());
  }

  List<AvatarPreset> _buildSuggestedPresetList() {
    final filtered = AvatarPresetService.presets
        .where((preset) => preset.gender == _gender)
        .toList();
    final pool = filtered.isEmpty
        ? List<AvatarPreset>.from(AvatarPresetService.presets)
        : filtered;
    pool.shuffle(_random);
    return pool.take(8).toList();
  }

  void _saveAvatar() {
    if (_isSaving) return;
    final preset = _currentPreset;
    setState(() {
      _isSaving = true;
      _pendingPresetId = preset.id;
    });
    context.read<AuthBloc>().add(
          UpdateUserAvatar(
            avatarModelUrl: AvatarPresetService.toModelValue(preset.id),
            avatarImageUrl: preset.imageAsset,
          ),
        );
  }

  void _handleAvatarSaved() {
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop();
  }

  void _handleAvatarSaveFailed(String message) {
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!_isSaving) return;
        if (state is Authenticated) {
          final savedPreset = AvatarPresetService.extractPresetId(
                state.user.avatarModelUrl,
              ) ??
              AvatarPresetService.extractPresetId(
                state.user.avatarImageUrl,
              );
          if (savedPreset == _pendingPresetId) {
            _handleAvatarSaved();
            return;
          }
        } else if (state is AuthError) {
          _handleAvatarSaveFailed(state.message);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4EE),
        appBar: AppBar(
          title: const Text('Avatar Studio'),
          backgroundColor: const Color(0xFFF7F4EE),
          foregroundColor: const Color(0xFF111827),
          elevation: 0,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAvatar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save Avatar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewCard(),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      title: 'Featured presets',
                      action: TextButton.icon(
                        onPressed: _refreshSuggestedPresets,
                        icon: const Icon(Icons.shuffle, size: 18),
                        label: const Text('Shuffle'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSuggestedPresets(),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      title: 'Basics',
                      icon: Icons.person_outline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubsectionTitle('Gender'),
                          const SizedBox(height: 8),
                          _buildGenderOptions(),
                          const SizedBox(height: 12),
                          _buildSectionDivider(),
                          const SizedBox(height: 12),
                          _buildSubsectionTitle('Skin tone'),
                          const SizedBox(height: 8),
                          _buildSkinOptions(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Hair',
                      icon: Icons.content_cut,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubsectionTitle('Hair color'),
                          const SizedBox(height: 8),
                          _buildHairOptions(),
                          const SizedBox(height: 12),
                          _buildSectionDivider(),
                          const SizedBox(height: 12),
                          _buildSubsectionTitle('Hair style'),
                          const SizedBox(height: 8),
                          _buildHairStyleOptions(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Face',
                      icon: Icons.face_retouching_natural,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubsectionTitle('Face shape'),
                          const SizedBox(height: 8),
                          _buildFaceShapeOptions(),
                          const SizedBox(height: 12),
                          _buildSectionDivider(),
                          const SizedBox(height: 12),
                          _buildSubsectionTitle('Eyes'),
                          const SizedBox(height: 8),
                          _buildEyeOptions(),
                          const SizedBox(height: 12),
                          _buildSectionDivider(),
                          const SizedBox(height: 12),
                          _buildSubsectionTitle('Mouth'),
                          const SizedBox(height: 8),
                          _buildMouthOptions(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Accessories',
                      icon: Icons.auto_awesome,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubsectionTitle('Accessories'),
                          const SizedBox(height: 8),
                          _buildAccessoryOptions(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Saving avatar...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final preset = _currentPreset;
    final savedPreset = _initialPreset;
    final showSaved = savedPreset != null && savedPreset.id != preset.id;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AvatarPreview(
                preset: preset,
                label: showSaved ? 'Editing' : 'Preview',
                size: 156,
                animate: true,
                highlight: true,
              ),
              if (showSaved) ...[
                const SizedBox(width: 16),
                _AvatarPreview(
                  preset: savedPreset!,
                  label: 'Saved',
                  size: 72,
                  animate: false,
                  highlight: false,
                  compact: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildAttributeChips(preset),
        ],
      ),
    );
  }

  Widget _buildAttributeChips(AvatarPreset preset) {
    final tags = [
      AvatarPresetService.genderLabels[preset.gender],
      AvatarPresetService.skinToneLabels[preset.skinTone],
      AvatarPresetService.hairLabels[preset.hairColor],
      AvatarPresetService.hairStyleLabels[preset.hairStyle],
      AvatarPresetService.faceShapeLabels[preset.faceShape],
      AvatarPresetService.eyeStyleLabels[preset.eyeStyle],
      AvatarPresetService.mouthStyleLabels[preset.mouthStyle],
      AvatarPresetService.accessoryLabels[preset.accessory],
    ].whereType<String>().where((label) => label.isNotEmpty).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: tags.map((label) => _AttributeChip(label: label)).toList(),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    Widget? action,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ActionPill(
            icon: Icons.auto_awesome,
            label: 'Randomize',
            onTap: _randomizeAll,
          ),
          const SizedBox(width: 10),
          _ActionPill(
            icon: Icons.palette_outlined,
            label: 'Colors',
            onTap: _randomizeColors,
          ),
          const SizedBox(width: 10),
          _ActionPill(
            icon: Icons.brush_outlined,
            label: 'Style',
            onTap: _randomizeStyle,
          ),
          const SizedBox(width: 10),
          _ActionPill(
            icon: Icons.emoji_emotions_outlined,
            label: 'Mood',
            onTap: _randomizeExpression,
          ),
          const SizedBox(width: 10),
          _ActionPill(
            icon: Icons.restore,
            label: 'Reset',
            onTap: _hasChanges ? _resetToSaved : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedPresets() {
    if (_suggestedPresets.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Text(
          'No presets available',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedPresets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final preset = _suggestedPresets[index];
          return _PresetCard(
            preset: preset,
            isSelected: preset.id == _currentPreset.id,
            onTap: () => _applyPreset(preset),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF111827)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildGenderOptions() {
    return Wrap(
      spacing: 12,
      children: AvatarGender.values.map((gender) {
        final isSelected = _gender == gender;
        return ChoiceChip(
          label: Text(AvatarPresetService.genderLabels[gender] ?? ''),
          selected: isSelected,
          onSelected: (_) => _setGender(gender),
          selectedColor: const Color(0xFF111827),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkinOptions() {
    return Wrap(
      spacing: 14,
      children: AvatarSkinTone.values.map((tone) {
        return _ColorOption(
          color: AvatarPresetService.skinToneColors[tone] ?? Colors.brown,
          label: AvatarPresetService.skinToneLabels[tone] ?? '',
          isSelected: _skinTone == tone,
          onTap: () => setState(() => _skinTone = tone),
        );
      }).toList(),
    );
  }

  Widget _buildHairOptions() {
    return Wrap(
      spacing: 14,
      children: AvatarHairColor.values.map((hair) {
        return _ColorOption(
          color: AvatarPresetService.hairColors[hair] ?? Colors.black,
          label: AvatarPresetService.hairLabels[hair] ?? '',
          isSelected: _hairColor == hair,
          onTap: () => setState(() => _hairColor = hair),
        );
      }).toList(),
    );
  }

  Widget _buildHairStyleOptions() {
    return Wrap(
      spacing: 12,
      children: AvatarHairStyle.values.map((style) {
        final isSelected = _hairStyle == style;
        return ChoiceChip(
          label: Text(AvatarPresetService.hairStyleLabels[style] ?? ''),
          selected: isSelected,
          onSelected: (_) => setState(() => _hairStyle = style),
          selectedColor: const Color(0xFF111827),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFaceShapeOptions() {
    return Wrap(
      spacing: 12,
      children: AvatarFaceShape.values.map((shape) {
        final isSelected = _faceShape == shape;
        return ChoiceChip(
          label: Text(AvatarPresetService.faceShapeLabels[shape] ?? ''),
          selected: isSelected,
          onSelected: (_) => setState(() => _faceShape = shape),
          selectedColor: const Color(0xFF111827),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEyeOptions() {
    return Wrap(
      spacing: 12,
      children: AvatarEyeStyle.values.map((style) {
        final isSelected = _eyeStyle == style;
        return ChoiceChip(
          label: Text(AvatarPresetService.eyeStyleLabels[style] ?? ''),
          selected: isSelected,
          onSelected: (_) => setState(() => _eyeStyle = style),
          selectedColor: const Color(0xFF111827),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMouthOptions() {
    return Wrap(
      spacing: 12,
      children: AvatarMouthStyle.values.map((style) {
        final isSelected = _mouthStyle == style;
        return ChoiceChip(
          label: Text(AvatarPresetService.mouthStyleLabels[style] ?? ''),
          selected: isSelected,
          onSelected: (_) => setState(() => _mouthStyle = style),
          selectedColor: const Color(0xFF111827),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccessoryOptions() {
    return Wrap(
      spacing: 12,
      children: AvatarAccessory.values.map((accessory) {
        final isSelected = _accessory == accessory;
        return ChoiceChip(
          label: Text(AvatarPresetService.accessoryLabels[accessory] ?? ''),
          selected: isSelected,
          onSelected: (_) => setState(() => _accessory = accessory),
          selectedColor: const Color(0xFF111827),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final AvatarPreset preset;
  final String label;
  final double size;
  final bool animate;
  final bool highlight;
  final bool compact;

  const _AvatarPreview({
    required this.preset,
    required this.label,
    required this.size,
    required this.animate,
    required this.highlight,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = ClipOval(
      key: ValueKey(preset.id),
      child: _buildAvatarImage(),
    );

    final avatar = animate
        ? AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: image,
          )
        : image;

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.08),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: highlight
                  ? const [Color(0xFFFFF0D6), Color(0xFFE7F2FF)]
                  : const [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
            ),
            border: Border.all(
              color:
                  highlight ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
              width: highlight ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(highlight ? 0.12 : 0.05),
                blurRadius: highlight ? 16 : 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: avatar,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    final resolvedUrl =
        AvatarPresetService.resolveAvatarImageUrl(preset.imageAsset);
    if (resolvedUrl.isEmpty) {
      return _avatarFallback();
    }
    if (AvatarPresetService.isAssetPath(resolvedUrl)) {
      return Image.asset(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(),
      );
    }
    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => _avatarPlaceholder(),
      errorWidget: (_, __, ___) => _avatarFallback(),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.person, color: Color(0xFF9CA3AF)),
    );
  }
}

class _AttributeChip extends StatelessWidget {
  final String label;

  const _AttributeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isDisabled ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
          ),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  isDisabled ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDisabled
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final AvatarPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hairStyle =
        AvatarPresetService.hairStyleLabels[preset.hairStyle] ?? '';
    final accessory =
        AvatarPresetService.accessoryLabels[preset.accessory] ?? '';
    final subtitle = [hairStyle, accessory]
        .where((label) => label.isNotEmpty)
        .join(' | ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipOval(
              child: _buildAvatarThumb(),
            ),
            const SizedBox(height: 8),
            Text(
              AvatarPresetService.hairLabels[preset.hairColor] ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarThumb() {
    final resolvedUrl =
        AvatarPresetService.resolveAvatarImageUrl(preset.imageAsset);
    if (resolvedUrl.isEmpty) {
      return _avatarFallback();
    }
    if (AvatarPresetService.isAssetPath(resolvedUrl)) {
      return Image.asset(
        resolvedUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(),
      );
    }
    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      placeholder: (_, __) => _avatarPlaceholder(),
      errorWidget: (_, __, ___) => _avatarFallback(),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.person, color: Color(0xFF9CA3AF)),
    );
  }
}
