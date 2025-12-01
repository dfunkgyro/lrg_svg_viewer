import 'dart:math';
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
}
