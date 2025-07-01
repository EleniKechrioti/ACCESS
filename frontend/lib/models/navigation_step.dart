import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class NavigationStep {
  final String instruction;  // Text instruction for this navigation step
  final double? distance;    // Distance in meters (optional)
  final double? duration;    // Duration in seconds (optional)
  final Point location;      // Geographic point of the step (longitude, latitude)

  NavigationStep({
    required this.instruction,
    required this.location,
    this.distance,
    this.duration,
  });

  // Creates a NavigationStep from a JSON map
  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      instruction: json['instruction'] ?? '',
      distance: (json['distance'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
      location: Point(
        coordinates: Position(
          (json['location']['lng'] as num).toDouble(),
          (json['location']['lat'] as num).toDouble(),
        ),
      ),
    );
  }
}
