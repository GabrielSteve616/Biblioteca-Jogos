import 'package:flutter/material.dart';

/// Subtle, static cyberpunk foundations: clear contrast without flicker or motion.
abstract final class Cyber {
  static const background = Color(0xff080c15);
  static const panel = Color(0xff111b29);
  static const cyan = Color(0xff60e8ef);
  static const pink = Color(0xffed78ba);
  static const yellow = Color(0xffeed18b);
  static const muted = Color(0xff9caec3);
  static const border = Color(0xff29404f);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        onPrimary: Color(0xff082329),
        secondary: pink,
        onSecondary: Color(0xff2a1023),
        tertiary: yellow,
        surface: panel,
        onSurface: Color(0xffe5edf5),
        outline: border,
      ),
    );
    const shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(7)),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xffe5edf5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        prefixIconColor: cyan,
        labelStyle: const TextStyle(fontFamily: 'Roboto', color: muted),
        hintStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: muted,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cyan, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panel,
        selectedColor: const Color(0xff16434c),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        labelStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          side: const BorderSide(color: Color(0xff3b6674)),
          minimumSize: const Size(0, 46),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: cyan,
        foregroundColor: Color(0xff082329),
        shape: shape,
        elevation: 5,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border),
      iconTheme: const IconThemeData(color: cyan),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: cyan),
    );
  }
}

class CyberBackdrop extends StatelessWidget {
  const CyberBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const RepaintBoundary(child: CustomPaint(painter: _BackdropPainter())),
      child,
    ],
  );
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Cyber.background);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-1, -.85),
          radius: 1.1,
          colors: [Color(0xff102b37), Color(0x00080c15)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(1.2, .65),
          radius: .9,
          colors: [Color(0xff211425), Color(0x00080c15)],
        ).createShader(rect),
    );
    final grid = Paint()
      ..color = Cyber.cyan.withValues(alpha: .025)
      ..strokeWidth = .6;
    for (var x = 0.0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final trace = Paint()
      ..color = Cyber.cyan.withValues(alpha: .13)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 9, 130)
        ..lineTo(size.width - 9, 240)
        ..lineTo(size.width - 16, 247)
        ..lineTo(size.width - 16, 310),
      trace,
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}
