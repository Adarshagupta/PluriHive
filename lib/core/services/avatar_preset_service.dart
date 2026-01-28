import 'package:flutter/material.dart';
import 'api_config.dart';

enum AvatarGender { male, female }

enum AvatarSkinTone { light, medium, tan, dark }

enum AvatarHairColor { black, brown, blonde }

enum AvatarHairStyle { short, curls, ponytail }

enum AvatarFaceShape { round, oval, square }

enum AvatarEyeStyle { normal, happy }

enum AvatarMouthStyle { smile, open }

enum AvatarAccessory { none, glasses }

class AvatarPreset {
  final String id;
  final AvatarGender gender;
  final AvatarSkinTone skinTone;
  final AvatarHairColor hairColor;
  final AvatarHairStyle hairStyle;
  final AvatarFaceShape faceShape;
  final AvatarEyeStyle eyeStyle;
  final AvatarMouthStyle mouthStyle;
  final AvatarAccessory accessory;
  final String imageAsset;

  const AvatarPreset({
    required this.id,
    required this.gender,
    required this.skinTone,
    required this.hairColor,
    required this.hairStyle,
    required this.faceShape,
    required this.eyeStyle,
    required this.mouthStyle,
    required this.accessory,
    required this.imageAsset,
  });
}

class AvatarPresetService {
  static const String modelPrefix = 'preset:';
  static const String legacyAssetBasePath = 'assets/avatars/previews';
  static const String staticBasePath = '/static/avatars/previews';

  static final List<AvatarPreset> presets = _buildPresets();

  static const Map<AvatarGender, String> genderLabels = {
    AvatarGender.male: 'Male',
    AvatarGender.female: 'Female',
  };

  static const Map<AvatarSkinTone, String> skinToneLabels = {
    AvatarSkinTone.light: 'Light',
    AvatarSkinTone.medium: 'Medium',
    AvatarSkinTone.tan: 'Tan',
    AvatarSkinTone.dark: 'Dark',
  };

  static const Map<AvatarHairColor, String> hairLabels = {
    AvatarHairColor.black: 'Black',
    AvatarHairColor.brown: 'Brown',
    AvatarHairColor.blonde: 'Blonde',
  };

  static const Map<AvatarHairStyle, String> hairStyleLabels = {
    AvatarHairStyle.short: 'Short',
    AvatarHairStyle.curls: 'Curls',
    AvatarHairStyle.ponytail: 'Ponytail',
  };

  static const Map<AvatarFaceShape, String> faceShapeLabels = {
    AvatarFaceShape.round: 'Round',
    AvatarFaceShape.oval: 'Oval',
    AvatarFaceShape.square: 'Square',
  };

  static const Map<AvatarEyeStyle, String> eyeStyleLabels = {
    AvatarEyeStyle.normal: 'Normal',
    AvatarEyeStyle.happy: 'Happy',
  };

  static const Map<AvatarMouthStyle, String> mouthStyleLabels = {
    AvatarMouthStyle.smile: 'Smile',
    AvatarMouthStyle.open: 'Open',
  };

  static const Map<AvatarAccessory, String> accessoryLabels = {
    AvatarAccessory.none: 'None',
    AvatarAccessory.glasses: 'Glasses',
  };

  static const Map<AvatarSkinTone, Color> skinToneColors = {
    AvatarSkinTone.light: Color(0xFFF0C8AA),
    AvatarSkinTone.medium: Color(0xFFC68C64),
    AvatarSkinTone.tan: Color(0xFFD6A07A),
    AvatarSkinTone.dark: Color(0xFF845840),
  };

  static const Map<AvatarHairColor, Color> hairColors = {
    AvatarHairColor.black: Color(0xFF282828),
    AvatarHairColor.brown: Color(0xFF604020),
    AvatarHairColor.blonde: Color(0xFFD6BA7E),
  };

  static const AvatarHairStyle defaultHairStyle = AvatarHairStyle.short;
  static const AvatarFaceShape defaultFaceShape = AvatarFaceShape.round;
  static const AvatarEyeStyle defaultEyeStyle = AvatarEyeStyle.normal;
  static const AvatarMouthStyle defaultMouthStyle = AvatarMouthStyle.smile;
  static const AvatarAccessory defaultAccessory = AvatarAccessory.none;

  static List<AvatarPreset> _buildPresets() {
    final List<AvatarPreset> result = [];
    for (final gender in AvatarGender.values) {
      for (final skinTone in AvatarSkinTone.values) {
        for (final hairColor in AvatarHairColor.values) {
          for (final hairStyle in AvatarHairStyle.values) {
            for (final faceShape in AvatarFaceShape.values) {
              for (final eyeStyle in AvatarEyeStyle.values) {
                for (final mouthStyle in AvatarMouthStyle.values) {
                  for (final accessory in AvatarAccessory.values) {
                    final id = presetId(
                      gender,
                      skinTone,
                      hairColor,
                      hairStyle,
                      faceShape,
                      eyeStyle,
                      mouthStyle,
                      accessory,
                    );
                    result.add(
                      AvatarPreset(
                        id: id,
                        gender: gender,
                        skinTone: skinTone,
                        hairColor: hairColor,
                        hairStyle: hairStyle,
                        faceShape: faceShape,
                        eyeStyle: eyeStyle,
                        mouthStyle: mouthStyle,
                        accessory: accessory,
                        imageAsset: imagePathForPresetId(id),
                      ),
                    );
                  }
                }
              }
            }
          }
        }
      }
    }
    return result;
  }

  static String presetId(
    AvatarGender gender,
    AvatarSkinTone skinTone,
    AvatarHairColor hairColor,
    AvatarHairStyle hairStyle,
    AvatarFaceShape faceShape,
    AvatarEyeStyle eyeStyle,
    AvatarMouthStyle mouthStyle,
    AvatarAccessory accessory,
  ) {
    return '${gender.name}_${skinTone.name}_${hairColor.name}'
        '_${hairStyle.name}_${faceShape.name}_${eyeStyle.name}'
        '_${mouthStyle.name}_${accessory.name}';
  }

  static String imageAssetForPresetId(String presetId) {
    return imagePathForPresetId(presetId);
  }

  static String imagePathForPresetId(String presetId) {
    final normalized = normalizePresetId(presetId);
    return '$staticBasePath/$normalized.png';
  }

  static String legacyAssetPathForPresetId(String presetId) {
    final normalized = normalizePresetId(presetId);
    return '$legacyAssetBasePath/$normalized.png';
  }

  static String imageUrlForPresetId(String presetId) {
    return '${_normalizedBaseUrl()}${imagePathForPresetId(presetId)}';
  }

  static String _normalizedBaseUrl() {
    final baseUrl = ApiConfig.baseUrl;
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  static AvatarPreset findPreset({
    required AvatarGender gender,
    required AvatarSkinTone skinTone,
    required AvatarHairColor hairColor,
    required AvatarHairStyle hairStyle,
    required AvatarFaceShape faceShape,
    required AvatarEyeStyle eyeStyle,
    required AvatarMouthStyle mouthStyle,
    required AvatarAccessory accessory,
  }) {
    final id = presetId(
      gender,
      skinTone,
      hairColor,
      hairStyle,
      faceShape,
      eyeStyle,
      mouthStyle,
      accessory,
    );
    return presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => presets.first,
    );
  }

  static String toModelValue(String presetId) {
    return '$modelPrefix$presetId';
  }

  static bool isAssetPath(String value) {
    return value.startsWith('assets/') || value.startsWith('asset://');
  }

  static String normalizeAssetPath(String value) {
    final normalized =
        value.startsWith('asset://') ? value.substring('asset://'.length) : value;
    if (normalized.contains(legacyAssetBasePath) && normalized.endsWith('.png')) {
      final presetId = extractPresetId(normalized);
      if (presetId != null) {
        return legacyAssetPathForPresetId(presetId);
      }
    }
    return normalized;
  }

  static String? extractPresetId(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith(modelPrefix)) {
      return value.substring(modelPrefix.length);
    }
    final staticPathNoSlash = staticBasePath.startsWith('/')
        ? staticBasePath.substring(1)
        : staticBasePath;
    if (value.contains(legacyAssetBasePath) ||
        value.contains(staticBasePath) ||
        value.contains(staticPathNoSlash)) {
      final parts = value.split('/');
      final fileName = parts.isNotEmpty ? parts.last : '';
      if (fileName.endsWith('.png')) {
        return fileName.substring(0, fileName.length - 4);
      }
    }
    return null;
  }

  static String normalizePresetId(String presetId) {
    final parts = presetId.split('_');
    if (parts.length >= 8) return presetId;
    if (parts.length < 3) return presetId;
    final padded = List<String>.from(parts);
    const defaults = [
      AvatarHairStyle.short,
      AvatarFaceShape.round,
      AvatarEyeStyle.normal,
      AvatarMouthStyle.smile,
      AvatarAccessory.none,
    ];
    for (int i = padded.length; i < 8; i++) {
      final defaultIndex = i - 3;
      if (defaultIndex >= 0 && defaultIndex < defaults.length) {
        padded.add(defaults[defaultIndex].name);
      } else {
        padded.add(AvatarAccessory.none.name);
      }
    }
    return padded.join('_');
  }

  static String resolveAvatarImageUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith(modelPrefix)) {
      final presetId = extractPresetId(value);
      if (presetId != null) {
        return imageUrlForPresetId(presetId);
      }
    }

    final normalized = value.startsWith('asset://')
        ? value.substring('asset://'.length)
        : value;

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    if (isAssetPath(normalized)) {
      final presetId = extractPresetId(normalized);
      if (presetId != null) {
        return imageUrlForPresetId(presetId);
      }
      return normalized;
    }

    final baseUrl = _normalizedBaseUrl();
    if (normalized.startsWith('/')) {
      return '$baseUrl$normalized';
    }

    return '$baseUrl/$normalized';
  }

  static AvatarPreset? fromStored({
    String? avatarModelUrl,
    String? avatarImageUrl,
  }) {
    final presetIdFromModel = extractPresetId(avatarModelUrl);
    final presetIdFromImage = extractPresetId(avatarImageUrl);
    final id = presetIdFromModel ?? presetIdFromImage;
    if (id == null) return null;
    final normalized = normalizePresetId(id);
    for (final preset in presets) {
      if (preset.id == normalized) return preset;
    }
    return null;
  }
}
