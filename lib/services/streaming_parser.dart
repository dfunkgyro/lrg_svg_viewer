import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:xml/xml_events.dart';
import 'package:path_drawing/path_drawing.dart';
import 'dart:convert';

class StreamingSvgParser {
  static const double _gridBoxSize = 50.0;
  static const int _maxGridCols = 2000 ~/ 50;

  Future<void> parseSvgFile(String path, SendPort sendPort) async {
    try {
      final file = File(path);
      final stream = file.openRead();

      final events = await stream
          .transform(utf8.decoder)
          .transform(XmlEventDecoder())
          .toList();

      double width = 1000.0, height = 1000.0;
      final elements = <Map<String, dynamic>>[];
      int elementCount = 0;

      // First pass: find SVG dimensions using proper type checking
      for (final event in events) {
        if (event is XmlStartElementEvent) {
          final startEvent = event as XmlStartElementEvent;
          if (startEvent.name == 'svg') {
            final viewBox = _getAttribute(startEvent, 'viewBox');
            final svgWidth = _getAttribute(startEvent, 'width');
            final svgHeight = _getAttribute(startEvent, 'height');

            if (svgWidth != null) {
              width = _parseDimension(svgWidth);
            }
            if (svgHeight != null) {
              height = _parseDimension(svgHeight);
            }
            if (viewBox != null) {
              final parts = viewBox.split(RegExp(r'\s+'));
              if (parts.length == 4) {
                width = double.tryParse(parts[2]) ?? width;
                height = double.tryParse(parts[3]) ?? height;
              }
            }
            break;
          }
        }
      }

      sendPort.send({
        'type': 'metadata',
        'width': width,
        'height': height,
      });

      // Second pass: parse elements with proper type checking
      bool inSvgElement = false;
      Map<String, String> currentAttributes = {};

      for (final event in events) {
        if (event is XmlStartElementEvent) {
          final startEvent = event as XmlStartElementEvent;

          if (startEvent.name == 'svg') {
            inSvgElement = true;
            continue;
          }

          if (inSvgElement && _isGraphicElement(startEvent.name)) {
            // Extract attributes properly
            currentAttributes = {};
            for (final attribute in startEvent.attributes) {
              currentAttributes[attribute.name] = attribute.value;
            }

            final bbox =
                _calculateBoundingBox(startEvent.name, currentAttributes);
            if (bbox != null && !bbox.isEmpty && !bbox.isInfinite) {
              final gridX = (bbox.left / _gridBoxSize).floor();
              final gridY = (bbox.top / _gridBoxSize).floor();
              final gridId = (gridY * _maxGridCols) + gridX + 1;

              elements.add({
                'id': currentAttributes['id'] ?? 'elem_$elementCount',
                'tag': startEvent.name,
                'xml': _buildXmlSnippet(startEvent.name, currentAttributes),
                'x': bbox.left,
                'y': bbox.top,
                'w': bbox.width,
                'h': bbox.height,
                'gridId': gridId,
              });
              elementCount++;

              // Send batches periodically
              if (elements.length >= 100) {
                sendPort.send({
                  'type': 'elements',
                  'elements': List.from(elements),
                });
                elements.clear();
                await Future.delayed(const Duration(milliseconds: 1));
              }
            }
          }
        } else if (event is XmlEndElementEvent) {
          final endEvent = event as XmlEndElementEvent;
          if (endEvent.name == 'svg') {
            inSvgElement = false;
          }
        }
      }

      // Send remaining elements
      if (elements.isNotEmpty) {
        sendPort.send({
          'type': 'elements',
          'elements': elements,
        });
      }

      sendPort.send({
        'type': 'total_elements',
        'count': elementCount,
      });

      sendPort.send({'type': 'complete'});
    } catch (e, st) {
      sendPort.send({
        'type': 'error',
        'error': '$e\n$st',
      });
    }
  }

  // Helper method to get attributes from XmlStartElementEvent
  String? _getAttribute(XmlStartElementEvent event, String attributeName) {
    for (final attribute in event.attributes) {
      if (attribute.name == attributeName) {
        return attribute.value;
      }
    }
    return null;
  }

  bool _isGraphicElement(String tag) {
    return [
      'rect',
      'circle',
      'ellipse',
      'line',
      'polygon',
      'polyline',
      'path',
      'text',
      'g'
    ].contains(tag);
  }

  Rect? _calculateBoundingBox(String tag, Map<String, String> attributes) {
    try {
      switch (tag) {
        case 'rect':
          final x = _parseDimension(attributes['x'] ?? '0');
          final y = _parseDimension(attributes['y'] ?? '0');
          final w = _parseDimension(attributes['width'] ?? '0');
          final h = _parseDimension(attributes['height'] ?? '0');
          return Rect.fromLTWH(x, y, w, h);

        case 'circle':
          final cx = _parseDimension(attributes['cx'] ?? '0');
          final cy = _parseDimension(attributes['cy'] ?? '0');
          final r = _parseDimension(attributes['r'] ?? '0');
          return Rect.fromLTWH(cx - r, cy - r, r * 2, r * 2);

        case 'ellipse':
          final cx = _parseDimension(attributes['cx'] ?? '0');
          final cy = _parseDimension(attributes['cy'] ?? '0');
          final rx = _parseDimension(attributes['rx'] ?? '0');
          final ry = _parseDimension(attributes['ry'] ?? '0');
          return Rect.fromLTWH(cx - rx, cy - ry, rx * 2, ry * 2);

        case 'line':
          final x1 = _parseDimension(attributes['x1'] ?? '0');
          final y1 = _parseDimension(attributes['y1'] ?? '0');
          final x2 = _parseDimension(attributes['x2'] ?? '0');
          final y2 = _parseDimension(attributes['y2'] ?? '0');
          final left = min(x1, x2);
          final top = min(y1, y2);
          final w = (x1 - x2).abs();
          final h = (y1 - y2).abs();
          return Rect.fromLTWH(left, top, w, h);

        case 'polygon':
        case 'polyline':
          final pointsAttr = attributes['points'] ?? '';
          final pts = _parsePoints(pointsAttr);
          if (pts.isEmpty) return null;
          return _computeBoundsFromPoints(pts);

        case 'path':
          final pathData = attributes['d'] ?? '';
          return _computePathBounds(pathData);

        case 'text':
          // Basic text bounding box - approximate based on font size
          final x = _parseDimension(attributes['x'] ?? '0');
          final y = _parseDimension(attributes['y'] ?? '0');
          final fontSize = _parseDimension(attributes['font-size'] ?? '12');
          // Approximate text width based on character count and font size
          final textLength = (attributes['text'] ?? '').length;
          final estimatedWidth = textLength * fontSize * 0.6;
          return Rect.fromLTWH(x, y - fontSize, estimatedWidth, fontSize);

        case 'g':
          // For group elements, return null as we don't calculate child bounds
          return null;

        default:
          return null;
      }
    } catch (e) {
      print('Error calculating bounds for $tag: $e');
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

      final path = parseSvgPathData(pathData);
      final bounds = path.getBounds();
      return Rect.fromLTRB(
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
      );
    } catch (e) {
      print('Error parsing path: $e');
      // Fallback: use the path bounds calculator
      return _computePathBoundsFallback(pathData);
    }
  }

  Rect? _computePathBoundsFallback(String pathData) {
    try {
      // Simple fallback that extracts coordinates from path data
      final regex = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
      final matches = regex.allMatches(pathData);
      final coords =
          matches.map((m) => double.tryParse(m.group(0)!) ?? 0.0).toList();

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
      print('Fallback path bounds calculation failed: $e');
      return null;
    }
  }

  List<Offset> _parsePoints(String pointsAttr) {
    final cleaned = pointsAttr.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return [];
    final parts =
        cleaned.split(RegExp(r'[ ,]')).where((s) => s.isNotEmpty).toList();
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
    // Remove units (px, em, etc.)
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
    }

    // Handle percentage values (rough approximation)
    if (value.endsWith('%')) {
      value = value.substring(0, value.length - 1);
      final percent = double.tryParse(value) ?? 0.0;
      return percent * 10.0; // Rough approximation
    }

    return double.tryParse(value) ?? 0.0;
  }

  String _buildXmlSnippet(String tag, Map<String, String> attributes) {
    final attrs = attributes.entries
        .map((e) => '${e.key}="${e.value.replaceAll('"', '&quot;')}"')
        .join(' ');
    return '<$tag $attrs/>';
  }
}
