import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/svg_models.dart';
import '../services/theme_manager.dart';
import 'custom_painters.dart';
import 'zoom_controls.dart';

class SvgViewport extends StatefulWidget {
  const SvgViewport({super.key});

  @override
  State<SvgViewport> createState() => _SvgViewportState();
}

class _SvgViewportState extends State<SvgViewport>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();

  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  double _initialScale = 1.0;
  bool _isInitialized = false;
  int? _hoveredGridId;
  int _lastHandledNavigationVersion = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (!mounted) return;

    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final panOffset =
        Offset(matrix.getTranslation().x, matrix.getTranslation().y);

    final model = Provider.of<SvgModel>(context, listen: false);
    model.updateScaleAndOffset(scale, panOffset);
  }

  void _animateToTransform(Matrix4 targetTransform) {
    final Matrix4 beginTransform = _transformationController.value.clone();

    _animation = Matrix4Tween(
      begin: beginTransform,
      end: targetTransform,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward(from: 0).then((_) {
      _transformationController.value = targetTransform;
    });

    _animation!.addListener(() {
      _transformationController.value = _animation!.value;
    });
  }

  void _initializeTransformation(
    double svgWidth,
    double svgHeight,
    double viewportWidth,
    double viewportHeight,
  ) {
    if (_isInitialized || svgWidth <= 0 || svgHeight <= 0) return;

    print('🎯 Initializing viewport:');
    print('  SVG: ${svgWidth.toInt()}x${svgHeight.toInt()}');
    print('  Viewport: ${viewportWidth.toInt()}x${viewportHeight.toInt()}');

    // Calculate scale to fit HEIGHT (as requested)
    const padding = 40.0;
    final scaleToFitHeight = (viewportHeight - padding) / svgHeight;
    final scale = scaleToFitHeight.clamp(0.01, 10.0);

    _initialScale = scale;

    // Center the SVG
    final scaledWidth = svgWidth * scale;
    final scaledHeight = svgHeight * scale;

    final initialPanX = (viewportWidth - scaledWidth) / 2;
    final initialPanY = (viewportHeight - scaledHeight) / 2;

    final initialTransform = Matrix4.identity()
      ..translate(initialPanX, initialPanY)
      ..scale(scale);

    print('  Scale: ${scale.toStringAsFixed(3)}');
    print('  Pan: (${initialPanX.toInt()}, ${initialPanY.toInt()})');
    print('  Scaled size: ${scaledWidth.toInt()}x${scaledHeight.toInt()}');

    // Set initial transform immediately (no animation for first load)
    _transformationController.value = initialTransform;
    _isInitialized = true;

    // Update model
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final model = Provider.of<SvgModel>(context, listen: false);
        model.updateScaleAndOffset(scale, Offset(initialPanX, initialPanY));
      }
    });
  }

  void _handleZoomIn() {
    final model = Provider.of<SvgModel>(context, listen: false);
    final viewportCenter = _getViewportCenter();

    final newScale = (model.currentScale * 1.2).clamp(0.01, 100.0);
    final dx =
        (viewportCenter.dx - model.currentPanOffset.dx) / model.currentScale;
    final dy =
        (viewportCenter.dy - model.currentPanOffset.dy) / model.currentScale;
    final newPanX = viewportCenter.dx - dx * newScale;
    final newPanY = viewportCenter.dy - dy * newScale;

    final targetTransform = Matrix4.identity()
      ..translate(newPanX, newPanY)
      ..scale(newScale);

    _animateToTransform(targetTransform);
  }

  void _handleZoomOut() {
    final model = Provider.of<SvgModel>(context, listen: false);
    final viewportCenter = _getViewportCenter();

    final newScale = (model.currentScale / 1.2).clamp(0.01, 100.0);
    final dx =
        (viewportCenter.dx - model.currentPanOffset.dx) / model.currentScale;
    final dy =
        (viewportCenter.dy - model.currentPanOffset.dy) / model.currentScale;
    final newPanX = viewportCenter.dx - dx * newScale;
    final newPanY = viewportCenter.dy - dy * newScale;

    final targetTransform = Matrix4.identity()
      ..translate(newPanX, newPanY)
      ..scale(newScale);

    _animateToTransform(targetTransform);
  }

  void _resetZoom() {
    final model = Provider.of<SvgModel>(context, listen: false);
    final renderBox = context.findRenderObject() as RenderBox?;

    if (renderBox != null && model.svgWidth > 0 && model.svgHeight > 0) {
      _isInitialized = false;
      _initializeTransformation(
        model.svgWidth,
        model.svgHeight,
        renderBox.size.width,
        renderBox.size.height,
      );
    }
  }

  Offset _getViewportCenter() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      return Offset(size.width / 2, size.height / 2);
    }
    return Offset.zero;
  }

  void _handleGridHover(Offset localPosition, SvgModel model) {
    // Transform viewport coordinates to SVG coordinates
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    final svgX = (localPosition.dx - translation.x) / scale;
    final svgY = (localPosition.dy - translation.y) / scale;

    // Check if within SVG bounds
    if (svgX >= 0 &&
        svgX <= model.svgWidth &&
        svgY >= 0 &&
        svgY <= model.svgHeight) {
      final gridBoxSize = model.gridBoxSize;
      final maxGridCols = model.maxGridCols;

      final gridX = (svgX / gridBoxSize).floor();
      final gridY = (svgY / gridBoxSize).floor();
      final gridId = (gridY * maxGridCols) + gridX + 1;

      if (gridId != _hoveredGridId && gridId <= model.totalGridCells) {
        setState(() {
          _hoveredGridId = gridId;
        });
        model.setHoveredGrid(gridId);
      }
    } else {
      if (_hoveredGridId != null) {
        setState(() {
          _hoveredGridId = null;
        });
        model.setHoveredGrid(null);
      }
    }
  }

  void _handleGridTap(Offset localPosition, SvgModel model) {
    // Transform viewport coordinates to SVG coordinates
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    final svgX = (localPosition.dx - translation.x) / scale;
    final svgY = (localPosition.dy - translation.y) / scale;

    // Check if within SVG bounds
    if (svgX >= 0 &&
        svgX <= model.svgWidth &&
        svgY >= 0 &&
        svgY <= model.svgHeight) {
      final gridBoxSize = model.gridBoxSize;
      final maxGridCols = model.maxGridCols;

      final gridX = (svgX / gridBoxSize).floor();
      final gridY = (svgY / gridBoxSize).floor();
      final gridId = (gridY * maxGridCols) + gridX + 1;

      if (gridId <= model.totalGridCells) {
        _navigateToGrid(gridId, model);
      }
    }
  }

  void _navigateToGrid(int gridId, SvgModel model) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportWidth = renderBox.size.width;
    final viewportHeight = renderBox.size.height;

    final gridInfo = model.getGridInfo(gridId);

    // Calculate scale to show 3x3 grid cells
    final targetScale = min(
      viewportWidth / (model.gridBoxSize * 3),
      viewportHeight / (model.gridBoxSize * 3),
    ).clamp(0.1, 10.0);

    // Calculate offset to center the grid cell
    final targetOffset = Offset(
      (viewportWidth / 2) - (gridInfo.centerX * targetScale),
      (viewportHeight / 2) - (gridInfo.centerY * targetScale),
    );

    final targetTransform = Matrix4.identity()
      ..translate(targetOffset.dx, targetOffset.dy)
      ..scale(targetScale);

    model.selectGridById(gridId);
    _animateToTransform(targetTransform);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SvgModel, ThemeManager>(
      builder: (context, model, themeManager, child) {
        if (model.filePath == null) {
          return _buildEmptyState(context);
        }

        if (model.isParsing) {
          return _buildLoadingState();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth;
            final viewportHeight = constraints.maxHeight;

            if (model.svgWidth == 0 || model.svgHeight == 0) {
              return _buildLoadingState();
            }

            // Initialize transformation after first frame with dimensions
            if (!_isInitialized) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initializeTransformation(
                  model.svgWidth,
                  model.svgHeight,
                  viewportWidth,
                  viewportHeight,
                );
              });
            }

            if (model.pendingNavigateGridId != null &&
                model.navigationRequestVersion != _lastHandledNavigationVersion) {
              final targetGrid = model.pendingNavigateGridId!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _navigateToGrid(targetGrid, model);
                _lastHandledNavigationVersion = model.navigationRequestVersion;
                model.clearNavigateRequest();
              });
            }

            return Stack(
              children: [
                // Main Interactive Viewer
                _buildInteractiveViewer(model, themeManager),

                // Debug info
                _buildDebugInfo(context, model, viewportWidth, viewportHeight),

                // Controls overlay
                Positioned(
                  top: 16,
                  right: 16,
                  child: ZoomControls(
                    initialScale: _initialScale,
                    onZoomIn: _handleZoomIn,
                    onZoomOut: _handleZoomOut,
                    onReset: _resetZoom,
                  ),
                ),

                // Grid info tooltip
                if (model.showGrid && _hoveredGridId != null)
                  _buildGridTooltip(model),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInteractiveViewer(SvgModel model, ThemeManager themeManager) {
    final file = File(model.filePath!);

    return MouseRegion(
      onHover: model.showGrid
          ? (event) => _handleGridHover(event.localPosition, model)
          : null,
      onExit: model.showGrid
          ? (event) {
              setState(() {
                _hoveredGridId = null;
              });
              model.setHoveredGrid(null);
            }
          : null,
      child: GestureDetector(
        onTapDown: model.showGrid
            ? (details) => _handleGridTap(details.localPosition, model)
            : null,
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.01,
          maxScale: 100.0,
          panEnabled: true,
          scaleEnabled: true,
          constrained: false,
          child: SizedBox(
            width: model.svgWidth,
            height: model.svgHeight,
            child: Container(
              color: themeManager.getViewportBackground(),
              child: Stack(
                children: [
                  // SVG display
                  _buildSvgDisplay(file, model),

                  // Grid overlay - ONLY within SVG bounds
                  if (model.showGrid)
                    CustomPaint(
                      size: Size(model.svgWidth, model.svgHeight),
                      painter: InteractiveGridPainter(
                        svgWidth: model.svgWidth,
                        svgHeight: model.svgHeight,
                        gridSize: model.gridBoxSize,
                        hoveredGridId: model.hoveredGridId,
                        selectedGridId: model.selectedGridId,
                        showLabels: model.currentScale > 0.3,
                        gridColor: themeManager.getGridColor(),
                        gridLabelColor: themeManager.getGridLabelColor(),
                        populatedGridIds: model.getPopulatedGridIds(),
                      ),
                    ),

                  // Selected element bounding box
                  if (model.selectedElement != null)
                    CustomPaint(
                      size: Size(model.svgWidth, model.svgHeight),
                      painter: BoundingBoxPainter(
                        model.selectedElement!.boundingBox,
                        color: Colors.blue,
                        label: model.selectedElement!.tagName,
                      ),
                    ),

                  // Multiple selected elements
                  if (model.selectedElements.isNotEmpty)
                    CustomPaint(
                      size: Size(model.svgWidth, model.svgHeight),
                      painter: MultipleBoundingBoxesPainter(
                        model.selectedElements
                            .map((e) => e.boundingBox)
                            .toList(),
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSvgDisplay(File file, SvgModel model) {
    return SvgPicture.file(
      file,
      width: model.svgWidth,
      height: model.svgHeight,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Upload an SVG file to begin',
            style: TextStyle(
              fontSize: 16,
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click the upload button in the top right',
            style: TextStyle(
              fontSize: 14,
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading SVG...'),
        ],
      ),
    );
  }

  Widget _buildDebugInfo(
    BuildContext context,
    SvgModel model,
    double viewportWidth,
    double viewportHeight,
  ) {
    return Positioned(
      top: 16,
      left: 16,
      child: Card(
        color: Colors.black.withOpacity(0.7),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDebugRow('SVG',
                  '${model.svgWidth.toInt()}×${model.svgHeight.toInt()}'),
              _buildDebugRow('Viewport',
                  '${viewportWidth.toInt()}×${viewportHeight.toInt()}'),
              _buildDebugRow(
                  'Scale', '${model.currentScale.toStringAsFixed(2)}x'),
              _buildDebugRow(
                'Pan',
                '(${model.currentPanOffset.dx.toStringAsFixed(0)}, ${model.currentPanOffset.dy.toStringAsFixed(0)})',
              ),
              _buildDebugRow('Grid', model.showGrid ? 'ON' : 'OFF'),
              _buildDebugRow('Grid Cells', '${model.totalGridCells}'),
              _buildDebugRow('Initialized', _isInitialized ? 'YES' : 'NO',
                  color: _isInitialized ? Colors.green[300] : Colors.red[300]),
              if (model.selectedGridId != null)
                _buildDebugRow('Selected Grid', '${model.selectedGridId}',
                    color: Colors.blue[300]),
              if (model.hoveredGridId != null)
                _buildDebugRow('Hovered Grid', '${model.hoveredGridId}',
                    color: Colors.cyan[300]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value, {Color? color}) {
    return Text(
      '$label: $value',
      style: TextStyle(
        color: color ?? Colors.white,
        fontSize: 12,
        fontFamily: 'monospace',
      ),
    );
  }

  Widget _buildGridTooltip(SvgModel model) {
    if (_hoveredGridId == null) return const SizedBox.shrink();

    final gridInfo = model.getGridInfo(_hoveredGridId!);
    final elementsInGrid = model.getElementsInGrid(_hoveredGridId!);

    return Positioned(
      top: 60,
      left: 16,
      child: Card(
        color: Colors.blue.withOpacity(0.9),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Grid ${gridInfo.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Position: (${gridInfo.x}, ${gridInfo.y})',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              Text(
                'Bounds: (${gridInfo.left.toInt()}, ${gridInfo.top.toInt()}) - (${gridInfo.right.toInt()}, ${gridInfo.bottom.toInt()})',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              Text(
                'Elements: ${elementsInGrid.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              if (elementsInGrid.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Click to navigate',
                  style: TextStyle(
                    color: Colors.cyan[100],
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
