import 'package:flutter/material.dart';

import '../theme.dart';

/// Flag-shaped banner at the top of the main page. It will later show an image
/// matching the user's selected theme; for now it's a solid orange placeholder.
/// Tapping it opens the detailed profile page.
class ProfileBanner extends StatelessWidget {
  const ProfileBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: _FlagClipper(),
        child: Container(
          height: 70,
          width: double.infinity,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

/// Clips a rectangle into a flag/pennant with a V-notch cut into the right edge.
class _FlagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const notch = 26.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - notch, h / 2)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
