import 'dart:isolate';
import 'dart:io';
import 'dart:math';
import 'package:xml/xml.dart';
import 'package:flutter/material.dart';

const double _gridBoxSize = 50.0;
const int _maxGridCols = 2000 ~/ 50;

void parserIsolateEntry(SendPort sendPort) {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  port.listen((message) async {
    if (message is List && message.isNotEmpty) {
      final cmd = message[0] as String;
      if (cmd == 'start' && message.length > 1) {
        final path = message[1] as String;
        await _parseSvgFile(path, sendPort);
      }
    }
  });
}

Future<void> _parseSvgFile(String path, SendPort sendPort) async {
  try {
    final file = File(path);
    if (!await file.exists()) {
      sendPort.send(['error', 'File does not exist: $path']);
      return;
    }

    final content = await file.readAsString();
    if (content.isEmpty) {
      sendPort.send(['error', 'File is empty']);
      return;
    }

    final document = XmlDocument.parse(content);
    final svgElements = document.findAllElements('svg').toList();

    if (svgElements.isEmpty) {
      sendPort.send(['error', 'No SVG element found in file']);
      return;
    }

    final svgElement = svgElements.first;
    double width = 1000.0, height = 1000.0;

    // Parse dimensions
    final viewBoxAttr = svgElement.getAttribute('viewBox');
    final widthAttr = svgElement.getAttribute('width');
    final heightAttr = svgElement.getAttribute('height');

    // Parse width
    if (widthAttr != null) {
      width = _parseDimension(widthAttr);
    }

    // Parse height
    if (heightAttr != null) {
      height = _parseDimension(heightAttr);
    }

    // Use viewBox as fallback
    if (viewBoxAttr != null) {
      final parts = viewBoxAttr.split(RegExp(r'\s+'));
      if (parts.length == 4) {
        width = double.tryParse(parts[2]) ?? width;
        height = double.tryParse(parts[3]) ?? height;
      }
    }

    // Ensure valid dimensions
    if (width <= 0 || height <= 0) {
      width = 1000.0;
      height = 1000.0;
    }

    sendPort.send(['metadata', width, height]);

    // Find graphical elements
    final elementsToParse = document.descendants
        .whereType<XmlElement>()
        .where(
          (e) => [
            'rect',
            'circle',
            'ellipse',
            'line',
            'polygon',
            'polyline',
            'path',
            'text',
          ].contains(e.name.local),
        )
        .toList();

    final batch = <Map<String, dynamic>>[];
    int counter = 0;
    int totalCount = 0;

    for (final el in elementsToParse) {
      final tag = el.name.local;
      Rect? bbox = _calculateBoundingBox(el);

      if (bbox != null && !bbox.isEmpty && !bbox.isInfinite) {
        final gridX = (bbox.left / _gridBoxSize).floor();
        final gridY = (bbox.top / _gridBoxSize).floor();
        final gridId = (gridY * _maxGridCols) + gridX + 1;

        final xmlSnippet = el.toXmlString(pretty: false);
        batch.add({
          'id': el.getAttribute('id') ?? 'elem_${counter++}',
          'tag': tag,
          'xml': xmlSnippet,
          'x': bbox.left,
          'y': bbox.top,
          'w': bbox.width,
          'h': bbox.height,
          'gridId': gridId,
        });
        totalCount++;

        if (batch.length >= 50) {
          sendPort.send(['elements', batch.toList()]);
          batch.clear();
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    }

    if (batch.isNotEmpty) {
      sendPort.send(['elements', batch.toList()]);
    }

    sendPort.send(['complete']);
  } catch (e, st) {
    sendPort.send(['error', 'Parser error: $e\n$st']);
  }
}

Rect? _calculateBoundingBox(XmlElement el) {
  try {
    final tag = el.name.local;

    switch (tag) {
      case 'rect':
        final x = _parseDimension(el.getAttribute('x') ?? '0');
        final y = _parseDimension(el.getAttribute('y') ?? '0');
        final w = _parseDimension(el.getAttribute('width') ?? '0');
        final h = _parseDimension(el.getAttribute('height') ?? '0');
        return Rect.fromLTWH(x, y, w, h);

      case 'circle':
        final cx = _parseDimension(el.getAttribute('cx') ?? '0');
        final cy = _parseDimension(el.getAttribute('cy') ?? '0');
        final r = _parseDimension(el.getAttribute('r') ?? '0');
        return Rect.fromLTWH(cx - r, cy - r, r * 2, r * 2);

      case 'ellipse':
        final cx = _parseDimension(el.getAttribute('cx') ?? '0');
        final cy = _parseDimension(el.getAttribute('cy') ?? '0');
        final rx = _parseDimension(el.getAttribute('rx') ?? '0');
        final ry = _parseDimension(el.getAttribute('ry') ?? '0');
        return Rect.fromLTWH(cx - rx, cy - ry, rx * 2, ry * 2);

      case 'line':
        final x1 = _parseDimension(el.getAttribute('x1') ?? '0');
        final y1 = _parseDimension(el.getAttribute('y1') ?? '0');
        final x2 = _parseDimension(el.getAttribute('x2') ?? '0');
        final y2 = _parseDimension(el.getAttribute('y2') ?? '0');
        final left = min(x1, x2);
        final top = min(y1, y2);
        final w = (x1 - x2).abs();
        final h = (y1 - y2).abs();
        return Rect.fromLTWH(left, top, w, h);

      case 'polygon':
      case 'polyline':
        final pointsAttr = el.getAttribute('points') ?? '';
        final pts = _parsePoints(pointsAttr);
        if (pts.isEmpty) return null;
        return _computeBoundsFromPoints(pts);

      case 'path':
        final pathData = el.getAttribute('d') ?? '';
        return _computePathBounds(pathData);

      case 'text':
        final x = _parseDimension(el.getAttribute('x') ?? '0');
        final y = _parseDimension(el.getAttribute('y') ?? '0');
        final fontSize = _parseDimension(el.getAttribute('font-size') ?? '12');
        final textContent = el.text;
        final estimatedWidth = textContent.length * fontSize * 0.6;
        return Rect.fromLTWH(x, y - fontSize, estimatedWidth, fontSize);

      default:
        return null;
    }
  } catch (e) {
    print('Error calculating bounds for ${el.name.local}: $e');
    return null;
  }
}

Rect _computeBoundsFromPoints(List<Offset> points) {
  if (points.isEmpty) return Rect.zero;

  double minX = points.first.dx, maxX = points.first.dx;
  double minY = points.first.dy, maxY = points.first.dy;

  for (final point in points) {
    minX = min(minX, point.dx);
    maxX = max(maxX, point.dx);
    minY = min(minY, point.dy);
    maxY = max(maxY, point.dy);
  }

  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

Rect? _computePathBounds(String pathData) {
  try {
    if (pathData.isEmpty) return null;

    // Simple bounds calculation for path data
    final regex = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
    final matches = regex.allMatches(pathData);
    final coords = matches
        .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
        .toList();

    if (coords.isEmpty) return null;

    double minX = coords[0], maxX = coords[0];
    double minY = coords.length > 1 ? coords[1] : 0,
        maxY = coords.length > 1 ? coords[1] : 0;

    for (int i = 0; i < coords.length; i += 2) {
      if (i + 1 < coords.length) {
        minX = min(minX, coords[i]);
        maxX = max(maxX, coords[i]);
        minY = min(minY, coords[i + 1]);
        maxY = max(maxY, coords[i + 1]);
      }
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  } catch (e) {
    print('Path bounds calculation failed: $e');
    return null;
  }
}

List<Offset> _parsePoints(String pointsAttr) {
  final cleaned = pointsAttr.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return [];
  final parts = cleaned
      .split(RegExp(r'[ ,]'))
      .where((s) => s.isNotEmpty)
      .toList();
  final pts = <Offset>[];
  for (int i = 0; i + 1 < parts.length; i += 2) {
    final x = double.tryParse(parts[i]) ?? 0.0;
    final y = double.tryParse(parts[i + 1]) ?? 0.0;
    pts.add(Offset(x, y));
  }
  return pts;
}

double _parseDimension(String value) {
  value = value.trim();

  // Remove units
  if (value.endsWith('px')) {
    value = value.substring(0, value.length - 2);
  } else if (value.endsWith('pt')) {
    value = value.substring(0, value.length - 2);
  } else if (value.endsWith('em')) {
    value = value.substring(0, value.length - 2);
  } else if (value.endsWith('mm')) {
    value = value.substring(0, value.length - 2);
  } else if (value.endsWith('cm')) {
    value = value.substring(0, value.length - 2);
  } else if (value.endsWith('in')) {
    value = value.substring(0, value.length - 2);
  } else if (value.endsWith('%')) {
    value = value.substring(0, value.length - 1);
    final percent = double.tryParse(value) ?? 0.0;
    return percent * 10.0;
  }

  return double.tryParse(value) ?? 0.0;
}
