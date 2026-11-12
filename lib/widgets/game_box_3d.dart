import '../models/case_mesh.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/gestures.dart';
import '../models/game.dart';
import '../services/collection_store.dart';

import 'progress_stickers.dart';
import 'package_art.dart';
import 'spine_art.dart';
import '../models/case_profile.dart';

/// Reusable projected polygon renderer, using the same Flutter Canvas approach as Walken.
/// All faces have depth ordering; artwork is mapped to subdivided textured polygons.
class GameBox3D extends StatefulWidget {
  const GameBox3D({super.key, required this.game, required this.store});
  final Game game;
  final CollectionStore store;
  @override
  State<GameBox3D> createState() => GameBox3DState();
}

class GameBox3DState extends State<GameBox3D> with TickerProviderStateMixin {
  late final AnimationController lid = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController removal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  ui.Image? front, back, spine, disc, _plainFront;
  _BoxPainter? _painter;
  CaseMesh? mesh;
  bool get usesImportedMesh => mesh != null;
  Size _sceneSize = Size.zero;
  String _drag = 'orbit';
  Offset _dragStart = Offset.zero;
  int _stampRevision = 0;

  /// Same picking path used by touch input and accessibility/integration checks.
  Offset? visiblePartCenter(String part) => _painter?.pointFor(part);
  double rx = -.12, ry = .34, zoom = 1, startZoom = 1, discX = 0, discY = 0;
  Offset last = Offset.zero;
  Offset? _pointerStart;
  bool opened = false, removed = false, discMode = false, loading = true;
  CaseProfile get profile => CaseProfile.forPlatform(widget.game.platform);
  bool get android => widget.game.platform == 'Android';

  @override
  void initState() {
    super.initState();
    loadArt();
  }

  Future<ui.Image?> decode(String name) async {
    if (name.isEmpty) return null;
    final codec = await ui.instantiateImageCodec(
      await File(widget.store.path(name)).readAsBytes(),
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    return image;
  }

  Future<ui.Image> artwork({
    bool rear = false,
    bool edge = false,
    ui.Image? cover,
  }) async {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final w = edge ? 100.0 : 600.0;
    const h = 800.0;
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = profile.brand);
    if (cover != null && !edge) {
      paintImage(
        canvas: c,
        rect: Rect.fromLTWH(0, 0, w, h),
        image: cover,
        fit: BoxFit.cover,
      );
      c.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Colors.black.withValues(alpha: .78),
      );
    }
    var y = 55.0;
    void text(String value, double size, Color color, {double gap = 25}) {
      if (value.isEmpty) return;
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: rear ? 9 : 6,
        ellipsis: '…',
      );
      painter.layout(maxWidth: w - 48);
      painter.paint(c, Offset(24, y));
      y += painter.height + gap;
    }

    text(
      widget.game.platform.toUpperCase(),
      edge ? 19 : 25,
      const Color(0xff9ccfff),
    );
    text(widget.game.title, edge ? 27 : 44, profile.ink);
    if (rear) {
      text(widget.game.description, 25, const Color(0xffdfebf7));
      final metadata = [
        if (widget.game.genre.isNotEmpty) 'Gênero: ${widget.game.genre}',
        if (widget.game.year.isNotEmpty) 'Ano: ${widget.game.year}',
        if (widget.game.rating.isNotEmpty)
          'Classificação: ${widget.game.rating}',
        if (widget.game.players.isNotEmpty) 'Jogadores: ${widget.game.players}',
      ].join('\n');
      text(metadata, 23, const Color(0xffc0d2e8));
      c.drawLine(
        const Offset(24, 730),
        Offset(w - 24, 730),
        Paint()..color = Colors.white38,
      );
      y = 745;
      text(
        'COLEÇÃO PESSOAL • ${widget.game.platform}',
        16,
        Colors.white70,
        gap: 0,
      );
    }
    if (android) cyberpunk(c, w, h);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    picture.dispose();
    return image;
  }

  Future<ui.Image> frontPaper(ui.Image source) async {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    const w = 600.0;
    final h = profile.jewel
        ? 600.0
        : (600 * (profile.halfHeight * 2 - .11) / 1.504);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = profile.brand);
    paintImage(
      canvas: c,
      rect: Rect.fromLTWH(0, 52, w, h - 52),
      image: source,
      fit: BoxFit.cover,
    );
    final text = TextPainter(
      text: TextSpan(
        text: switch (widget.game.platform) {
          'PS1' => 'PlayStation',
          'PS2' => 'PlayStation 2',
          'PS3' => 'PlayStation 3',
          'PS4' => 'PlayStation 4',
          'PS5' => 'PlayStation 5',
          'Android' => 'ANDROID',
          'Steam' => 'STEAM • PC',
          _ => 'BIBLIOTECA',
        },
        style: TextStyle(
          fontFamily: 'Roboto',
          color: profile.ink,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 550);
    text.paint(c, const Offset(24, 9));
    if (android) cyberpunk(c, w, h);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    picture.dispose();
    return image;
  }

  void cyberpunk(Canvas c, double w, double h) {
    final cyan = Paint()
      ..color = const Color(0xff4cf5ef)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final pink = Paint()
      ..color = const Color(0xffff4cbe)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawPath(
      Path()
        ..moveTo(10, 70)
        ..lineTo(10, h * .62)
        ..lineTo(22, h * .65)
        ..lineTo(22, h - 36),
      cyan,
    );
    c.drawPath(
      Path()
        ..moveTo(w - 10, 70)
        ..lineTo(w - 10, h * .32)
        ..lineTo(w - 24, h * .35)
        ..lineTo(w - 24, h - 28),
      pink,
    );
    c.drawLine(Offset(26, h - 18), Offset(w - 26, h - 18), cyan);
    for (var x = 32.0; x < w - 32; x += 24) {
      c.drawLine(
        Offset(x, h - 29),
        Offset(x + 10, h - 39),
        Paint()
          ..color = const Color(0xffffda65)
          ..strokeWidth = 5,
      );
    }
  }

  Future<void> loadArt() async {
    try {
      if (CaseMesh.supports(widget.game.platform)) mesh = await CaseMesh.load();
      final source = await decode(widget.game.front);
      final f = source == null ? await artwork() : await frontPaper(source);
      source?.dispose();
      final b =
          await decode(widget.game.back) ?? await retroBack(widget.game, f);
      final s = await spinePaper(widget.game, f);
      final customMedia = await decode(widget.game.disc);
      final d = customMedia ?? await printedDisc(widget.game, f);
      if (!mounted) {
        f.dispose();
        b.dispose();
        s.dispose();
        d.dispose();
        return;
      }
      setState(() {
        front = f;
        _plainFront = f;
        back = b;
        spine = s;
        disc = d;
        loading = false;
      });
      await stampFront();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant GameBox3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.finished != widget.game.finished ||
        oldWidget.game.platinum != widget.game.platinum ||
        oldWidget.game.complete != widget.game.complete ||
        oldWidget.game.favorite != widget.game.favorite) {
      stampFront();
    }
  }

  Future<void> stampFront() async {
    final source = _plainFront;
    if (source == null) return;
    final revision = ++_stampRevision;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.drawImage(source, Offset.zero, Paint());
    CornerStickersPainter(
      widget.game,
    ).paint(c, Size(source.width.toDouble(), source.height.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(source.width, source.height);
    picture.dispose();
    if (!mounted || revision != _stampRevision) {
      image.dispose();
      return;
    }
    setState(() {
      if (front != _plainFront) front?.dispose();
      front = image;
    });
  }

  void touch(Offset position) {
    final part = _painter?.hitPart(position);
    if (part == 'media' && opened) {
      takeDisc();
    } else if (part == 'lid' || part == 'case' || part == 'spine') {
      openClose();
    }
  }

  void begin(ScaleStartDetails d) {
    last = _pointerStart ?? d.localFocalPoint;
    _dragStart = last;
    startZoom = zoom;
    final hit = _painter?.hitPart(last);
    _drag = hit == 'media' && opened
        ? 'media'
        : hit == 'lid' && last.dx > _sceneSize.width * .58 && !removed
        ? 'hinge'
        : 'orbit';
  }

  void move(ScaleUpdateDetails d) {
    final delta = d.localFocalPoint - last;
    setState(() {
      if (d.pointerCount > 1) {
        _drag = 'zoom';
        zoom = (startZoom * d.scale).clamp(.55, 2.3);
      } else if (_drag == 'hinge') {
        lid.stop();
        lid.value = (lid.value - delta.dx / (_sceneSize.width * .65)).clamp(
          0,
          1,
        );
      } else if (_drag == 'media' && !removed) {
        removal.stop();
        removal.value =
            ((d.localFocalPoint - _dragStart).distance /
                    (_sceneSize.shortestSide * .35))
                .clamp(0, 1);
      } else if (_drag == 'media' || (discMode && removed)) {
        discY += delta.dx * .012;
        discX -= delta.dy * .012;
      } else {
        ry += delta.dx * .012;
        rx = (rx - delta.dy * .012).clamp(-1.5, 1.5);
      }
      last = d.localFocalPoint;
    });
  }

  void end(ScaleEndDetails d) {
    if (_drag == 'hinge') {
      setState(() => opened = lid.value > .3);
      lid.animateTo(opened ? 1 : 0, curve: Curves.easeOutCubic);
    } else if (_drag == 'media' && !removed && removal.value > 0) {
      setState(() {
        removed = removal.value > .3;
        discMode = removed;
      });
      removal.animateTo(removed ? 1 : 0, curve: Curves.easeOutCubic);
    }
    if (_drag == 'orbit' && !opened && !removed) {
      final nearest = (ry / math.pi).round() * math.pi;
      if ((ry - nearest).abs() < .38 && rx.abs() < .4) {
        setState(() {
          ry = nearest;
          rx = 0;
        });
      }
    }
    _drag = 'orbit';
  }

  void openClose() {
    if (removed || lid.isAnimating || removal.isAnimating) return;
    setState(() {
      opened = !opened;
      discMode = false;
    });
    opened ? lid.forward() : lid.reverse();
  }

  void takeDisc() {
    if (!opened || lid.isAnimating || removal.isAnimating) return;
    setState(() {
      removed = !removed;
      discMode = removed;
      discX = 0;
      discY = 0;
    });
    removed ? removal.forward() : removal.reverse();
  }

  void view(double angle, {double? tilt}) => setState(() {
    rx = tilt ?? ((angle.abs() - math.pi).abs() < .01 ? 0 : -.1);
    ry = angle;
    discMode = false;
  });
  void reset() {
    lid.reset();
    removal.reset();
    setState(() {
      opened = false;
      removed = false;
      discMode = false;
      rx = -.12;
      ry = .34;
      zoom = 1;
      discX = 0;
      discY = 0;
    });
  }

  @override
  void dispose() {
    lid.dispose();
    removal.dispose();
    if (front != _plainFront) front?.dispose();
    _plainFront?.dispose();
    back?.dispose();
    spine?.dispose();
    disc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _sceneSize = constraints.biggest;
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xff213641), Color(0xff0a111a)],
              radius: .9,
            ),
          ),
          child: Semantics(
            label: 'Visualizador 3D',
            value:
                '${opened ? "Caixa aberta" : "Caixa fechada"}${removed ? ", mídia retirada" : ""}',
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Abrir ou fechar caixa'):
                  openClose,
              const CustomSemanticsAction(label: 'Retirar ou recolocar mídia'):
                  takeDisc,
              const CustomSemanticsAction(label: 'Restaurar posição'): reset,
            },
            child: Listener(
              onPointerDown: (event) => _pointerStart = event.localPosition,
              child: GestureDetector(
                key: const ValueKey('case-touch-surface'),
                dragStartBehavior: DragStartBehavior.down,
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => touch(d.localPosition),
                onDoubleTap: reset,
                onScaleStart: begin,
                onScaleUpdate: move,
                onScaleEnd: end,
                child: Stack(
                  children: [
                    if (loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([lid, removal]),
                          builder: (_, _) {
                            _painter = _BoxPainter(
                              widget.game.platform,
                              mesh,
                              front,
                              back,
                              spine,
                              disc,
                              _plainFront,
                              rx,
                              ry,
                              zoom,
                              Curves.easeInOutCubic.transform(lid.value),
                              Curves.easeInOutCubic.transform(removal.value),
                              discX,
                              discY,
                            );
                            return CustomPaint(painter: _painter);
                          },
                        ),
                      ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Tooltip(
                            message: removed
                                ? 'Toque na mídia para guardar'
                                : opened
                                ? 'Toque na mídia para retirar'
                                : 'Toque na caixa para abrir',
                            child: const Icon(
                              Icons.touch_app_outlined,
                              size: 19,
                              color: Color(0xff8297a7),
                            ),
                          ),
                          const SizedBox(width: 22),
                          const Tooltip(
                            message:
                                'Arraste para girar. Puxe a borda para abrir.',
                            child: Icon(
                              Icons.swipe_outlined,
                              size: 19,
                              color: Color(0xff8297a7),
                            ),
                          ),
                          const SizedBox(width: 22),
                          const Tooltip(
                            message: 'Pinça para zoom',
                            child: Icon(
                              Icons.pinch_outlined,
                              size: 19,
                              color: Color(0xff8297a7),
                            ),
                          ),
                          const SizedBox(width: 22),
                          const Tooltip(
                            message: 'Dois toques para centralizar',
                            child: Icon(
                              Icons.center_focus_strong,
                              size: 19,
                              color: Color(0xff8297a7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V turn(double rx, double ry) {
    final yy = y * math.cos(rx) - z * math.sin(rx);
    final zz = y * math.sin(rx) + z * math.cos(rx);
    return _V(
      x * math.cos(ry) + zz * math.sin(ry),
      yy,
      -x * math.sin(ry) + zz * math.cos(ry),
    );
  }

  _V shift(double dx, double dy, double dz) => _V(x + dx, y + dy, z + dz);
}

class _Face {
  _Face(this.points, this.color, [this.image, this.uv]);
  final List<_V> points;
  final Color color;
  final ui.Image? image;
  final List<Offset>? uv;
  bool get backFacing {
    if (points.length != 4 && !cullMesh) return false;
    final a = points[0], b = points[1], c = points[2];
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) >= 0;
  }

  Color get litColor {
    if (points.length < 3) return color;
    final a = points[0], b = points[1], c = points[2];
    final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
    final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
    final nx = uy * vz - uz * vy,
        ny = uz * vx - ux * vz,
        nz = ux * vy - uy * vx;
    final length = math.sqrt(nx * nx + ny * ny + nz * nz);
    final lighting = length < .00001
        ? .85
        : (.62 + .38 * ((nx * -.35 + ny * .5 + nz * .78).abs() / length)).clamp(
            .60,
            1.0,
          );
    return Color.lerp(Colors.black, color, lighting)!;
  }

  List<_V>? clipOutline;
  bool cullMesh = false;
  bool edgeStroke = true;
  String part = 'case';
  double? groupedDepth;
  double get surfaceDepth =>
      points.fold<double>(0, (a, b) => a + b.z) / points.length;
  double get depth => groupedDepth ?? surfaceDepth;
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(
    this.platform,
    this.mesh,
    this.front,
    this.back,
    this.spine,
    this.disc,
    this.booklet,
    this.rx,
    this.ry,
    this.zoom,
    this.open,
    this.removal,
    this.discX,
    this.discY,
  );
  final String platform;
  final CaseMesh? mesh;
  CaseProfile get profile => CaseProfile.forPlatform(platform);
  final ui.Image? front, back, spine, disc, booklet;
  final double rx, ry, zoom, open, removal, discX, discY;
  final List<_Face> faces = [];
  final List<({Path path, String part})> regions = [];
  String _part = 'case';
  String? hitPart(Offset p) {
    for (final region in regions.reversed) {
      if (region.path.contains(p)) return region.part;
    }
    return null;
  }

  Offset? pointFor(String part) {
    for (final region in regions.reversed.where((r) => r.part == part)) {
      final bounds = region.path.getBounds();
      for (final fx in [.5, .25, .75]) {
        for (final fy in [.5, .25, .75]) {
          final p = Offset(
            bounds.left + bounds.width * fx,
            bounds.top + bounds.height * fy,
          );
          if (region.path.contains(p) && hitPart(p) == part) return p;
        }
      }
    }
    return null;
  }

  _V global(_V v) => v.turn(rx, ry);
  void face(
    List<_V> vertices,
    Color color, [
    ui.Image? image,
    List<Offset>? uv,
  ]) => faces.add(
    _Face(vertices.map(global).toList(), color, image, uv)..part = _part,
  );

  void cuboid(
    double left,
    double right,
    double bottom,
    double top,
    double rear,
    double fore,
    Color color, {
    ui.Image? frontArt,
    ui.Image? backArt,
    ui.Image? edgeArt,
    bool hinge = false,
  }) {
    _V p(double x, double y, double z) {
      var v = _V(x, y, z * profile.depthScale);

      if (hinge) {
        v = v
            .shift(.8, 0, -.065 * profile.depthScale)
            .turn(0, -open * 2.5)
            .shift(-.8, 0, .065 * profile.depthScale);
      }
      return v;
    }

    face(
      [
        p(left, top, fore),
        p(right, top, fore),
        p(right, bottom, fore),
        p(left, bottom, fore),
      ],
      color,
      frontArt,
    );
    face(
      [
        p(right, top, rear),
        p(left, top, rear),
        p(left, bottom, rear),
        p(right, bottom, rear),
      ],
      color,
      backArt,
    );
    face(
      [
        p(left, top, rear),
        p(left, top, fore),
        p(left, bottom, fore),
        p(left, bottom, rear),
      ],
      color,
      edgeArt,
    );
    face([
      p(right, top, fore),
      p(right, top, rear),
      p(right, bottom, rear),
      p(right, bottom, fore),
    ], color);
    face([
      p(left, top, rear),
      p(right, top, rear),
      p(right, top, fore),
      p(left, top, fore),
    ], color);
    face([
      p(left, bottom, fore),
      p(right, bottom, fore),
      p(right, bottom, rear),
      p(left, bottom, rear),
    ], color);
  }

  void barrel(
    double x,
    double bottom,
    double top,
    double z,
    double radius,
    Color color,
  ) {
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8, b = (i + 1) * math.pi / 8;
      face([
        _V(
          x + math.cos(a) * radius,
          top,
          (z + math.sin(a) * radius) * profile.depthScale,
        ),
        _V(
          x + math.cos(b) * radius,
          top,
          (z + math.sin(b) * radius) * profile.depthScale,
        ),
        _V(
          x + math.cos(b) * radius,
          bottom,
          (z + math.sin(b) * radius) * profile.depthScale,
        ),
        _V(
          x + math.cos(a) * radius,
          bottom,
          (z + math.sin(a) * radius) * profile.depthScale,
        ),
      ], color);
    }
  }

  List<Offset> roundedOutline(
    double left,
    double right,
    double bottom,
    double top,
    double radius,
  ) {
    final r = math.min(
      radius,
      math.min((right - left) / 2, (top - bottom) / 2),
    );
    final points = <Offset>[];
    final corners = [
      (right - r, top - r, math.pi / 2),
      (right - r, bottom + r, 0.0),
      (left + r, bottom + r, -math.pi / 2),
      (left + r, top - r, -math.pi),
    ];
    for (final (x, y, start) in corners) {
      for (var i = 0; i <= 8; i++) {
        final a = start - i * math.pi / 16;
        points.add(Offset(x + math.cos(a) * r, y + math.sin(a) * r));
      }
    }
    return points;
  }

  /// Actual extruded curved perimeter and rounded bevel rings, not a 2D mask.
  void roundedBox(
    double left,
    double right,
    double bottom,
    double top,
    double rear,
    double fore,
    Color color, {
    ui.Image? frontArt,
    ui.Image? backArt,
    bool hinge = false,
    double? radius,
  }) {
    final r = radius ?? profile.corner;
    final bevel = math.min(.009, (fore - rear) * .2);
    _V p(Offset v, double z) {
      var point = _V(v.dx, v.dy, z * profile.depthScale);
      if (hinge) {
        point = point
            .shift(.8, 0, -.065 * profile.depthScale)
            .turn(0, -open * 2.5)
            .shift(-.8, 0, .065 * profile.depthScale);
      }
      return point;
    }

    final outer = roundedOutline(left, right, bottom, top, r);
    final inset = roundedOutline(
      left + bevel,
      right - bevel,
      bottom + bevel,
      top - bevel,
      math.max(.003, r - bevel),
    );
    final rings = [inset, outer, outer, inset];
    final zs = [rear, rear + bevel, fore - bevel, fore];
    for (var band = 0; band < 3; band++) {
      for (var i = 0; i < outer.length; i++) {
        final j = (i + 1) % outer.length;
        face([
          p(rings[band][i], zs[band]),
          p(rings[band][j], zs[band]),
          p(rings[band + 1][j], zs[band + 1]),
          p(rings[band + 1][i], zs[band + 1]),
        ], band == 1 ? color : Color.lerp(color, Colors.white, .12)!);
        faces.last.edgeStroke = false;
      }
    }
    void cap(bool frontCap, ui.Image? image) {
      final z = frontCap ? fore : rear;
      // A subdivided plane keeps printed lines straight in perspective.
      final corners = frontCap
          ? [
              Offset(left, top),
              Offset(right, top),
              Offset(right, bottom),
              Offset(left, bottom),
            ]
          : [
              Offset(right, top),
              Offset(left, top),
              Offset(left, bottom),
              Offset(right, bottom),
            ];
      faces.add(
        _Face(corners.map((v) => global(p(v, z))).toList(), color, image)
          ..part = _part
          ..edgeStroke = false
          ..clipOutline = inset.map((v) => global(p(v, z))).toList(),
      );
    }

    cap(true, frontArt);
    cap(false, backArt);
  }

  void roundedRim(double h, Color shell) {
    final lip = profile.jewel ? .015 : .045;
    final margin = profile.jewel ? .005 : .02;
    final outer = roundedOutline(
      -.79,
      .79,
      -h + margin,
      h - margin,
      profile.corner,
    );
    final inner = roundedOutline(
      -.79 + lip,
      .79 - lip,
      -h + margin + lip,
      h - margin - lip,
      math.max(.008, profile.corner - .025),
    );
    for (var i = 0; i < outer.length; i++) {
      final j = (i + 1) % outer.length;
      _V p(Offset v) => _V(v.dx, v.dy, .042 * profile.depthScale);
      face([p(outer[i]), p(outer[j]), p(inner[j]), p(inner[i])], shell);
      _V at(Offset v, double z) => _V(v.dx, v.dy, z * profile.depthScale);
      face([
        at(outer[j], -.068),
        at(outer[i], -.068),
        at(outer[i], .064),
        at(outer[j], .064),
      ], shell);
      faces.last.edgeStroke = false;
      face([
        at(inner[i], -.068),
        at(inner[j], -.068),
        at(inner[j], .064),
        at(inner[i], .064),
      ], Color.lerp(shell, Colors.black, .25)!);
      faces.last.edgeStroke = false;
    }
  }

  void printedSpine(double h) {
    final x = -.814;
    final y = h - math.max(.025, profile.corner);
    face(
      [
        _V(x, y, -.154 * profile.depthScale),
        _V(x, y, .114 * profile.depthScale),
        _V(x, -y, .114 * profile.depthScale),
        _V(x, -y, -.154 * profile.depthScale),
      ],
      Colors.white,
      spine,
    );
    faces.last.part = 'spine';
  }

  /// Articulates the supplied GLB; continuous local print surfaces avoid UV seams.
  void importedCase() {
    final ds = profile.depthScale, h = profile.halfHeight;
    final bounds = mesh!.bounds;
    final sourceDepth = bounds.halfX;
    final sourceHeight = bounds.halfY;
    final centerZ = bounds.centerZ;
    _V hinge(_V p) => p
        .shift(.81, 0, .015 * ds)
        .turn(0, -open * 2.5)
        .shift(-.81, 0, -.015 * ds);
    _V medium(_V p) => p
        .turn(discX, discY)
        .shift(removal * 1.05, removal * .08, removal * .95);
    final baseDepth = global(_V(0, 0, -.10 * ds)).z;
    final lidDepth = global(hinge(_V(0, 0, .08 * ds))).z;
    final mediaDepth = global(medium(_V(0, 0, -.07 * ds))).z;
    void group(double depth, [double layer = 0]) {
      faces.last.groupedDepth =
          depth + layer * .00001 + faces.last.surfaceDepth * .0000001;
      faces.last.edgeStroke = false;
    }

    // A complete surface behind each open half also finishes non-double-sided meshes.
    void panel({
      required bool lid,
      required bool rear,
      required double z,
      required Color color,
      ui.Image? image,
      double layer = 10,
    }) {
      _part = lid ? 'lid' : 'case';
      const left = -.762, right = .762;
      final bottom = -h + .055, top = h - .055;
      _V p(Offset v) {
        final point = _V(v.dx, v.dy, z * ds);
        return lid ? hinge(point) : point;
      }

      final outline = roundedOutline(left, right, bottom, top, .075);
      final corners = rear
          ? [
              Offset(right, top),
              Offset(left, top),
              Offset(left, bottom),
              Offset(right, bottom),
            ]
          : [
              Offset(left, top),
              Offset(right, top),
              Offset(right, bottom),
              Offset(left, bottom),
            ];
      face(corners.map(p).toList(), color, image);
      faces.last.clipOutline = outline.map((v) => global(p(v))).toList();
      group(lid ? lidDepth : baseDepth, layer);
    }

    for (final part in mesh!.parts) {
      final lid = part.name == 'Cubo.001';
      final discPart = part.name == 'Círculo';
      final hub = part.name == 'Círculo.001';
      if (open <= .001 && removal <= .001 && (discPart || hub)) continue;
      _part = lid
          ? 'lid'
          : discPart
          ? 'media'
          : 'case';
      final partBounds = part.bounds;
      final hole = discPart ? part.innerRadiusYZ / partBounds.radiusYZ : .125;
      Offset discXY(MeshPoint p) {
        var x = (p.z - partBounds.centerZ) / partBounds.radiusYZ;
        var y = (p.y - partBounds.centerY) / partBounds.radiusYZ;
        final radius = math.sqrt(x * x + y * y);
        final adjusted = (.125 + (radius - hole) * .875 / (1 - hole)).clamp(
          .125,
          1.0,
        );
        if (radius > .00001) {
          x *= adjusted / radius;
          y *= adjusted / radius;
        }
        return Offset(x, y);
      }

      _V mapped(MeshPoint p) {
        if (discPart) {
          final xy = discXY(p);
          return medium(
            _V(
              xy.dx * profile.discRadius,
              xy.dy * profile.discRadius,
              (-(p.x - partBounds.centerX) / partBounds.halfX * .010 - .080) *
                  ds,
            ),
          );
        }
        if (hub) {
          return _V(
            (p.z - partBounds.centerZ) / partBounds.radiusYZ * .106,
            (p.y - partBounds.centerY) / partBounds.radiusYZ * .106,
            (-.128 + (partBounds.maxX - p.x) / (partBounds.halfX * 2) * .070) *
                ds,
          );
        }
        final point = _V(
          (p.z - centerZ) / bounds.halfZ * .81,
          (p.y - bounds.centerY) / sourceHeight * h,
          (-(p.x - bounds.centerX) / sourceDepth * .145 - .015) * ds,
        );
        return lid ? hinge(point) : point;
      }

      final depth = lid
          ? lidDepth
          : discPart
          ? mediaDepth
          : hub
          ? global(_V(0, 0, -.05 * ds)).z
          : baseDepth;
      final labelPoints = <_V>[], labelUv = <Offset>[];
      for (var i = 0; i < part.indices.length; i += 3) {
        final raw = [
          for (var k = 0; k < 3; k++) part.positions[part.indices[i + k]],
        ];
        final points = raw.map(mapped).toList();
        final color = discPart
            ? const Color(0xffc8d7e3)
            : hub
            ? Color.lerp(profile.shell, Colors.black, .32)!
            : profile.shell;
        face([points[2], points[1], points[0], points[0]], color);
        // Respect the outward normals of the closed solid GLB shells.
        group(depth);
        if (discPart && disc != null) {
          final a = raw[0], b = raw[1], c = raw[2];
          final nx = (b.y - a.y) * (c.z - a.z) - (b.z - a.z) * (c.y - a.y);
          if (nx < -.000001 &&
              raw.every((v) => (v.x - raw.first.x).abs() < .00001)) {
            for (final index in [2, 1, 0, 0]) {
              labelPoints.add(global(points[index]));
              final xy = discXY(raw[index]);
              labelUv.add(Offset((xy.dx + 1) / 2, (1 - xy.dy) / 2));
            }
          }
        }
      }
      if (labelPoints.isNotEmpty) {
        faces.add(
          _Face(labelPoints, Colors.white, disc, labelUv)
            ..part = 'media'
            ..cullMesh = true,
        );
        group(depth, 2);
      }
    }
    if (open > .001) {
      panel(
        lid: false,
        rear: false,
        z: -.125,
        color: Color.lerp(profile.shell, Colors.black, .5)!,
      );
      panel(
        lid: true,
        rear: true,
        z: .11,
        color: const Color(0xffd9d4c5),
        image: booklet,
      );
    }
    panel(lid: true, rear: false, z: .132, color: profile.shell, image: front);
    panel(lid: false, rear: true, z: -.162, color: profile.shell, image: back);
    _part = 'case';
    cuboid(-.814, -.790, -h + .04, h - .04, -.159, .002, profile.shell);
    printedSpine(h);
    if (open > .02) {
      for (final y in [-h + .12, h - .25]) {
        barrel(-.8, y, y + .13, -.015, .017, profile.shell);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    faces.clear();
    regions.clear();
    _part = 'case';
    final h = profile.halfHeight;
    final shell = profile.shell;
    if (mesh != null) {
      importedCase();
    } else {
      roundedBox(-.81, .81, -h, h, -.16, -.065, shell);
      cuboid(-.812, -.766, -h + .025, h - .025, -.159, .064, shell);
      printedSpine(h);
      roundedBox(
        -.755,
        .755,
        -h + .045,
        h - .045,
        -.166,
        -.162,
        shell,
        backArt: back,
      );
      final tray = platform == 'PS1'
          ? const Color(0xff343a40)
          : Color.lerp(shell, Colors.black, .62)!;
      roundedBox(
        -.755,
        .755,
        -h + .06,
        h - .06,
        -.064,
        -.036,
        tray,
        radius: profile.corner * .6,
      );
      roundedRim(h, shell);
      if (profile.jewel) {
        cuboid(
          -.78,
          -.61,
          -h + .04,
          h - .04,
          -.062,
          .035,
          const Color(0xff202328),
        );
      }
      if (profile.jewel) {
        for (final y in [-h + .06, h - .13]) {
          barrel(
            -.794,
            y,
            y + .07,
            -.005,
            .014,
            Color.lerp(shell, Colors.white, .12)!,
          );
        }
      }
      for (var i = 0; i < 4; i++) {
        final y = -.18 + i * .09;
        cuboid(
          .778,
          .803,
          y,
          y + .025,
          -.02,
          .055,
          Color.lerp(shell, Colors.white, .2)!,
        );
      }

      final firstMolding = faces.length;
      for (var i = 0; i < 64; i++) {
        final a = i * math.pi / 32, b = (i + 1) * math.pi / 32;
        face([
          _V(
            math.cos(a) * (profile.discRadius + .008),
            math.sin(a) * (profile.discRadius + .008),
            -.022 * profile.depthScale,
          ),
          _V(
            math.cos(b) * (profile.discRadius + .008),
            math.sin(b) * (profile.discRadius + .008),
            -.022 * profile.depthScale,
          ),
          _V(
            math.cos(b) * (profile.discRadius + .020),
            math.sin(b) * (profile.discRadius + .020),
            -.022 * profile.depthScale,
          ),
          _V(
            math.cos(a) * (profile.discRadius + .020),
            math.sin(a) * (profile.discRadius + .020),
            -.022 * profile.depthScale,
          ),
        ], Color.lerp(tray, Colors.white, i % 8 == 0 ? .25 : .08)!);
      }
      for (final f in faces.skip(firstMolding)) {
        f.groupedDepth =
            global(_V(0, 0, -.022 * profile.depthScale)).z +
            f.surfaceDepth * .001;
      }
      _part = 'media';
      final hub = <_V>[];
      for (var i = 0; i < 24; i++) {
        final a = i * math.pi / 12, b = (i + 1) * math.pi / 12;
        final radius = i.isEven ? .068 : .058;
        hub.addAll([
          _V(
            math.cos(a) * radius,
            math.sin(a) * radius,
            .039 * profile.depthScale,
          ),
          _V(
            math.cos(b) * radius,
            math.sin(b) * radius,
            .039 * profile.depthScale,
          ),
          _V(0, 0, .039 * profile.depthScale),
          _V(0, 0, .039 * profile.depthScale),
        ]);
      }
      face(hub, Color.lerp(tray, Colors.white, .32)!);
      _part = 'case';

      _part = 'media';

      // Disc has a true center hole, independent front/reverse and independent rotation.
      _V point(double angle, double radius, double z) =>
          _V(
                math.cos(angle) * radius,
                math.sin(angle) * radius,
                z * profile.depthScale,
              )
              .turn(discX, discY)
              .shift(
                removal * 1.05,
                0,
                .01 * profile.depthScale + removal * .95,
              );
      Offset uv(double a, double r) => Offset(
        .5 + math.cos(a) * r / (profile.discRadius * 2),
        .5 - math.sin(a) * r / (profile.discRadius * 2),
      );
      for (var side = 0; side < 2; side++) {
        final points = <_V>[];
        final textureCoords = <Offset>[];
        for (var i = 0; i < 64; i++) {
          final a = i * math.pi / 32, b = (i + 1) * math.pi / 32;
          final z = side == 0 ? .012 : -.012;
          points.addAll([
            point(a, profile.discRadius, z),
            point(b, profile.discRadius, z),
            point(b, .085, z),
            point(a, .085, z),
          ]);
          textureCoords.addAll([
            uv(a, profile.discRadius),
            uv(b, profile.discRadius),
            uv(b, .085),
            uv(a, .085),
          ]);
        }
        // The disc is one coplanar surface. Sorting wedges individually against the
        // whole lid incorrectly lets parts of the disc draw over a closed case.
        face(
          points,
          side == 0 ? const Color(0xffb7cadd) : const Color(0xffd8e4eb),
          side == 0 ? disc : null,
          textureCoords,
        );
      }

      _part = 'lid';
      roundedBox(-.8, .8, -h, h, .065, .12, shell, hinge: true);
      roundedBox(
        profile.paperLeft,
        .752,
        -h + .055,
        h - .055,
        .121,
        .124,
        shell,
        frontArt: front,
        hinge: true,
        radius: math.max(.009, profile.corner - .02),
      );
      if (open > .08) {
        // The booklet lives under retaining clips on the inside of the opening lid.
        cuboid(
          -.725,
          .725,
          -h + .13,
          h - .13,
          .045,
          .063,
          const Color(0xffd5d0bd),
          backArt: booklet,
          hinge: true,
        );
        for (final y in [-h + .30, h - .38]) {
          cuboid(-.77, -.65, y, y + .075, .025, .064, shell, hinge: true);
        }
      }
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    final scale =
        math.min(size.width / (2.7 + open * 1.8), size.height / 3.15) * zoom;
    Offset project(_V v) {
      final perspective = 5 / (5 - v.z).clamp(1.5, 8);
      return Offset(
        size.width / 2 +
            (v.x + open * .48 - removal * .16) * scale * perspective,
        size.height / 2 - v.y * scale * perspective,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .79),
        width: size.width * (.45 + open * .25),
        height: 18,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    for (final f in faces) {
      if (f.backFacing) continue;
      if (f.points.length > 4) {
        final positions = <Offset>[], coords = <Offset>[];
        for (var i = 0; i < f.points.length; i += 4) {
          final ps = f.points.sublist(i, i + 4).map(project).toList();
          final region = Path()..addPolygon(ps, true);
          regions.add((path: region, part: f.part));
          canvas.drawPath(
            region,
            Paint()
              ..color =
                  f.part == 'media' && f.image == null && f.points.length >= 256
                  ? Color.lerp(
                      f.color,
                      [
                        const Color(0xffb8cbdc),
                        const Color(0xffe3c7df),
                        const Color(0xffc4e4da),
                        const Color(0xfff1e5bd),
                      ][(i ~/ 20) % 4],
                      .4,
                    )!
                  : f.litColor,
          );
          if (f.image != null) {
            for (final index in [0, 1, 2, 0, 2, 3]) {
              positions.add(ps[index]);
              final uv = f.uv![i + index];
              coords.add(
                Offset(uv.dx * f.image!.width, uv.dy * f.image!.height),
              );
            }
          }
        }
        if (f.image != null) {
          final vertices = ui.Vertices(
            ui.VertexMode.triangles,
            positions,
            textureCoordinates: coords,
          );
          canvas.drawVertices(
            vertices,
            BlendMode.srcOver,
            Paint()
              ..shader = ImageShader(
                f.image!,
                TileMode.clamp,
                TileMode.clamp,
                Float64List.fromList([
                  1,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  1,
                ]),
              )
              ..filterQuality = FilterQuality.medium,
          );
          vertices.dispose();
        }
        continue;
      }
      final offsets = f.points.map(project).toList();
      final path = Path()
        ..addPolygon(f.clipOutline?.map(project).toList() ?? offsets, true);
      regions.add((path: path, part: f.part));
      canvas.drawPath(path, Paint()..color = f.litColor);
      final image = f.image;
      if (image != null) {
        canvas.save();
        canvas.clipPath(path, doAntiAlias: true);
        final customUv = f.uv;
        // Subdivision makes perspective accurate without a WebView or external engine.
        final steps = f.uv == null ? 8 : 1;
        final positions = <Offset>[], coords = <Offset>[];
        for (var yy = 0; yy < steps; yy++) {
          for (var xx = 0; xx < steps; xx++) {
            for (final d in [
              [0, 0],
              [1, 0],
              [1, 1],
              [0, 0],
              [1, 1],
              [0, 1],
            ]) {
              final u = (xx + d[0]) / steps, v = (yy + d[1]) / steps;
              double mix(double a, double b, double c, double d) =>
                  a * (1 - u) * (1 - v) +
                  b * u * (1 - v) +
                  c * u * v +
                  d * (1 - u) * v;
              final ps = f.points;
              positions.add(
                project(
                  _V(
                    mix(ps[0].x, ps[1].x, ps[2].x, ps[3].x),
                    mix(ps[0].y, ps[1].y, ps[2].y, ps[3].y),
                    mix(ps[0].z, ps[1].z, ps[2].z, ps[3].z),
                  ),
                ),
              );
              final tex =
                  customUv ??
                  const [
                    Offset(0, 0),
                    Offset(1, 0),
                    Offset(1, 1),
                    Offset(0, 1),
                  ];
              coords.add(
                Offset(
                  mix(tex[0].dx, tex[1].dx, tex[2].dx, tex[3].dx) * image.width,
                  mix(tex[0].dy, tex[1].dy, tex[2].dy, tex[3].dy) *
                      image.height,
                ),
              );
            }
          }
        }
        final vertices = ui.Vertices(
          ui.VertexMode.triangles,
          positions,
          textureCoordinates: coords,
        );
        canvas.drawVertices(
          vertices,
          BlendMode.srcOver,
          Paint()
            ..shader = ImageShader(
              image,
              TileMode.clamp,
              TileMode.clamp,
              Float64List.fromList([
                1,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                1,
              ]),
            )
            ..filterQuality = FilterQuality.medium,
        );
        vertices.dispose();
        canvas.restore();
      }
      if (f.image != null && f.part != 'media') {
        canvas.drawPath(
          path,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x16ffffff), Color(0x00ffffff), Color(0x15000000)],
              stops: [0, .4, 1],
            ).createShader(path.getBounds()),
        );
      }
      if (f.uv == null && f.edgeStroke) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: .10)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) => true;
}
