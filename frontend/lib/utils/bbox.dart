import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../blocs/map_bloc/map_bloc.dart';

/// Gets the bounding box (bbox) string of the current visible map area
Future<String> getBbox(BuildContext context) async {
  /// Access the MapBloc's mapController
  final mapController = context.read<MapBloc>().state.mapController;
  if (mapController == null) {
    print("_onTap: Widget not mounted or controller is null. Skipping.");
    return '';
  }

  String bboxString = '';
  try {
    /// Get the current camera state of the map (position, zoom, bearing, pitch)
    final mapbox.CameraState currentCameraState = await mapController.getCameraState();

    /// Create CameraOptions from the current camera state to use for getting bounds
    final mapbox.CameraOptions currentCameraOptions = mapbox.CameraOptions(
      center: currentCameraState.center,
      padding: currentCameraState.padding,
      zoom: currentCameraState.zoom,
      bearing: currentCameraState.bearing,
      pitch: currentCameraState.pitch,
    );

    /// Get the visible coordinate bounds based on the camera options
    final mapbox.CoordinateBounds? bounds = await mapController.coordinateBoundsForCamera(currentCameraOptions);

    // If bounds are available, extract southwest and northeast coordinates to form bbox string
    if (bounds != null) {
      final minLng = bounds.southwest.coordinates.lng;
      final minLat = bounds.southwest.coordinates.lat;
      final maxLng = bounds.northeast.coordinates.lng;
      final maxLat = bounds.northeast.coordinates.lat;

      /// Format bbox as "minLng,minLat,maxLng,maxLat"
      bboxString = '$minLng,$minLat,$maxLng,$maxLat';
      return bboxString;
    } else {
      print('[ Button] Could not get map bounds (getVisibleCoordinateBounds returned null).');
    }
  } catch (e) {
    print("[Button] Error getting map bounds: $e");
  }
  return bboxString;
}
