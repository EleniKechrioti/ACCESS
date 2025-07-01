import 'dart:math';

import '../models/navigation_step.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Finds the nearest navigation step to the user's current location
NavigationStep? findNearestStep(Point userLocation, List<NavigationStep> steps) {
  NavigationStep? nearestStep;
  double shortestDistance = double.infinity;

  /// Loop through all steps to find the closest one by distance
  for (final step in steps) {
    final d = distanceBetweenPoints(userLocation, step.location);
    if (d < shortestDistance) {
      shortestDistance = d;
      nearestStep = step;
    }
  }

  return nearestStep;
}

/// Calculates the distance in meters between two geographic points using the Haversine formula
double distanceBetweenPoints(Point p1, Point p2) {
  final double lat1 = p1.coordinates.lat.toDouble();
  final double lon1 = p1.coordinates.lng.toDouble();
  final double lat2 = p2.coordinates.lat.toDouble();
  final double lon2 = p2.coordinates.lng.toDouble();

  const R = 6371000; // Earth radius in meters
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);

  /// Haversine formula to calculate great-circle distance between two points
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
          cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
              sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c;
}

/// Converts degrees to radians
double _toRadians(double degree) => degree * pi / 180;
