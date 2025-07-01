// Custom listener for Mapbox point annotation clicks
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Extends the built-in annotation click listener to add custom behavior
class PointAnnotationClickListener extends OnPointAnnotationClickListener {
  /// Function to call when annotation is clicked, passed from outside
  final void Function(PointAnnotation annotation) onAnnotationClick;

  /// Constructor requires this callback function
  PointAnnotationClickListener({
    required this.onAnnotationClick,
  });

  /// Override the callback method that fires on annotation click
  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    print("Point annotation clicked, id: ${annotation.id}");
    // Call the passed-in callback with the clicked annotation
    onAnnotationClick(annotation);
  }
}
