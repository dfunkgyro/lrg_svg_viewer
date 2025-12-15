import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/svg_models.dart';

class ZoomControls extends StatelessWidget {
  final double initialScale;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onReset;

  const ZoomControls({
    super.key,
    required this.initialScale,
    this.onZoomIn,
    this.onZoomOut,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<SvgModel>(context);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'VIEW',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 12),

            // Zoom in
            _ZoomButton(
              icon: Icons.add,
              tooltip: 'Zoom In (Ctrl/Cmd +)',
              onPressed: onZoomIn ??
                  () {
                    final center = _getViewportCenter(context);
                    model.zoomStep(1.2, center);
                  },
            ),

            const SizedBox(height: 8),

            // Current scale indicator with percentage
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${(model.currentScale * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                  ),
                  Text(
                    'zoom',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Zoom out
            _ZoomButton(
              icon: Icons.remove,
              tooltip: 'Zoom Out (Ctrl/Cmd -)',
              onPressed: onZoomOut ??
                  () {
                    final center = _getViewportCenter(context);
                    model.zoomStep(1 / 1.2, center);
                  },
            ),

            const Divider(height: 24),

            // Reset zoom
            _ZoomButton(
              icon: Icons.fit_screen,
              tooltip: 'Fit to Screen (Ctrl/Cmd 0)',
              onPressed: onReset ?? () => model.resetZoom(initialScale),
            ),

            const SizedBox(height: 8),

            // Zoom to 100%
            _ZoomButton(
              icon: Icons.crop_square,
              tooltip: '100% Zoom',
              onPressed: () {
                final center = _getViewportCenter(context);
                final targetScale = 1.0;
                final dx = (center.dx - model.currentPanOffset.dx) / model.currentScale;
                final dy = (center.dy - model.currentPanOffset.dy) / model.currentScale;
                final newPanX = center.dx - dx * targetScale;
                final newPanY = center.dy - dy * targetScale;
                model.updateScaleAndOffset(targetScale, Offset(newPanX, newPanY));
              },
            ),

            const Divider(height: 24),

            // Grid toggle with label
            Column(
              children: [
                Tooltip(
                  message: 'Toggle Grid Overlay (G)',
                  child: Container(
                    decoration: BoxDecoration(
                      color: model.showGrid
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        model.showGrid ? Icons.grid_on : Icons.grid_off,
                        color: model.showGrid ? Colors.blue[700] : null,
                      ),
                      onPressed: () => model.toggleGrid(!model.showGrid),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
                Text(
                  'Grid',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: model.showGrid ? Colors.blue[700] : Colors.grey,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Offset _getViewportCenter(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    return Offset(size.width / 2, size.height / 2);
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(icon, size: 22),
          onPressed: onPressed,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
