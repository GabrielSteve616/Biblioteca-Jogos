import 'dart:io';
import 'dart:typed_data';
import 'package:acervo/models/case_mesh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = File('modelos/case.glb').readAsBytesSync();
  test(
    'Actual GLB preserves four independent parts and all 1236 triangles',
    () {
      final model = CaseMesh.parse(ByteData.sublistView(bytes));
      expect(model.parts.map((p) => p.name), [
        'Cubo',
        'Cubo.001',
        'Círculo',
        'Círculo.001',
      ]);
      expect(
        model.parts.fold<int>(0, (n, p) => n + p.indices.length ~/ 3),
        1236,
      );
      for (final part in model.parts) {
        expect(
          part.indices.every((i) => i >= 0 && i < part.positions.length),
          isTrue,
        );
      }
    },
  );
  test('Node transforms retain the exported dimensions and disc placement', () {
    final model = CaseMesh.parse(ByteData.sublistView(bytes));
    final parts = model.parts;
    expect(model.bounds.halfZ, closeTo(1.009273737668991, .000001));
    expect(model.bounds.centerZ, closeTo(.9701692163944244, .000001));
    double min(Iterable<double> values) =>
        values.reduce((a, b) => a < b ? a : b);
    double max(Iterable<double> values) =>
        values.reduce((a, b) => a > b ? a : b);
    expect(min(parts[0].positions.map((p) => p.x)), closeTo(0, .000001));
    expect(
      max(parts[0].positions.map((p) => p.x)),
      closeTo(.10486531257629395 * 1.1427481174468994, .000001),
    );
    expect(
      min(parts[1].positions.map((p) => p.x)),
      closeTo(-.10486531257629395 * 1.142748475074768, .000001),
    );
    expect(
      max(parts[0].positions.map((p) => p.y)),
      closeTo(1.405617356300354 * 1.0142595767974854, .000001),
    );
    expect(
      max(parts[2].positions.map((p) => p.z)),
      closeTo(.9361230134963989 + .7954827547073364, .000001),
    );
    expect(
      min(parts[2].positions.map((p) => p.y)),
      closeTo(-.7954827547073364, .000001),
    );
  });
  test(
    'GLB decoding respects a ByteData view with a nonzero buffer offset',
    () {
      final wrapped = Uint8List(bytes.length + 32)
        ..setRange(16, 16 + bytes.length, bytes);
      final model = CaseMesh.parse(
        ByteData.sublistView(wrapped, 16, 16 + bytes.length),
      );
      expect(model.parts[2].indices.length, 1920);
    },
  );
  test('Truncated containers and unsupported GLB versions are rejected', () {
    expect(
      () => CaseMesh.parse(ByteData.sublistView(bytes, 0, bytes.length - 4)),
      throwsFormatException,
    );
    final changed = Uint8List.fromList(bytes);
    ByteData.sublistView(changed).setUint32(4, 1, Endian.little);
    expect(
      () => CaseMesh.parse(ByteData.sublistView(changed)),
      throwsFormatException,
    );
  });
}
