import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../blocs/map_bloc/map_bloc.dart';

/// Queries map features around a center point within a tolerance (pixel radius)
/// Returns a list of unique map features found nearby
Future<List<mapbox.QueriedRenderedFeature>> queryNearbyFeatures(
    mapbox.ScreenCoordinate center,
    int tolerance,
    BuildContext context,
    ) async {
  final results = <mapbox.QueriedRenderedFeature>[];
  final mapController = context.read<MapBloc>().state.mapController;

  // Loop through a square area around the center coordinate (offset by dx, dy)
  for (int dx = -tolerance; dx <= tolerance; dx++) {
    for (int dy = -tolerance; dy <= tolerance; dy++) {
      final point = mapbox.ScreenCoordinate(
        x: center.x + dx,
        y: center.y + dy,
      );

      // Query rendered features at the current screen coordinate
      final features = await mapController?.queryRenderedFeatures(
        mapbox.RenderedQueryGeometry.fromScreenCoordinate(point),
        mapbox.RenderedQueryOptions(
          layerIds: ['poi-label', 'place-label', 'your-custom-layer'], // Target specific layers
        ),
      );

      // If features found, add them to results (filter out any nulls)
      if (features != null) {
        results.addAll(features.where((f) => f != null).cast<mapbox.QueriedRenderedFeature>());
      }
    }
  }

  /// Filter duplicates by 'name' property to return unique features only
  final seenNames = <String>{};
  final uniqueResults = <mapbox.QueriedRenderedFeature>[];

  for (final feature in results) {
    // Extract properties map and get the 'name' of the feature
    final prop = feature.queriedFeature.feature['properties'];
    final props = Map<String, dynamic>.from(prop as Map);
    final name = props['name'];

    // Only add if name exists and hasn't been added yet
    if (name != null && !seenNames.contains(name)) {
      seenNames.add(name);
      uniqueResults.add(feature);
    }
  }

  return uniqueResults;
}
