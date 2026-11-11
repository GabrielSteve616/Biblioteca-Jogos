import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

class MeshPoint {
  const MeshPoint(this.x, this.y, this.z);
  final double x, y, z;
}

class CaseMeshPart {
  CaseMeshPart(this.name, this.positions, this.indices);
  final String name;
  final List<MeshPoint> positions;
  final List<int> indices;
  late final bounds = MeshBounds(positions);
  late final innerRadiusYZ = positions
      .map(
        (p) => math.sqrt(
          math.pow(p.y - bounds.centerY, 2) + math.pow(p.z - bounds.centerZ, 2),
        ),
      )
      .reduce(math.min);
}

class MeshBounds {
  MeshBounds(Iterable<MeshPoint> points)
    : minX = points.map((p) => p.x).reduce(math.min),
      maxX = points.map((p) => p.x).reduce(math.max),
      minY = points.map((p) => p.y).reduce(math.min),
      maxY = points.map((p) => p.y).reduce(math.max),
      minZ = points.map((p) => p.z).reduce(math.min),
      maxZ = points.map((p) => p.z).reduce(math.max) {
    if (![minX, minY, minZ, maxX, maxY, maxZ].every((v) => v.isFinite) ||
        halfX <= 0 ||
        halfY <= 0 ||
        halfZ <= 0) {
      throw const FormatException('Peça sem volume válido.');
    }
  }
  final double minX, minY, minZ, maxX, maxY, maxZ;
  double get centerX => (minX + maxX) / 2;
  double get centerY => (minY + maxY) / 2;
  double get centerZ => (minZ + maxZ) / 2;
  double get halfX => (maxX - minX) / 2;
  double get halfY => (maxY - minY) / 2;
  double get halfZ => (maxZ - minZ) / 2;
  double get radiusYZ => math.max(halfY, halfZ);
}

/// Local, uncompressed GLB 2.0 triangle geometry. No WebView or network loader.
/// Accessor offsets, byteStride, node hierarchy and TRS/matrices follow Khronos.
class CaseMesh {
  CaseMesh(this.parts);
  final List<CaseMeshPart> parts;
  late final bounds = MeshBounds(
    parts
        .where((p) => p.name == 'Cubo' || p.name == 'Cubo.001')
        .expand((p) => p.positions),
  );
  static Future<CaseMesh>? _cached;
  static bool supports(String platform) =>
      const ['Steam', 'PS2', 'PS3', 'PS4', 'Android'].contains(platform);
  static Future<CaseMesh> load() => _cached ??= rootBundle
      .load('modelos/case.glb')
      .then((data) => CaseMesh.parse(data));

  factory CaseMesh.parse(ByteData data) {
    Never invalid() =>
        throw const FormatException('Modelo GLB inválido ou não suportado.');
    if (data.lengthInBytes < 20 ||
        data.getUint32(0, Endian.little) != 0x46546c67 ||
        data.getUint32(4, Endian.little) != 2 ||
        data.getUint32(8, Endian.little) != data.lengthInBytes) {
      invalid();
    }
    Map<String, dynamic>? json;
    ByteData? binary;
    for (var offset = 12; offset < data.lengthInBytes;) {
      if (offset + 8 > data.lengthInBytes) invalid();
      final size = data.getUint32(offset, Endian.little);
      final type = data.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (size % 4 != 0 || offset + size > data.lengthInBytes) invalid();
      final bytes = data.buffer.asUint8List(data.offsetInBytes + offset, size);
      if (type == 0x4e4f534a) {
        json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
      if (type == 0x004e4942) binary = ByteData.sublistView(bytes);
      offset += size;
    }
    if (json == null ||
        binary == null ||
        (json['extensionsRequired'] as List? ?? []).isNotEmpty) {
      invalid();
    }
    final doc = json;
    final bin = binary;
    if ((doc['buffers'] as List).length != 1 ||
        doc['buffers'][0]['uri'] != null) {
      invalid();
    }
    List<List<double>> accessor(int index, String expected) {
      final a = doc['accessors'][index] as Map;
      if (a['type'] != expected ||
          a['sparse'] != null ||
          a['normalized'] == true) {
        invalid();
      }
      final view = doc['bufferViews'][a['bufferView']] as Map;
      if (view['buffer'] != 0) invalid();
      final component = a['componentType'];
      final bytes = switch (component) {
        5121 => 1,
        5123 => 2,
        5125 || 5126 => 4,
        _ => 0,
      };
      if (bytes == 0 || (expected != 'SCALAR' && component != 5126)) invalid();
      final count = a['count'] as int;
      final width = expected == 'VEC3' ? 3 : 1;
      final stride = (view['byteStride'] as int?) ?? width * bytes;
      final base = (view['byteOffset'] as int?) ?? 0;
      final start = (a['byteOffset'] as int?) ?? 0;
      if (count < 0 ||
          count > 100000 ||
          stride < width * bytes ||
          start < 0 ||
          base < 0 ||
          start + math.max(0, count - 1) * stride + width * bytes >
              view['byteLength'] ||
          base + view['byteLength'] > bin.lengthInBytes) {
        invalid();
      }
      return List.generate(
        count,
        (i) => List.generate(width, (c) {
          final offset = base + start + i * stride + c * bytes;
          final value = switch (component) {
            5126 => bin.getFloat32(offset, Endian.little),
            5125 => bin.getUint32(offset, Endian.little).toDouble(),
            5123 => bin.getUint16(offset, Endian.little).toDouble(),
            _ => bin.getUint8(offset).toDouble(),
          };
          if (!value.isFinite) invalid();
          return value;
        }),
      );
    }

    List<double> identity() => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
    List<double> multiply(List<double> a, List<double> b) =>
        List.generate(16, (i) {
          final row = i % 4, col = i ~/ 4;
          return List.generate(
            4,
            (k) => a[k * 4 + row] * b[col * 4 + k],
          ).reduce((a, b) => a + b);
        });
    List<double> numbers(Object? value, List<double> fallback) => value == null
        ? fallback
        : (value as List).map((e) => (e as num).toDouble()).toList();
    List<double> local(Map node) {
      if (node['matrix'] != null) return numbers(node['matrix'], identity());
      final t = numbers(node['translation'], [0, 0, 0]);
      final s = numbers(node['scale'], [1, 1, 1]);
      final q = numbers(node['rotation'], [0, 0, 0, 1]);
      final x = q[0], y = q[1], z = q[2], w = q[3];
      return [
        (1 - 2 * y * y - 2 * z * z) * s[0],
        (2 * x * y + 2 * z * w) * s[0],
        (2 * x * z - 2 * y * w) * s[0],
        0,
        (2 * x * y - 2 * z * w) * s[1],
        (1 - 2 * x * x - 2 * z * z) * s[1],
        (2 * y * z + 2 * x * w) * s[1],
        0,
        (2 * x * z + 2 * y * w) * s[2],
        (2 * y * z - 2 * x * w) * s[2],
        (1 - 2 * x * x - 2 * y * y) * s[2],
        0,
        t[0],
        t[1],
        t[2],
        1,
      ];
    }

    final parts = <CaseMeshPart>[];
    final visited = <int>{};
    void visit(int id, List<double> parent) {
      if (!visited.add(id)) invalid();
      final node = doc['nodes'][id] as Map;
      if (node['skin'] != null) invalid();
      final matrix = multiply(parent, local(node));
      if (node['mesh'] != null) {
        final mesh = doc['meshes'][node['mesh']] as Map;
        for (final primitive in mesh['primitives'] as List) {
          if ((primitive['mode'] ?? 4) != 4) invalid();
          final raw = accessor(
            primitive['attributes']['POSITION'] as int,
            'VEC3',
          );
          final positions = raw
              .map(
                (p) => MeshPoint(
                  matrix[0] * p[0] +
                      matrix[4] * p[1] +
                      matrix[8] * p[2] +
                      matrix[12],
                  matrix[1] * p[0] +
                      matrix[5] * p[1] +
                      matrix[9] * p[2] +
                      matrix[13],
                  matrix[2] * p[0] +
                      matrix[6] * p[1] +
                      matrix[10] * p[2] +
                      matrix[14],
                ),
              )
              .toList();
          final indices = primitive['indices'] == null
              ? List.generate(positions.length, (i) => i)
              : accessor(
                  primitive['indices'] as int,
                  'SCALAR',
                ).map((e) => e.single.toInt()).toList();
          if (indices.length % 3 != 0 ||
              indices.any((i) => i < 0 || i >= positions.length)) {
            invalid();
          }
          parts.add(
            CaseMeshPart(
              node['name'] as String? ?? mesh['name'] as String? ?? '',
              positions,
              indices,
            ),
          );
        }
      }
      for (final child in node['children'] as List? ?? []) {
        visit(child as int, matrix);
      }
    }

    for (final id in doc['scenes'][doc['scene'] ?? 0]['nodes'] as List) {
      visit(id as int, identity());
    }
    const required = ['Cubo', 'Cubo.001', 'Círculo', 'Círculo.001'];
    if (parts.length != 4 ||
        !required.every((name) => parts.any((p) => p.name == name))) {
      invalid();
    }
    return CaseMesh(List.unmodifiable(parts));
  }
}
