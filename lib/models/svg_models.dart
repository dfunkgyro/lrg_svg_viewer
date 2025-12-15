import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class SvgElementData {
  final String id;
  final String tagName;
  final String xmlSnippet;
  final Rect boundingBox;
  final int gridId;
  final String? fillColor;
  final String? strokeColor;

  SvgElementData({
    required this.id,
    required this.tagName,
    required this.xmlSnippet,
    required this.boundingBox,
    required this.gridId,
    this.fillColor,
    this.strokeColor,
  });

  factory SvgElementData.fromMap(Map<String, dynamic> m) {
    return SvgElementData(
      id: m['id'] as String? ?? 'unknown',
      tagName: m['tag'] as String? ?? '',
      xmlSnippet: m['xml'] as String? ?? '',
      boundingBox: Rect.fromLTWH(
        (m['x'] as num?)?.toDouble() ?? 0.0,
        (m['y'] as num?)?.toDouble() ?? 0.0,
        (m['w'] as num?)?.toDouble() ?? 0.0,
        (m['h'] as num?)?.toDouble() ?? 0.0,
      ),
      gridId: (m['gridId'] as num?)?.toInt() ?? 0,
      fillColor: m['fill'] as String?,
      strokeColor: m['stroke'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tag': tagName,
      'xml': xmlSnippet,
      'x': boundingBox.left,
      'y': boundingBox.top,
      'w': boundingBox.width,
      'h': boundingBox.height,
      'gridId': gridId,
      'fill': fillColor,
      'stroke': strokeColor,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SvgElementData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tagName == other.tagName;

  @override
  int get hashCode => id.hashCode ^ tagName.hashCode;
}

class GridInfo {
  final int id;
  final int x;
  final int y;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double centerX;
  final double centerY;

  GridInfo({
    required this.id,
    required this.x,
    required this.y,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.centerX,
    required this.centerY,
  });
}

class RecognizedTextHit {
  final String text;
  final String source; // e.g. 'text-node', 'ocr', 'polyline-heuristic'
  final double confidence;
  final Rect? bounds;

  RecognizedTextHit({
    required this.text,
    required this.source,
    required this.confidence,
    this.bounds,
  });
}

class GridRecognitionResult {
  final int gridId;
  final List<RecognizedTextHit> hits;
  final DateTime timestamp;

  GridRecognitionResult({
    required this.gridId,
    required this.hits,
    required this.timestamp,
  });

  bool get isEmpty => hits.isEmpty;
}

class SvgModel with ChangeNotifier {
  String? _filePath;
  final List<SvgElementData> _elements = [];
  final Set<SvgElementData> _selectedElements = {};
  bool _isParsing = false;

  double _svgWidth = 0;
  double _svgHeight = 0;
  double _gridBoxSize = 50.0;

  double _currentScale = 1.0;
  Offset _currentPanOffset = Offset.zero;
  bool _showGrid = false;
  SvgElementData? _selectedElement;
  int _totalElements = 0;
  int? _selectedGridId;
  int? _hoveredGridId;
  int? _pendingNavigateGridId;
  int _navigationRequestVersion = 0;
  bool _recognizeTextEnabled = false;
  final Map<int, GridRecognitionResult> _recognitionCache = {};
  final Set<int> _recognitionInFlight = {};
  final Map<String, String> _userGeometryLabels = {};

  // getters
  String? get filePath => _filePath;
  List<SvgElementData> get elements => List.unmodifiable(_elements);
  Set<SvgElementData> get selectedElements =>
      Set.unmodifiable(_selectedElements);
  bool get isParsing => _isParsing;
  double get svgWidth => _svgWidth;
  double get svgHeight => _svgHeight;
  double get gridBoxSize => _gridBoxSize;
  double get currentScale => _currentScale;
  Offset get currentPanOffset => _currentPanOffset;
  bool get showGrid => _showGrid;
  SvgElementData? get selectedElement => _selectedElement;
  int get totalElements => _totalElements;
  int? get selectedGridId => _selectedGridId;
  int? get hoveredGridId => _hoveredGridId;
  int? get pendingNavigateGridId => _pendingNavigateGridId;
  int get navigationRequestVersion => _navigationRequestVersion;
  bool get recognizeTextEnabled => _recognizeTextEnabled;
  Map<int, GridRecognitionResult> get recognitionCache =>
      Map.unmodifiable(_recognitionCache);
  bool isGridRecognitionInFlight(int gridId) =>
      _recognitionInFlight.contains(gridId);
  String? getUserGeometryLabel(SvgElementData element) {
    final sig = _geometrySignature(element);
    if (sig == null) return null;
    return _userGeometryLabels[sig];
  }

  /// Returns user-supplied labels present in the given grid (label -> count).
  Map<String, int> getGridUserLabelCounts(int gridId) {
    final counts = <String, int>{};
    for (final element in getElementsInGrid(gridId)) {
      final label = getUserGeometryLabel(element);
      if (label != null && label.isNotEmpty) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return counts;
  }

  int get maxGridCols => (svgWidth / _gridBoxSize).ceil();
  int get maxGridRows => (svgHeight / _gridBoxSize).ceil();
  int get totalGridCells => maxGridCols * maxGridRows;

  void startParsing(String path) {
    _filePath = path;
    _isParsing = true;
    _elements.clear();
    _selectedElements.clear();
    _svgWidth = 0;
    _svgHeight = 0;
    _currentScale = 1.0;
    _currentPanOffset = Offset.zero;
    _selectedElement = null;
    _totalElements = 0;
    _selectedGridId = null;
    _hoveredGridId = null;
    _pendingNavigateGridId = null;
    _navigationRequestVersion = 0;
    _recognizeTextEnabled = false;
    _recognitionCache.clear();
    _recognitionInFlight.clear();
    _userGeometryLabels.clear();
    notifyListeners();
  }

  void updateSvgMetadata(double width, double height) {
    _svgWidth = width;
    _svgHeight = height;
    notifyListeners();
  }

  void addElements(List<SvgElementData> newElements) {
    _elements.addAll(newElements);
    _totalElements = _elements.length;
    notifyListeners();
  }

  void updateTotalElements(int count) {
    _totalElements = count;
    notifyListeners();
  }

  void parsingComplete() {
    _isParsing = false;
    notifyListeners();
  }

  void toggleGrid(bool value) {
    _showGrid = value;
    notifyListeners();
  }

  void updateScaleAndOffset(double newScale, Offset newOffset) {
    _currentScale = newScale;
    _currentPanOffset = newOffset;
    notifyListeners();
  }

  void zoomStep(double factor, Offset center) {
    final newScale = (_currentScale * factor).clamp(0.01, 100.0);
    final dx = (center.dx - _currentPanOffset.dx) / _currentScale;
    final dy = (center.dy - _currentPanOffset.dy) / _currentScale;
    final newPanX = center.dx - dx * newScale;
    final newPanY = center.dy - dy * newScale;
    _currentScale = newScale;
    _currentPanOffset = Offset(newPanX, newPanY);
    notifyListeners();
  }

  void resetZoom(double calculatedInitialScale) {
    _currentScale = calculatedInitialScale;
    _currentPanOffset = Offset.zero;
    notifyListeners();
  }

  void selectElement(SvgElementData element) {
    _selectedElement = element;
    notifyListeners();
  }

  void zoomToSelected(
    Rect targetBox,
    double viewportWidth,
    double viewportHeight,
  ) {
    if (_svgWidth == 0 || _svgHeight == 0) return;
    const padding = 40.0;
    final scaleX = viewportWidth / (targetBox.width + padding);
    final scaleY = viewportHeight / (targetBox.height + padding);
    final newScale = min(scaleX, scaleY).clamp(0.01, 100.0);
    final targetCenterX = targetBox.left + targetBox.width / 2;
    final targetCenterY = targetBox.top + targetBox.height / 2;
    final newPanX = viewportWidth / 2 - targetCenterX * newScale;
    final newPanY = viewportHeight / 2 - targetCenterY * newScale;
    _currentScale = newScale;
    _currentPanOffset = Offset(newPanX, newPanY);
    notifyListeners();
  }

  void clearSelection() {
    _selectedElement = null;
    _selectedElements.clear();
    notifyListeners();
  }

  void setRecognizeTextEnabled(bool value) {
    if (_recognizeTextEnabled != value) {
      _recognizeTextEnabled = value;
      notifyListeners();
    }
  }

  void assignGeometryLabel(SvgElementData element, String label) {
    final sig = _geometrySignature(element);
    if (sig == null) return;
    _userGeometryLabels[sig] = label.trim();
    _recognitionCache.clear(); // force re-run on next open
    notifyListeners();
  }

  // Grid Navigation
  void navigateToGrid(int gridId, double viewportWidth, double viewportHeight) {
    final gridInfo = getGridInfo(gridId);

    // Calculate scale to show 3x3 grid cells
    final targetScale = min(
      viewportWidth / (_gridBoxSize * 3),
      viewportHeight / (_gridBoxSize * 3),
    ).clamp(0.1, 10.0);

    // Calculate offset to center the grid cell
    final targetOffset = Offset(
      (viewportWidth / 2) - (gridInfo.centerX * targetScale),
      (viewportHeight / 2) - (gridInfo.centerY * targetScale),
    );

    _currentScale = targetScale;
    _currentPanOffset = targetOffset;
    _selectedGridId = gridId;
    notifyListeners();
  }

  GridInfo getGridInfo(int gridId) {
    final gridX = (gridId - 1) % maxGridCols;
    final gridY = (gridId - 1) ~/ maxGridCols;

    final gridLeft = gridX * _gridBoxSize;
    final gridTop = gridY * _gridBoxSize;

    return GridInfo(
      id: gridId,
      x: gridX,
      y: gridY,
      left: gridLeft,
      top: gridTop,
      right: gridLeft + _gridBoxSize,
      bottom: gridTop + _gridBoxSize,
      centerX: gridLeft + (_gridBoxSize / 2),
      centerY: gridTop + (_gridBoxSize / 2),
    );
  }

  void setHoveredGrid(int? gridId) {
    if (_hoveredGridId != gridId) {
      _hoveredGridId = gridId;
      notifyListeners();
    }
  }

  void selectGridById(int gridId) {
    _selectedGridId = gridId;
    notifyListeners();
  }

  /// Request that the viewport navigate to the given grid. The viewport listens
  /// for this and performs the pan/zoom using its real dimensions.
  void requestNavigateToGrid(int gridId) {
    _pendingNavigateGridId = gridId;
    _navigationRequestVersion++;
    notifyListeners();
  }

  void clearNavigateRequest() {
    _pendingNavigateGridId = null;
  }

  // Selection Tools
  void selectAllOfType(String tagName) {
    _selectedElements.clear();
    _selectedElements.addAll(_elements.where((e) => e.tagName == tagName));
    notifyListeners();
  }

  void selectInViewport(double viewportWidth, double viewportHeight) {
    _selectedElements.clear();

    // Calculate visible area in SVG coordinates
    final visibleLeft = -_currentPanOffset.dx / _currentScale;
    final visibleTop = -_currentPanOffset.dy / _currentScale;
    final visibleRight = visibleLeft + (viewportWidth / _currentScale);
    final visibleBottom = visibleTop + (viewportHeight / _currentScale);

    final visibleRect = Rect.fromLTRB(
      visibleLeft,
      visibleTop,
      visibleRight,
      visibleBottom,
    );

    _selectedElements.addAll(
      _elements.where((e) => e.boundingBox.overlaps(visibleRect)),
    );
    notifyListeners();
  }

  void selectByColor(String? color) {
    if (color == null) return;
    _selectedElements.clear();
    _selectedElements.addAll(
      _elements.where((e) => e.fillColor == color || e.strokeColor == color),
    );
    notifyListeners();
  }

  void selectOverlappingElements() {
    _selectedElements.clear();

    for (int i = 0; i < _elements.length; i++) {
      for (int j = i + 1; j < _elements.length; j++) {
        if (_elements[i].boundingBox.overlaps(_elements[j].boundingBox)) {
          _selectedElements.add(_elements[i]);
          _selectedElements.add(_elements[j]);
        }
      }
    }
    notifyListeners();
  }

  void toggleElementSelection(SvgElementData element) {
    if (_selectedElements.contains(element)) {
      _selectedElements.remove(element);
    } else {
      _selectedElements.add(element);
    }
    notifyListeners();
  }

  // Get unique tag types
  Set<String> getUniqueTagTypes() {
    return _elements.map((e) => e.tagName).toSet();
  }

  // Get unique colors
  Set<String> getUniqueColors() {
    final colors = <String>{};
    for (final element in _elements) {
      if (element.fillColor != null) colors.add(element.fillColor!);
      if (element.strokeColor != null) colors.add(element.strokeColor!);
    }
    return colors;
  }

  // Get elements in specific grid
  List<SvgElementData> getElementsInGrid(int gridId) {
    return _elements.where((e) => e.gridId == gridId).toList();
  }

  // Get all populated grid IDs
  Set<int> getPopulatedGridIds() {
    return _elements.map((e) => e.gridId).toSet();
  }

  // Text recognition (hybrid)
  Future<GridRecognitionResult?> ensureGridTextRecognition(
    int gridId, {
    bool force = false,
  }) async {
    if (!_recognizeTextEnabled) return _recognitionCache[gridId];
    if (_recognitionInFlight.contains(gridId)) return _recognitionCache[gridId];
    if (!force && _recognitionCache.containsKey(gridId)) {
      return _recognitionCache[gridId];
    }

    _recognitionInFlight.add(gridId);
    notifyListeners();

    final elements = getElementsInGrid(gridId);
    final hits = <RecognizedTextHit>[];

    hits.addAll(_applyUserGeometryLabels(elements));
    hits.addAll(_extractTextNodeHits(elements));
    hits.addAll(_guessPolylineText(elements));
    hits.addAll(await _runOcrOnGrid(elements));

    final mergedHits = _mergeHits(hits);
    final result = GridRecognitionResult(
      gridId: gridId,
      hits: mergedHits,
      timestamp: DateTime.now(),
    );

    _recognitionCache[gridId] = result;
    _recognitionInFlight.remove(gridId);
    notifyListeners();
    return result;
  }

  List<RecognizedTextHit> _extractTextNodeHits(List<SvgElementData> elements) {
    final hits = <RecognizedTextHit>[];
    final textElements =
        elements.where((e) => e.tagName.toLowerCase() == 'text').toList();

    for (final element in textElements) {
      final textContent = _extractTextContent(element.xmlSnippet);
      if (textContent.isNotEmpty) {
        hits.add(
          RecognizedTextHit(
            text: textContent,
            source: 'text-node',
            confidence: 0.95,
            bounds: element.boundingBox,
          ),
        );
      }
    }
    return hits;
  }

  String _extractTextContent(String snippet) {
    final buffer = StringBuffer();
    final textMatches = RegExp(r'>([^<>]+)<').allMatches(snippet);
    for (final m in textMatches) {
      buffer.write(m.group(1)?.trim());
      buffer.write(' ');
    }
    return buffer.toString().trim();
  }

  List<RecognizedTextHit> _guessPolylineText(List<SvgElementData> elements) {
    final hits = <RecognizedTextHit>[];
    final candidates = elements.where((e) {
      final t = e.tagName.toLowerCase();
      return t == 'polyline' || t == 'polygon' || t == 'path';
    });

    for (final element in candidates) {
      final guess = _guessCharacterFromGeometry(element);
      if (guess != null) {
        hits.add(
          RecognizedTextHit(
            text: guess.text,
            source: 'polyline-heuristic',
            confidence: guess.confidence,
            bounds: element.boundingBox,
          ),
        );
      }
    }
    return hits;
  }

  _HeuristicGuess? _guessCharacterFromGeometry(SvgElementData element) {
    final box = element.boundingBox;
    if (box.width <= 0 || box.height <= 0) return null;

    final aspect = box.width / box.height;
    final isTall = aspect < 0.6;
    final isWide = aspect > 1.6;
    final isSquareish = aspect > 0.7 && aspect < 1.3;

    final pointCount = _countPolylinePoints(element.xmlSnippet);
    final hasSharpAngles =
        _hasRightAngleSegments(element.xmlSnippet, toleranceDeg: 25);

    // Basic shape-based guesses; these are intentionally soft and combined later.
    if (isTall && !hasSharpAngles) {
      return _HeuristicGuess(text: '1', confidence: 0.45);
    }
    if (isWide && hasSharpAngles) {
      return _HeuristicGuess(text: '-', confidence: 0.35);
    }
    if (isSquareish && pointCount >= 4 && hasSharpAngles) {
      return _HeuristicGuess(text: '0/O', confidence: 0.4);
    }
    if (isTall && hasSharpAngles && pointCount >= 6) {
      return _HeuristicGuess(text: '4/H', confidence: 0.35);
    }
    if (!hasSharpAngles && isSquareish && pointCount >= 5) {
      return _HeuristicGuess(text: 'C/G/S', confidence: 0.3);
    }
    return null;
  }

  int _countPolylinePoints(String snippet) {
    final pointsMatch = RegExp(r'points\s*=\s*"([^"]+)"').firstMatch(snippet);
    if (pointsMatch != null) {
      final pointsString = pointsMatch.group(1)!;
      return pointsString.split(RegExp(r'[ ,]+')).length ~/ 2;
    }
    // Try path data as a fallback proxy
    final pathMatch = RegExp(r'[MLCQSZTmlcqszt]').allMatches(snippet).length;
    return max(pathMatch, 0);
  }

  bool _hasRightAngleSegments(String snippet, {double toleranceDeg = 20}) {
    final pointsMatch =
        RegExp(r'points\s*=\s*"([^"]+)"').firstMatch(snippet);
    if (pointsMatch == null) return false;
    final pointsString = pointsMatch.group(1)!;
    final coords = pointsString
        .split(RegExp(r'\s+'))
        .map((pair) => pair.split(','))
        .where((p) => p.length == 2)
        .map((p) => Offset(
              double.tryParse(p[0]) ?? 0,
              double.tryParse(p[1]) ?? 0,
            ))
        .toList();
    if (coords.length < 3) return false;

    for (int i = 1; i < coords.length - 1; i++) {
      final a = coords[i - 1];
      final b = coords[i];
      final c = coords[i + 1];
      final v1 = Offset(b.dx - a.dx, b.dy - a.dy);
      final v2 = Offset(c.dx - b.dx, c.dy - b.dy);
      final dot = v1.dx * v2.dx + v1.dy * v2.dy;
      final mag = v1.distance * v2.distance;
      if (mag == 0) continue;
      final cosTheta = (dot / mag).clamp(-1.0, 1.0);
      final angleDeg = (acos(cosTheta) * 180 / pi).abs();
      if ((angleDeg - 90).abs() <= toleranceDeg) {
        return true;
      }
    }
    return false;
  }

  List<RecognizedTextHit> _mergeHits(List<RecognizedTextHit> hits) {
    final merged = <String, RecognizedTextHit>{};
    for (final hit in hits) {
      final key = hit.text.trim().toLowerCase();
      final existing = merged[key];
      if (existing == null || hit.confidence > existing.confidence) {
        merged[key] = hit;
      }
    }
    return merged.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  Future<List<RecognizedTextHit>> _runOcrOnGrid(
    List<SvgElementData> elements,
  ) async {
    // Placeholder for OCR integration. With a real OCR plugin, render the grid
    // or element bounds to an image and pass it through the engine.
    // We keep this async to avoid blocking UI and to allow future upgrades.
    return const <RecognizedTextHit>[];
  }

  List<RecognizedTextHit> _applyUserGeometryLabels(
      List<SvgElementData> elements) {
    final hits = <RecognizedTextHit>[];
    for (final element in elements) {
      final sig = _geometrySignature(element);
      if (sig == null) continue;
      final label = _userGeometryLabels[sig];
      if (label != null && label.isNotEmpty) {
        hits.add(RecognizedTextHit(
          text: label,
          source: 'user-labeled-geometry',
          confidence: 0.99,
          bounds: element.boundingBox,
        ));
      }
    }
    return hits;
  }

  String? _geometrySignature(SvgElementData element) {
    final tag = element.tagName.toLowerCase();
    List<Offset> points = [];

    if (tag == 'polyline' || tag == 'polygon') {
      points = _extractPointsFromSnippet(element.xmlSnippet);
    } else if (tag == 'path') {
      points = _extractPathPoints(element.xmlSnippet);
    } else {
      return null;
    }

    if (points.length < 2) return null;

    double minX = points.first.dx, maxX = points.first.dx;
    double minY = points.first.dy, maxY = points.first.dy;
    for (final p in points) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    final width = maxX - minX;
    final height = maxY - minY;
    if (width == 0 || height == 0) return null;

    final normalized = points
        .map((p) => Offset(
              (p.dx - minX) / width,
              (p.dy - minY) / height,
            ))
        .map((p) =>
            '${p.dx.toStringAsFixed(3)},${p.dy.toStringAsFixed(3)}')
        .join(';');

    final raw = '$tag|${points.length}|$normalized';
    return md5.convert(utf8.encode(raw)).toString();
  }

  List<Offset> _extractPointsFromSnippet(String snippet) {
    final pointsMatch = RegExp(r'points\s*=\s*"([^"]+)"').firstMatch(snippet);
    if (pointsMatch == null) return [];
    final pointsString = pointsMatch.group(1)!;
    final parts = pointsString.trim().split(RegExp(r'[\s,]+'));
    final points = <Offset>[];
    for (int i = 0; i + 1 < parts.length; i += 2) {
      final x = double.tryParse(parts[i]) ?? 0;
      final y = double.tryParse(parts[i + 1]) ?? 0;
      points.add(Offset(x, y));
    }
    return points;
  }

  List<Offset> _extractPathPoints(String snippet) {
    final dMatch = RegExp(r'd\s*=\s*"([^"]+)"').firstMatch(snippet);
    if (dMatch == null) return [];
    final d = dMatch.group(1)!;
    final numMatches =
        RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?').allMatches(d);
    final nums =
        numMatches.map((m) => double.tryParse(m.group(0) ?? '') ?? 0).toList();
    final points = <Offset>[];
    for (int i = 0; i + 1 < nums.length; i += 2) {
      points.add(Offset(nums[i], nums[i + 1]));
    }
    return points;
  }
}

class _HeuristicGuess {
  final String text;
  final double confidence;
  _HeuristicGuess({required this.text, required this.confidence});
}
