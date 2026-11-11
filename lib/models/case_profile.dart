import 'package:flutter/material.dart';

/// Common retail single-disc formats. Regional/special editions can differ.
/// World units preserve the width/height/depth ratios of the physical case.
class CaseProfile {
  const CaseProfile(
    this.widthMm,
    this.heightMm,
    this.depthMm,
    this.shell,
    this.brand,
    this.ink, {
    this.corner = .045,
    this.jewel = false,
  });
  final double widthMm, heightMm, depthMm, corner;
  final Color shell, brand, ink;
  final bool jewel;
  double get halfHeight => .81 * heightMm / widthMm;
  double get depthScale => (1.62 * depthMm / widthMm) / .29;
  double get discRadius => 1.62 * 60 / widthMm;
  double get paperLeft => jewel ? -.61 : -.752;
  static CaseProfile forPlatform(String platform) => switch (platform) {
    'PS1' => const CaseProfile(
      142,
      125,
      10.5,
      Color(0xffb6c5cd),
      Color(0xff202326),
      Colors.white,
      corner: .014,
      jewel: true,
    ),
    'PS2' => const CaseProfile(
      135,
      190,
      14,
      Color(0xff15171b),
      Color(0xff101116),
      Colors.white,
      corner: .025,
    ),
    'PS3' => const CaseProfile(
      135,
      171,
      15,
      Color(0xffb7c2c9),
      Color(0xff151619),
      Colors.white,
      corner: .055,
    ),
    'PS4' => const CaseProfile(
      134,
      170,
      14,
      Color(0xff1262ad),
      Color(0xff0754a0),
      Colors.white,
      corner: .050,
    ),
    'PS5' => const CaseProfile(
      134,
      170,
      14,
      Color(0xff1664ad),
      Color(0xffeceef1),
      Color(0xff18191d),
      corner: .050,
    ),
    'Steam' => const CaseProfile(
      135,
      190,
      14,
      Color(0xff213847),
      Color(0xff162837),
      Colors.white,
      corner: .055,
    ),
    // Android uses the same virtual DVD case format as Steam.
    _ => const CaseProfile(
      135,
      190,
      14,
      Color(0xff25333f),
      Color(0xff18232e),
      Color(0xff71eeef),
      corner: .055,
    ),
  };
}
