import 'package:flutter/material.dart';

class InteractiveGridPainter extends CustomPainter {
  final double svgWidth;
  final double svgHeight;
  final double gridSize;
  final int? hoveredGridId;
  final int? selectedGridId;
  final bool showLabels;
  final Color gridColor;
  final Color gridLabelColor;
  final Set<int> populatedGridIds;

  InteractiveGridPainter({
    required this.svgWidth,
    required this.svgHeight,
    required this.populatedGridIds,
    this.gridSize = 50.0,
    this.hoveredGridId,
    this.selectedGridId,
    this.showLabels = true,
    this.gridColor = Colors.blue,
    this.gridLabelColor = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // CRITICAL FIX: Only draw grid cells WITHIN SVG bounds
    final maxGridCols = (svgWidth / gridSize).ceil();
    final maxGridRows = (svgHeight / gridSize).ceil();

    // Draw grid cells ONLY up to actual SVG dimensions
    for (int row = 0; row < maxGridRows; row++) {
      for (int col = 0; col < maxGridCols; col++) {
        final x = col * gridSize;
        final y = row * gridSize;

        // Stop if we've exceeded SVG bounds
        if (x >= svgWidth || y >= svgHeight) continue;

        final gridId = (row * maxGridCols) + col + 1;

        // Calculate actual cell size (last cells may be partial)
        final cellWidth = (x + gridSize > svgWidth) ? (svgWidth - x) : gridSize;
        final cellHeight =
            (y + gridSize > svgHeight) ? (svgHeight - y) : gridSize;

        final cellRect = Rect.fromLTWH(x, y, cellWidth, cellHeight);

        // Determine cell color based on state
        if (gridId == selectedGridId) {
          final cellPaint = Paint()
            ..color = Colors.blue.withOpacity(0.3)
            ..style = PaintingStyle.fill;
          canvas.drawRect(cellRect, cellPaint);
        } else if (gridId == hoveredGridId) {
          final cellPaint = Paint()
            ..color = Colors.blue.withOpacity(0.15)
            ..style = PaintingStyle.fill;
          canvas.drawRect(cellRect, cellPaint);
        } else if (populatedGridIds.contains(gridId)) {
          // Highlight cells with elements
          final cellPaint = Paint()
            ..color = gridColor.withOpacity(0.05)
            ..style = PaintingStyle.fill;
          canvas.drawRect(cellRect, cellPaint);
        }

        // Draw grid lines
        final linePaint = Paint()
          ..color = gridColor.withOpacity(0.3)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

        canvas.drawRect(cellRect, linePaint);

        // Draw grid labels
        if (showLabels && x + 20 < svgWidth && y + 12 < svgHeight) {
          final textStyle = TextStyle(
            color: gridId == selectedGridId
                ? Colors.blue
                : gridLabelColor.withOpacity(0.7),
            fontSize: 10,
            fontWeight:
                gridId == selectedGridId ? FontWeight.bold : FontWeight.normal,
          );
          final textPainter = TextPainter(
            text: TextSpan(text: '$gridId', style: textStyle),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          textPainter.paint(
            canvas,
            Offset(x + 2, y + 2),
          );
        }

        // Draw element count badge for populated cells
        if (showLabels && populatedGridIds.contains(gridId)) {
          final badge = Paint()
            ..color = Colors.blue.withOpacity(0.7)
            ..style = PaintingStyle.fill;

          final badgeSize = 6.0;
          final badgeX = x + cellWidth - badgeSize - 2;
          final badgeY = y + badgeSize + 2;

          if (badgeX > x && badgeY < y + cellHeight) {
            canvas.drawCircle(
              Offset(badgeX, badgeY),
              badgeSize,
              badge,
            );
          }
        }
      }
    }

    // Draw SVG boundary
    final boundaryPaint = Paint()
      ..color = gridColor.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, svgWidth, svgHeight),
      boundaryPaint,
    );
  }

  @override
  bool shouldRepaint(covariant InteractiveGridPainter oldDelegate) {
    return oldDelegate.svgWidth != svgWidth ||
        oldDelegate.svgHeight != svgHeight ||
        oldDelegate.hoveredGridId != hoveredGridId ||
        oldDelegate.selectedGridId != selectedGridId ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.populatedGridIds != populatedGridIds;
  }
}

class BoundingBoxPainter extends CustomPainter {
  final Rect box;
  final Color color;
  final String? label;

  BoundingBoxPainter(
    this.box, {
    this.color = Colors.red,
    this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()..color = color.withOpacity(0.1);

    // Draw filled background
    canvas.drawRect(box, fillPaint);

    // Draw bounding box
    canvas.drawRect(box, paint);

    // Draw corner markers
    const cornerRadius = 4.0;
    final cornerPaint = Paint()..color = color;

    canvas.drawCircle(box.topLeft, cornerRadius, cornerPaint);
    canvas.drawCircle(box.topRight, cornerRadius, cornerPaint);
    canvas.drawCircle(box.bottomLeft, cornerRadius, cornerPaint);
    canvas.drawCircle(box.bottomRight, cornerRadius, cornerPaint);

    // Draw dimensions
    final textStyle = TextStyle(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.white.withOpacity(0.9),
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final dimensionText =
        '${box.width.toStringAsFixed(1)} × ${box.height.toStringAsFixed(1)}';
    textPainter.text = TextSpan(text: dimensionText, style: textStyle);
    textPainter.layout();

    final textPosition = Offset(
      box.left + (box.width - textPainter.width) / 2,
      box.top - textPainter.height - 4,
    );

    // Draw text background
    final textBackground = Rect.fromPoints(
      textPosition,
      textPosition.translate(textPainter.width, textPainter.height),
    ).inflate(2);

    canvas.drawRect(
      textBackground,
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    textPainter.paint(canvas, textPosition);

    // Draw label if provided
    if (label != null) {
      textPainter.text = TextSpan(
        text: label,
        style: textStyle.copyWith(fontSize: 10),
      );
      textPainter.layout();

      final labelPosition = Offset(
        box.left,
        box.bottom + 4,
      );

      final labelBackground = Rect.fromPoints(
        labelPosition,
        labelPosition.translate(textPainter.width, textPainter.height),
      ).inflate(2);

      canvas.drawRect(
        labelBackground,
        Paint()..color = Colors.white.withOpacity(0.9),
      );

      textPainter.paint(canvas, labelPosition);
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.box != box ||
        oldDelegate.color != color ||
        oldDelegate.label != label;
  }
}

class MultipleBoundingBoxesPainter extends CustomPainter {
  final List<Rect> boxes;
  final Color color;

  MultipleBoundingBoxesPainter(
    this.boxes, {
    this.color = Colors.orange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()..color = color.withOpacity(0.05);

    for (final box in boxes) {
      canvas.drawRect(box, fillPaint);
      canvas.drawRect(box, paint);
    }

    // Draw count badge
    if (boxes.isNotEmpty) {
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );
      final textPainter = TextPainter(
        text: TextSpan(text: '${boxes.length}', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final badgePosition = Offset(10, 10);
      final badgeRadius = 20.0;

      canvas.drawCircle(
        badgePosition.translate(badgeRadius, badgeRadius),
        badgeRadius,
        Paint()..color = color,
      );

      textPainter.paint(
        canvas,
        badgePosition.translate(
          badgeRadius - textPainter.width / 2,
          badgeRadius - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MultipleBoundingBoxesPainter oldDelegate) {
    return oldDelegate.boxes != boxes || oldDelegate.color != color;
  }
}

class GridOverlayPainter extends CustomPainter {
  final double svgWidth;
  final double svgHeight;
  final double gridSize;
  final Color gridColor;
  final Color gridLabelColor;

  GridOverlayPainter({
    required this.svgWidth,
    required this.svgHeight,
    this.gridSize = 50.0,
    this.gridColor = Colors.blue,
    this.gridLabelColor = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withOpacity(0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Vertical lines - ONLY within SVG width
    for (double x = 0; x <= svgWidth; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, svgHeight), paint);
    }

    // Horizontal lines - ONLY within SVG height
    for (double y = 0; y <= svgHeight; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(svgWidth, y), paint);
    }

    // Coordinate labels
    final textStyle = TextStyle(
      color: gridLabelColor.withOpacity(0.6),
      fontSize: 10,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // X-axis labels
    for (double x = gridSize; x <= svgWidth; x += gridSize) {
      textPainter.text = TextSpan(
        text: x.toStringAsFixed(0),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, 2),
      );
    }

    // Y-axis labels
    for (double y = gridSize; y <= svgHeight; y += gridSize) {
      textPainter.text = TextSpan(
        text: y.toStringAsFixed(0),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridOverlayPainter oldDelegate) {
    return oldDelegate.svgWidth != svgWidth ||
        oldDelegate.svgHeight != svgHeight ||
        oldDelegate.gridSize != gridSize;
  }
}
