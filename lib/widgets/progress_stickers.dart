import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/game.dart';

/// Independent progress markers, rendered both on real 3D paper and library covers.
class CornerStickersPainter extends CustomPainter {
  CornerStickersPainter(this.game);
  final Game game;
  @override
  void paint(Canvas canvas, Size size) {
    final edge = math.min(size.width * .36, size.height * .23);
    void ribbon(String text, Color color, int corner) {
      canvas.save();
      if (corner == 1) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      if (corner == 2) {
        canvas.translate(size.width, size.height);
        canvas.scale(-1, -1);
      }
      if (corner == 3) {
        canvas.translate(0, size.height);
        canvas.scale(1, -1);
      }
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(edge, 0)
        ..lineTo(0, edge)
        ..close();
      canvas.drawShadow(path, Colors.black, 3, false);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Color.lerp(color, Colors.white, .45)!,
              color,
              Color.lerp(color, Colors.black, .3)!,
            ],
            stops: const [0, .5, 1],
          ).createShader(Rect.fromLTWH(0, 0, edge, edge)),
      );
      canvas.drawLine(
        Offset(0, edge - 2),
        Offset(edge - 2, 0),
        Paint()
          ..color = Colors.white54
          ..strokeWidth = .8,
      );
      canvas.translate(edge * .33, edge * .33);
      // Undo corner reflection for readable text.
      if (corner == 1) canvas.scale(-1, 1);
      if (corner == 2) canvas.scale(-1, -1);
      if (corner == 3) canvas.scale(1, -1);
      canvas.rotate(corner == 0 || corner == 3 ? -math.pi / 4 : math.pi / 4);
      final label = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: const Color(0xff14232a),
            fontSize: edge * .16,
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      canvas.restore();
    }

    if (game.finished) ribbon('ZERADO', const Color(0xff74d8b3), 0);
    if (game.platinum) ribbon('PLATINA', const Color(0xffc5d9ee), 1);
    if (game.complete) ribbon('100%', const Color(0xfff4ce75), 2);
    if (game.favorite) ribbon('FAV', const Color(0xffed78ba), 3);
  }

  @override
  bool shouldRepaint(covariant CornerStickersPainter old) =>
      old.game.finished != game.finished ||
      old.game.platinum != game.platinum ||
      old.game.complete != game.complete ||
      old.game.favorite != game.favorite;
}

class ProgressControls extends StatelessWidget {
  const ProgressControls({
    super.key,
    required this.game,
    required this.onToggle,
    this.busy = false,
  });
  final Game game;
  final ValueChanged<String> onToggle;
  final bool busy;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      control(
        'finished',
        'Zerado',
        Icons.check_rounded,
        game.finished,
        const Color(0xff74d8b3),
      ),
      control(
        'platinum',
        'Platina',
        Icons.emoji_events_outlined,
        game.platinum,
        const Color(0xffc5d9ee),
      ),
      control(
        'complete',
        '100% das conquistas',
        Icons.workspace_premium_outlined,
        game.complete,
        const Color(0xfff4ce75),
      ),
      control(
        'favorite',
        'Favorito',
        Icons.favorite_outline,
        game.favorite,
        const Color(0xffed78ba),
      ),
    ],
  );
  Widget control(
    String key,
    String label,
    IconData icon,
    bool selected,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Semantics(
      label: label,
      toggled: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? color : const Color(0xeb101b27),
          shape: CircleBorder(
            side: BorderSide(color: selected ? color : const Color(0xff425468)),
          ),
          elevation: selected ? 4 : 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : () => onToggle(key),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                icon,
                size: 22,
                color: selected ? const Color(0xff11232a) : color,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
