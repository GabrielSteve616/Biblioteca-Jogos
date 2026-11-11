import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/case_profile.dart';
import '../models/game.dart';

/// Single vertical line of print. The spine spans the complete closed case,
/// rather than covering only the rear half of a small plastic edge.
Future<ui.Image> spinePaper(Game game, ui.Image front) async {
  final profile = CaseProfile.forPlatform(game.platform);
  const w = 112.0;
  final h = (w * profile.heightMm / profile.depthMm).clamp(800.0, 1536.0);
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  final lightSpine = ['PS1', 'PS2', 'PS3', 'PS5'].contains(game.platform);
  final background = lightSpine ? const Color(0xfff1eee4) : profile.brand;
  final ink = lightSpine ? const Color(0xff1d2228) : Colors.white;
  c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = background);
  if (!lightSpine) {
    c.drawImageRect(
      front,
      Rect.fromLTWH(0, 0, front.width * .065, front.height.toDouble()),
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = Colors.white.withValues(alpha: .24),
    );
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = background.withValues(alpha: .75),
    );
  }
  final paperWorldHeight = profile.halfHeight * 2 - .11;
  final paperTextureHeight = profile.jewel
      ? 600.0
      : 600 * paperWorldHeight / 1.504;
  final bandWorldHeight = paperWorldHeight * 52 / paperTextureHeight;
  final spineTop = profile.halfHeight - math.max(.025, profile.corner);
  final brandHeight =
      h *
      (bandWorldHeight + .055 - math.max(.025, profile.corner)) /
      (spineTop * 2);
  c.drawRect(
    Rect.fromLTWH(0, 0, w, brandHeight),
    Paint()..color = profile.brand,
  );
  final brand = TextPainter(
    text: TextSpan(
      text: game.platform.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Roboto',
        color: profile.ink,
        fontSize: game.platform == 'Android' ? 20 : 30,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: w - 12);
  brand.paint(
    c,
    Offset((w - brand.width) / 2, (brandHeight - brand.height) / 2),
  );
  c.save();
  c.translate(w / 2, brandHeight + 38);
  c.rotate(math.pi / 2);
  final title = TextPainter(
    text: TextSpan(
      text: game.title,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 37,
        color: ink,
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: h - brandHeight - 150);
  title.paint(c, Offset(0, -title.height / 2));
  c.restore();
  c.drawLine(
    Offset(12, h - 78),
    Offset(w - 12, h - 78),
    Paint()..color = ink.withValues(alpha: .25),
  );
  final footer = TextPainter(
    text: TextSpan(
      text: game.platform,
      style: TextStyle(
        fontFamily: 'Roboto',
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: w - 12);
  footer.paint(c, Offset((w - footer.width) / 2, h - 53));
  // Fold lines are printed on the same continuous sheet.
  c.drawLine(
    const Offset(1, 0),
    Offset(1, h),
    Paint()..color = Colors.black.withValues(alpha: .12),
  );
  c.drawLine(
    Offset(w - 2, 0),
    Offset(w - 2, h),
    Paint()..color = Colors.white.withValues(alpha: .3),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  picture.dispose();
  return image;
}
