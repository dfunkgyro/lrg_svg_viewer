import 'dart:isolate';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';
import '../models/svg_models.dart';

class IsolateManager {
  Isolate? _isolate;
  SendPort? _isolateSendPort;
  bool _isIsolateReady = false;

  void initialize(SendPort sendPort) {
    _startIsolate(sendPort);
  }

  void _startIsolate(SendPort sendPort) async {
    try {
      _isolate = await Isolate.spawn(
        _isolateEntry,
        sendPort,
        debugName: 'SVGParserIsolate',
      );
    } catch (e) {
      print('Failed to start isolate: $e');
      _isIsolateReady = false;
    }
  }

  void handleIsolateMessage(SendPort sendPort) {
    _isolateSendPort = sendPort;
    _isIsolateReady = true;
    print('Isolate ready for communication');
  }

  Future<void> uploadSvg(BuildContext context) async {
    try {
      final model = Provider.of<SvgModel>(context, listen: false);

      // Show file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svg'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      if (file.path == null) {
        _showErrorSnackbar(context, 'No file selected or file path is null');
        return;
      }

      final path = file.path!;
      print('Selected file: $path');

      // Start parsing in UI
      model.startParsing(path);

      // Check if isolate is ready
      if (!_isIsolateReady || _isolateSendPort == null) {
        _showErrorSnackbar(context, 'Parser not ready. Please try again.');
        model.parsingComplete();
        return;
      }

      // Send file to isolate for parsing
      _isolateSendPort!.send(['start', path]);
    } catch (e, st) {
      print('Upload error: $e\n$st');
      final model = Provider.of<SvgModel>(context, listen: false);
      model.parsingComplete();
      _showErrorSnackbar(context, 'Failed to upload file: $e');
    }
  }

  void processMessage(BuildContext context, dynamic message) {
    if (message is SendPort) {
      handleIsolateMessage(message);
      return;
    }

    final model = Provider.of<SvgModel>(context, listen: false);

    if (message is List && message.isNotEmpty) {
      final type = message[0] as String;

      switch (type) {
        case 'metadata':
          if (message.length >= 3) {
            model.updateSvgMetadata(
              (message[1] as num).toDouble(),
              (message[2] as num).toDouble(),
            );
          }
          break;
        case 'elements':
          if (message.length >= 2 && message[1] is List) {
            final elementsData = message[1] as List;
            final elements = elementsData
                .map(
                    (m) => SvgElementData.fromMap(Map<String, dynamic>.from(m)))
                .toList();
            model.addElements(elements);
          }
          break;
        case 'complete':
          model.parsingComplete();
          break;
        case 'error':
          if (message.length >= 2) {
            final error = message[1] as String;
            _showErrorSnackbar(context, error);
            model.parsingComplete();
          }
          break;
      }
    }
  }

  void _showErrorSnackbar(BuildContext context, String error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void dispose() {
    try {
      _isolate?.kill(priority: Isolate.immediate);
    } catch (_) {}
    _isolate = null;
    _isolateSendPort = null;
    _isIsolateReady = false;
  }

  static void _isolateEntry(SendPort sendPort) {
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

  static Future<void> _parseSvgFile(String path, SendPort sendPort) async {
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

      if (widthAttr != null) {
        width = _parseDimension(widthAttr);
      }

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

      // Calculate grid based on actual SVG dimensions
      const gridBoxSize = 50.0;
      final maxGridCols = (width / gridBoxSize).ceil();

      // Find graphical elements
      final elementsToParse = document.descendants
          .whereType<XmlElement>()
          .where((e) => [
                'rect',
                'circle',
                'ellipse',
                'line',
                'polygon',
                'polyline',
                'path',
                'text',
                'g'
              ].contains(e.name.local))
          .toList();

      final batch = <Map<String, dynamic>>[];
      int counter = 0;

      for (final el in elementsToParse) {
        final tag = el.name.local;
        final bbox = _calculateBoundingBox(el);

        if (bbox != null && !bbox.isEmpty && !bbox.isInfinite) {
          // Calculate grid ID based on ACTUAL SVG dimensions
          final gridX = (bbox.left / gridBoxSize).floor().clamp(0, maxGridCols - 1);
          final gridY = (bbox.top / gridBoxSize).floor();
          final gridId = (gridY * maxGridCols) + gridX + 1;

          // Extract color information
          final fillColor = el.getAttribute('fill');
          final strokeColor = el.getAttribute('stroke');

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
            'fill': fillColor,
            'stroke': strokeColor,
          });

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

  static Rect? _calculateBoundingBox(XmlElement el) {
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
          final fontSize =
              _parseDimension(el.getAttribute('font-size') ?? '12');
          final textContent = el.text;
          final estimatedWidth = textContent.length * fontSize * 0.6;
          return Rect.fromLTWH(x, y - fontSize, estimatedWidth, fontSize);

        case 'g':
          // For group elements, calculate bounding box of children
          return _calculateGroupBounds(el);

        default:
          return null;
      }
    } catch (e) {
      print('Error calculating bounds for ${el.name.local}: $e');
      return null;
    }
  }

  static Rect? _calculateGroupBounds(XmlElement el) {
    final childElements = el.descendants.whereType<XmlElement>().where((e) => [
      'rect',
      'circle',
      'ellipse',
      'line',
      'polygon',
      'polyline',
      'path',
      'text'
    ].contains(e.name.local));

    Rect? groupBounds;
    for (final child in childElements) {
      final childBounds = _calculateBoundingBox(child);
      if (childBounds != null) {
        groupBounds = groupBounds?.expandToInclude(childBounds) ?? childBounds;
      }
    }
    return groupBounds;
  }

  static Rect _computeBoundsFromPoints(List<Offset> points) {
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

  static Rect? _computePathBounds(String pathData) {
    try {
      if (pathData.isEmpty) return null;

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
      print('Path bounds calculation failed: $e');
      return null;
    }
  }

  static List<Offset> _parsePoints(String pointsAttr) {
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

  static double _parseDimension(String value) {
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
}
