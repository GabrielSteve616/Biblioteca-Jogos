import 'package:acervo/models/case_profile.dart';
import 'package:acervo/models/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Models preserve physical width, height and depth instead of stretching a single cube',
    () {
      final cd = CaseProfile.forPlatform('PS1');
      final dvd = CaseProfile.forPlatform('PS2');
      final blu = CaseProfile.forPlatform('PS4');
      expect(cd.halfHeight / .81, closeTo(125 / 142, .00001));
      expect(dvd.halfHeight / .81, closeTo(190 / 135, .00001));
      expect(blu.halfHeight / .81, closeTo(170 / 134, .00001));
      expect(dvd.halfHeight, greaterThan(blu.halfHeight));
      expect(.29 * blu.depthScale / 1.62, closeTo(14 / 134, .00001));
      expect(cd.discRadius * 2 / 1.62, closeTo(120 / 142, .00001));
    },
  );
  test(
    'PS3, PS4 and Steam use real curved perimeters with sufficient spine area',
    () {
      for (final platform in ['PS3', 'PS4', 'Steam']) {
        final profile = CaseProfile.forPlatform(platform);
        expect(profile.corner, greaterThanOrEqualTo(.045));
        expect(profile.depthScale, inInclusiveRange(.3, .8));
        expect(profile.heightMm / profile.depthMm, greaterThan(10));
      }
      for (final platform in Game.platforms) {
        expect(CaseProfile.forPlatform(platform).halfHeight, greaterThan(.6));
      }
    },
  );
}
