import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/game.dart';
import 'cover.dart';

/// Printed retro package composition. Image panels are explicitly cover details,
/// never fabricated gameplay screenshots or product certifications.
Future<ui.Image> retroBack(Game game, ui.Image cover) async {
  const w = 720.0, h = 960.0;
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  const ink = Color(0xff202728), paper = Color(0xffe7e1ce);
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = paper);
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, 460),
    Paint()..color = const Color(0xff19232b),
  );
  paintImage(
    canvas: c,
    rect: const Rect.fromLTWH(0, 0, w, 460),
    image: cover,
    fit: BoxFit.cover,
  );
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, 460),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x99121b24), Color(0xdd121b24)],
      ).createShader(const Rect.fromLTWH(0, 0, w, 460)),
  );
  void text(
    String value,
    Rect rect,
    double fontSize,
    Color color, {
    FontWeight weight = FontWeight.normal,
    int? lines,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.25,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: lines == null ? null : '…',
    )..layout(maxWidth: rect.width);
    c.save();
    c.clipRect(rect);
    p.paint(c, rect.topLeft);
    c.restore();
  }

  c.drawRect(
    const Rect.fromLTWH(0, 0, w, 48),
    Paint()..color = platformColor(game.platform),
  );
  text(
    game.platform.toUpperCase(),
    const Rect.fromLTWH(30, 10, 660, 30),
    22,
    Colors.white,
    weight: FontWeight.w800,
    lines: 1,
  );
  text(
    game.title.toUpperCase(),
    const Rect.fromLTWH(30, 78, 660, 132),
    43,
    Colors.white,
    weight: FontWeight.w900,
    lines: 2,
  );
  text(
    game.description.isEmpty
        ? 'UMA HISTÓRIA NA SUA COLEÇÃO.'
        : game.description,
    const Rect.fromLTWH(32, 222, 656, 201),
    23,
    const Color(0xfff3efe2),
    lines: 6,
  );
  text(
    'DETALHES DA ARTE',
    const Rect.fromLTWH(30, 479, 660, 22),
    13,
    ink,
    weight: FontWeight.w800,
    lines: 1,
  );
  for (var i = 0; i < 3; i++) {
    final rect = Rect.fromLTWH(30 + i * 226.0, 510, 208, 134);
    c.drawRect(rect.inflate(3), Paint()..color = ink);
    // These are crops of the supplied cover, not screenshots.
    paintImage(
      canvas: c,
      rect: rect,
      image: cover,
      fit: BoxFit.cover,
      alignment: Alignment(-1 + i.toDouble(), 0),
    );
  }
  text(
    'INFORMAÇÕES DO JOGO',
    const Rect.fromLTWH(30, 670, 660, 26),
    17,
    ink,
    weight: FontWeight.w900,
    lines: 1,
  );
  final fields = [
    ['PLATAFORMA', game.platform],
    ['GÊNERO', game.genre],
    ['LANÇAMENTO', game.year],
    ['JOGADORES', game.players],
  ];
  for (var i = 0; i < fields.length; i++) {
    final x = i.isEven ? 30.0 : 374.0, y = 713.0 + (i ~/ 2) * 60;
    text(
      fields[i][0],
      Rect.fromLTWH(x, y, 308, 18),
      12,
      const Color(0xff59615d),
      weight: FontWeight.w800,
      lines: 1,
    );
    text(
      fields[i][1].isEmpty ? 'Não informado' : fields[i][1],
      Rect.fromLTWH(x, y + 20, 308, 28),
      20,
      ink,
      weight: FontWeight.w700,
      lines: 1,
    );
  }
  c.drawLine(
    const Offset(30, 845),
    const Offset(690, 845),
    Paint()
      ..color = ink
      ..strokeWidth = 1,
  );
  if (game.rating.isNotEmpty) {
    c.drawRect(const Rect.fromLTWH(30, 860, 78, 70), Paint()..color = ink);
    text(
      game.rating,
      const Rect.fromLTWH(37, 880, 64, 38),
      23,
      paper,
      weight: FontWeight.w900,
      lines: 1,
    );
  }
  text(
    'COLEÇÃO PESSOAL\nArte e dados cadastrados pelo proprietário.',
    Rect.fromLTWH(game.rating.isEmpty ? 30 : 126, 870, 370, 66),
    14,
    ink,
    weight: FontWeight.w600,
    lines: 3,
  );
  final bits = game.id.codeUnits.fold<int>(
    17,
    (a, b) => (a * 31 + b) & 0x7fffffff,
  );
  var x = 531.0;
  for (var i = 0; i < 38; i++) {
    final width = ((bits >> (i % 23)) & 1) == 0 ? 1.5 : 3.0;
    if (i.isEven) {
      c.drawRect(Rect.fromLTWH(x, 865, width, 44), Paint()..color = ink);
    }
    x += width + 1;
  }
  text(
    'ID DA COLEÇÃO',
    const Rect.fromLTWH(531, 915, 160, 20),
    10,
    ink,
    weight: FontWeight.w700,
    lines: 1,
  );
  // Light print grain; deterministic and inexpensive.
  for (var y = 0.0; y < h; y += 4) {
    c.drawLine(
      Offset(0, y),
      Offset(w, y),
      Paint()..color = const Color(0x037d715d),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  picture.dispose();
  return image;
}

Future<ui.Image> printedDisc(Game game, ui.Image source) async {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, 720, 720);
  c.drawRect(rect, Paint()..color = const Color(0xffd6dce2));
  paintImage(canvas: c, rect: rect, image: source, fit: BoxFit.cover);
  c.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00101c26), Color(0xcc101c26)],
      ).createShader(rect),
  );
  c.drawRect(
    const Rect.fromLTWH(0, 450, 720, 270),
    Paint()..color = const Color(0xee14232d),
  );
  final title = TextPainter(
    text: TextSpan(
      text: game.title.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Roboto',
        color: Colors.white,
        fontSize: 34,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: 500);
  title.paint(c, Offset(360 - title.width / 2, 485));
  final platform = TextPainter(
    text: TextSpan(
      text: game.platform.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Roboto',
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  platform.paint(c, Offset(360 - platform.width / 2, 145));
  c.drawCircle(
    const Offset(360, 360),
    52,
    Paint()..color = const Color(0xffb7c2c9),
  );
  c.drawCircle(
    const Offset(360, 360),
    42,
    Paint()..color = const Color(0xffe1e8eb),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(720, 720);
  picture.dispose();
  return image;
}
