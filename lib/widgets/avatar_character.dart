import 'package:flutter/material.dart';

import '../models/app_state.dart';

/// Path to the default character art. Isolated here so it can later vary by
/// theme / customization.
const String kDefaultAvatarAsset = 'assets/avatar_default.png';

/// Path to the stage/podium the character stands on.
const String kStageAsset = 'assets/stage.png';

/// The user's trainer avatar rendered from the character artwork.
class AvatarCharacter extends StatelessWidget {
  const AvatarCharacter({
    super.key,
    required this.gender,
    this.size = 130,
  });

  final AvatarGender gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kDefaultAvatarAsset,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// The avatar standing on a rounded pedestal — the centrepiece of the main
/// page. [diameter] controls the overall footprint size. The character art is a
/// square image with the figure centred, so the pedestal is placed near where
/// the feet fall.
class AvatarPlatform extends StatelessWidget {
  const AvatarPlatform({
    super.key,
    required this.gender,
    this.diameter = 200,
  });

  final AvatarGender gender;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter * 1.1,
      child: Stack(
        children: [
          // Stage/podium at the bottom.
          Positioned(
            bottom: 0,
            left: 0,
            width: diameter,
            height: diameter,
            child: Image.asset(kStageAsset, fit: BoxFit.contain),
          ),
          // Character standing on the stage's top surface.
          Positioned(
            bottom: diameter * 0.2,
            left: diameter * 0.05,
            width: diameter * 0.9,
            height: diameter * 0.9,
            child: Image.asset(kDefaultAvatarAsset, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
