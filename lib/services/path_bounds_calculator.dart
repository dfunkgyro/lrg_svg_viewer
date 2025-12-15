import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

class PathBoundsCalculator {
  static Rect computePathBounds(String pathData) {
    final commands = _parsePathCommands(pathData);
    if (commands.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    double currentX = 0;
    double currentY = 0;
    double startX = 0;
    double startY = 0;

    for (final command in commands) {
      switch (command.type) {
        case 'M':
          currentX = command.args[0];
          currentY = command.args[1];
          startX = currentX;
          startY = currentY;
          _updateBounds(currentX, currentY, minX, minY, maxX, maxY);
          break;
        case 'L':
          currentX = command.args[0];
          currentY = command.args[1];
          _updateBounds(currentX, currentY, minX, minY, maxX, maxY);
          break;
        case 'H':
          currentX = command.args[0];
          _updateBounds(currentX, currentY, minX, minY, maxX, maxY);
          break;
        case 'V':
          currentY = command.args[0];
          _updateBounds(currentX, currentY, minX, minY, maxX, maxY);
          break;
        case 'C':
          final points = _computeCubicBezierPoints(
            currentX,
            currentY,
            command.args[0],
            command.args[1],
            command.args[2],
            command.args[3],
            command.args[4],
            command.args[5],
          );
          for (final point in points) {
            _updateBounds(point.dx, point.dy, minX, minY, maxX, maxY);
          }
          currentX = command.args[4];
          currentY = command.args[5];
          break;
        case 'Q':
          final points = _computeQuadraticBezierPoints(
            currentX,
            currentY,
            command.args[0],
            command.args[1],
            command.args[2],
            command.args[3],
          );
          for (final point in points) {
            _updateBounds(point.dx, point.dy, minX, minY, maxX, maxY);
          }
          currentX = command.args[2];
          currentY = command.args[3];
          break;
        case 'Z':
          currentX = startX;
          currentY = startY;
          break;
      }
    }

    if (minX.isInfinite) return Rect.zero;

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static void _updateBounds(
      double x, double y, double minX, double minY, double maxX, double maxY) {
    minX = min(minX, x);
    minY = min(minY, y);
    maxX = max(maxX, x);
    maxY = max(maxY, y);
  }

  static List<Offset> _computeCubicBezierPoints(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final points = <Offset>[];
    for (double t = 0; t <= 1; t += 0.1) {
      final x = _cubicBezier(x0, x1, x2, x3, t);
      final y = _cubicBezier(y0, y1, y2, y3, t);
      points.add(Offset(x, y));
    }
    return points;
  }

  static List<Offset> _computeQuadraticBezierPoints(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final points = <Offset>[];
    for (double t = 0; t <= 1; t += 0.1) {
      final x = _quadraticBezier(x0, x1, x2, t);
      final y = _quadraticBezier(y0, y1, y2, t);
      points.add(Offset(x, y));
    }
    return points;
  }

  static double _cubicBezier(double a, double b, double c, double d, double t) {
    return pow(1 - t, 3) * a +
        3 * pow(1 - t, 2) * t * b +
        3 * (1 - t) * pow(t, 2) * c +
        pow(t, 3) * d;
  }

  static double _quadraticBezier(double a, double b, double c, double t) {
    return pow(1 - t, 2) * a + 2 * (1 - t) * t * b + pow(t, 2) * c;
  }

  static List<PathCommand> _parsePathCommands(String pathData) {
    final commands = <PathCommand>[];
    final pattern =
        RegExp(r'([MLHVCSQZTA])([^MLHVCSQZTA]*)', caseSensitive: false);
    final matches = pattern.allMatches(pathData);

    for (final match in matches) {
      final command = match.group(1)!;
      final argsString = match.group(2)!;
      final args = _parseArgs(argsString);
      commands.add(PathCommand(command, args));
    }

    return commands;
  }

  static List<double> _parseArgs(String argsString) {
    final pattern = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
    return pattern
        .allMatches(argsString)
        .map((match) => double.tryParse(match.group(0)!) ?? 0.0)
        .toList();
  }
}

class PathCommand {
  final String type;
  final List<double> args;

  PathCommand(this.type, this.args);
}
