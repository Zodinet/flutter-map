import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../simplifier.dart';
import 'simplified_path.dart';

/// Abstract map geometry.
mixin MapGeometry {
  Rect get bounds;

  int get pointsCount;
}

/// Point geometry.
class MapPoint extends Offset with MapGeometry {
  MapPoint(double x, double y) : super(x, y);

  double get x => dx;

  double get y => dy;

  @override
  String toString() {
    return 'MapPoint{x: $x, y: $y}';
  }

  @override
  Rect get bounds => Rect.fromLTWH(x, y, 0, 0);

  @override
  int get pointsCount => 1;
}

/// Line string geometry.
class MapLineString with MapGeometry {
  final UnmodifiableListView<MapPoint> points;

  @override
  final Rect bounds;

  MapLineString._(this.points, this.bounds);

  factory MapLineString.coordinates(List<double> coordinates) {
    List<MapPoint> points = [];
    for (int i = 0; i < coordinates.length; i = i + 2) {
      if (i < coordinates.length - 1) {
        final x = coordinates[i];
        final y = coordinates[i + 1];
        points.add(MapPoint(x, y));
      }
    }
    return MapLineString(points);
  }

  factory MapLineString(List<MapPoint> points) {
    if (points.isEmpty) {
      throw ArgumentError("points can be empty");
    }

    final first = points.first;
    double left = first.dx;
    double right = first.dx;
    double top = first.dy;
    double bottom = first.dy;

    for (int i = 1; i < points.length; i++) {
      final point = points[i];
      left = math.min(point.dx, left);
      right = math.max(point.dx, right);
      bottom = math.max(point.dy, bottom);
      top = math.min(point.dy, top);
    }
    Rect bounds = Rect.fromLTRB(left, top, right, bottom);
    return MapLineString._(UnmodifiableListView<MapPoint>(points), bounds);
  }

  @override
  int get pointsCount => points.length;

  SimplifiedPath toSimplifiedPath(
      Matrix4 worldToCanvas, GeometrySimplifier simplifier) {
    Path path = Path();
    final simplifiedPoints = simplifier.simplify(worldToCanvas, points);

    for (int i = 0; i < simplifiedPoints.length; i++) {
      final point = simplifiedPoints[i];
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return SimplifiedPath(path, simplifiedPoints.length);
  }
}

/// Multi line string geometry.
class MapMultiLineString with MapGeometry {
  final UnmodifiableListView<MapLineString> linesString;

  @override
  final Rect bounds;

  MapMultiLineString._(this.linesString, this.bounds);

  factory MapMultiLineString(List<MapLineString> linesString) {
    Rect bounds = linesString.first.bounds;

    for (final line in linesString) {
      bounds = bounds.expandToInclude(line.bounds);
    }

    return MapMultiLineString._(
      UnmodifiableListView<MapLineString>(linesString),
      bounds,
    );
  }

  @override
  int get pointsCount => _getPointsCount();

  /// Gets the count of points.
  int _getPointsCount() {
    int count = 0;

    for (MapLineString line in linesString) {
      count += line.pointsCount;
    }

    return count;
  }
}

/// Line ring geometry.
class MapLinearRing with MapGeometry {
  final UnmodifiableListView<MapPoint> points;

  @override
  final Rect bounds;

  MapLinearRing._(this.points, this.bounds);

  factory MapLinearRing.coordinates(List<double> coordinates) {
    List<MapPoint> points = [];

    for (int i = 0; i < coordinates.length; i = i + 2) {
      if (i < coordinates.length - 1) {
        final x = coordinates[i];
        final y = coordinates[i + 1];
        points.add(MapPoint(x, y));
      }
    }
    return MapLinearRing(points);
  }

  factory MapLinearRing(List<MapPoint> points) {
    //TODO exception for insufficient number of points?

    if (points.isEmpty) {
      throw ArgumentError("points cannot be empty");
    }

    MapPoint first = points.first;
    double left = first.dx;
    double right = first.dx;
    double top = first.dy;
    double bottom = first.dy;

    for (int i = 1; i < points.length; i++) {
      final point = points[i];
      left = math.min(point.dx, left);
      right = math.max(point.dx, right);
      bottom = math.max(point.dy, bottom);
      top = math.min(point.dy, top);
    }
    final bounds = Rect.fromLTRB(left, top, right, bottom);
    return MapLinearRing._(UnmodifiableListView<MapPoint>(points), bounds);
  }

  @override
  int get pointsCount => points.length;

  SimplifiedPath toSimplifiedPath(
      Matrix4 worldToCanvas, GeometrySimplifier simplifier) {
    Path path = Path();
    final simplifiedPoints = simplifier.simplify(worldToCanvas, points);
    for (int i = 0; i < simplifiedPoints.length; i++) {
      MapPoint point = simplifiedPoints[i];
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return SimplifiedPath(path, simplifiedPoints.length);
  }
}

/// Polygon geometry.
class MapPolygon with MapGeometry {
  final MapLinearRing externalRing;
  final UnmodifiableListView<MapLinearRing> internalRings;

  @override
  final Rect bounds;

  MapPolygon._(this.externalRing, this.internalRings, this.bounds);

  factory MapPolygon.coordinates(List<double> coordinates) {
    List<MapPoint> externalPoints = [];
    List<MapLinearRing> internalRings = [];
    List<MapPoint> points = [];
    for (int i = 0; i < coordinates.length; i = i + 2) {
      if (i < coordinates.length - 1) {
        final x = coordinates[i];
        final y = coordinates[i + 1];
        points.add(MapPoint(x, y));
        if (points.length >= 3) {
          if (points.first.x == x && points.first.y == y) {
            // closing ring
            if (externalPoints.isEmpty) {
              externalPoints = points;
            } else {
              internalRings.add(MapLinearRing(points));
            }
            points = [];
          }
        }
      }
    }
    return MapPolygon(MapLinearRing(externalPoints), internalRings);
  }

  factory MapPolygon(
      MapLinearRing externalRing, List<MapLinearRing>? internalRings) {
    Rect bounds = externalRing.bounds;

    final internal = internalRings ?? [];
    for (MapLinearRing linearRing in internal) {
      bounds = bounds.expandToInclude(linearRing.bounds);
    }

    return MapPolygon._(
      externalRing,
      UnmodifiableListView<MapLinearRing>(internal),
      bounds,
    );
  }

  @override
  int get pointsCount => _getPointsCount();

  int _getPointsCount() {
    int count = externalRing.pointsCount;
    for (MapLinearRing ring in internalRings) {
      count += ring.pointsCount;
    }
    return count;
  }

  SimplifiedPath toSimplifiedPath(
      Matrix4 worldToCanvas, GeometrySimplifier simplifier) {
    Path path = Path()..fillType = PathFillType.evenOdd;

    SimplifiedPath simplifiedPath =
        externalRing.toSimplifiedPath(worldToCanvas, simplifier);
    int pointsCount = simplifiedPath.pointsCount;
    path.addPath(simplifiedPath.path, Offset.zero);
    for (MapLinearRing ring in internalRings) {
      simplifiedPath = ring.toSimplifiedPath(worldToCanvas, simplifier);
      pointsCount += simplifiedPath.pointsCount;
      path.addPath(simplifiedPath.path, Offset.zero);
    }
    return SimplifiedPath(path, pointsCount);
  }
}

/// Multi polygon geometry.
class MapMultiPolygon with MapGeometry {
  final UnmodifiableListView<MapPolygon> polygons;

  @override
  final Rect bounds;

  MapMultiPolygon._(this.polygons, this.bounds);

  factory MapMultiPolygon(List<MapPolygon> polygons) {
    Rect bounds = polygons.first.bounds;

    for (final polygon in polygons) {
      bounds = bounds.expandToInclude(polygon.bounds);
    }

    return MapMultiPolygon._(
      UnmodifiableListView<MapPolygon>(polygons),
      bounds,
    );
  }

  @override
  int get pointsCount => _getPointsCount();

  /// Gets the count of points.
  int _getPointsCount() {
    int count = 0;
    for (final polygon in polygons) {
      count += polygon.pointsCount;
    }
    return count;
  }
}
