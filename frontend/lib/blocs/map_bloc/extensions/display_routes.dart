part of '../map_bloc.dart';

/// Extension on MapBloc to handle the display of routes and alternative paths.
extension MapBlocDisplay on MapBloc {

  /// Fetches route data from the MapService based on the user's location and selected destination.
  /// If `alternatives` is true, the API will return multiple route options.
  Future<Map<String, dynamic>?> _fetchRoute(
      MapboxFeature feature,
      bool alternatives,
      ) async {
    if (feature == null) {
      print("Attempted to navigate but feature was null.");
      return null;
    }

    try {
      final position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      // Call the API with `alternatives` query param
      final responseJson = await mapService.getRoutesJson(
        fromLat: position.latitude,
        fromLng: position.longitude,
        toLat: feature.latitude,
        toLng: feature.longitude,
        alternatives: alternatives,
      );

      print("Response JSON: $responseJson");
      if (alternatives) {
        // Extract all routes
        final List<List<List<double>>> alternativeRoutes = [];

        final routes = responseJson['routes'] as List<dynamic>?;

        if (routes != null) {
          for (var route in routes) {
            final coordinates = route['coordinates'] as List<dynamic>?;
            if (coordinates != null) {
              alternativeRoutes.add(
                coordinates.map<List<double>>((point) {
                  if (point is List && point.length >= 2) {
                    return [point[0].toDouble(), point[1].toDouble()];
                  } else {
                    throw Exception('Unexpected point format: $point');
                  }
                }).toList(),
              );
            }
          }
        }
      }
      return responseJson;
    } catch (e) {
      print("Navigation error: $e");
    }
    return null;
  }

  /// Parses a single route object into a usable format for display and navigation.
  /// Extracts steps, coordinates, color, and accessibility score.
  Map<dynamic, dynamic>? getRoute(dynamic routeObject) {
    if (routeObject == null ||
        routeObject['coordinates'] == null ||
        routeObject['coordinates'] is! List) {
      emit(state.copyWith(errorMessageGetter: () => 'Route data is invalid'));
      return null;
    }

    final coordinates = routeObject['coordinates'] as List;

    // Convert [lng, lat] to [lat, lng] for Mapbox compatibility
    final fixedLineCoordinates =
    coordinates.map<List<double>>((c) {
      if (c is List && c.length >= 2) {
        return [c[1].toDouble(), c[0].toDouble()]; // lat, lng for Mapbox
      } else {
        throw Exception('Invalid coordinate format');
      }
    }).toList();

    // Extract additional route metadata
    final instructionsList = routeObject['instructions'];
    final accessibilityScore = routeObject['accessibilityScore'];
    final colorHex = routeObject['color'];
    final List<NavigationStep> routeSteps = [];

    // Parse instructions into step objects
    if (instructionsList is List) {
      for (final step in instructionsList) {
        try {
          routeSteps.add(NavigationStep.fromJson(step as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    return {
      'coordinates': fixedLineCoordinates,
      'routeSteps': routeSteps,
      'accessibilityScore': accessibilityScore,
      'color': colorHex,
    };
  }

  /// Displays multiple alternative routes on the map.
  /// Each route is added as a separate line layer with a color based on accessibility score.
  Future<void> _onDisplayAlternativeRoutes(DisplayAlternativeRoutes event, Emitter<MapState> emit,) async {
    try {
      final map = state.mapController;
      if (map == null) {
        emit(
          state.copyWith(errorMessageGetter: () => 'Map controller not ready'),
        );
        return;
      }

      final route = await _fetchRoute(event.feature, true);
      final routes = route!['routes'] as List<dynamic>?;
      var alternativeRoutes = [];

      await _remove(); // Clear previous route layers

      for (int i = 0; i < routes!.length; i++) {
        final route = routes[i];
        final r = getRoute(route);
        final coordinates = r!['coordinates'];
        final List<NavigationStep> routeSteps = r['routeSteps'];
        final accessibilityScore = r['accessibilityScore'];

        // Add line to map
        await _addLine(coordinates, i, accessibilityScore);
        alternativeRoutes.add(r);
      }

      // Emit updated state with alternative routes
      emit(
        state.copyWith(
          errorMessageGetter: () => null,
          alternativeRoutes: alternativeRoutes,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          errorMessageGetter: () => 'Error displaying alternative routes: $e',
        ),
      );
    }
  }

  /// Adds a single route line to the map using a specific color.
  /// Uses the index `i` to create unique IDs for source/layer to avoid conflicts.
  Future<void> _addLine(
      List<dynamic> fixedRoute,
      int i,
      double? accessibilityScore,
      ) async {
    final style = state.mapController?.style;

    final sourceId = 'alt-route-source-$i';
    final layerId = 'alt-route-layer-$i';
    print("Adding line with color: $accessibilityScore");

    final List<int> routeColors = [
      Colors.blue.value,
      Colors.green.value,
      Colors.red.value,
      Colors.orange.value,
      Colors.purple.value,
    ];

    // Ensure coordinates are in [lng, lat] format for GeoJSON
    fixedRoute = fixedRoute.map((coord) => [coord[1], coord[0]]).toList();

    final geojson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": fixedRoute},
          "properties": {},
        },
      ],
    };

    print(fixedRoute);

    // Add route as a new source and layer
    await style?.addSource(
      mapbox.GeoJsonSource(id: sourceId, data: jsonEncode(geojson)),
    );

    await style?.addLayer(
      mapbox.LineLayer(
        id: layerId,
        sourceId: sourceId,
        lineColor: makeColor(accessibilityScore!).toARGB32(),
        lineWidth: 4.0,
        lineJoin: mapbox.LineJoin.ROUND,
        lineCap: mapbox.LineCap.ROUND,
      ),
    );
  }

  /// Handles event to remove all displayed alternative routes from the map.
  Future<void> _onRemoveAlternativeRoutes(
      RemoveAlternativeRoutes event,
      Emitter<MapState> emit,
      ) async {
    await _remove();
  }

  /// Removes all map layers and sources related to alternative routes.
  /// Iterates through numbered layers until none are found.
  Future<void> _remove() async {
    final style = state.mapController?.style;
    if (style == null) return;

    int i = 0;
    while (true) {
      final layerId = 'alt-route-layer-$i';
      final sourceId = 'alt-route-source-$i';
      bool removedAnything = false;

      if ((await style.styleLayerExists(layerId))) {
        print("Removing layer: $layerId");
        await style.removeStyleLayer(layerId);
        removedAnything = true;
      }

      if ((await style.styleSourceExists(sourceId))) {
        print("Removing source: $sourceId");
        await style.removeStyleSource(sourceId);
        removedAnything = true;
      }

      if (!removedAnything) break;
      i++;
    }
  }

  /// Converts an accessibility score (0.0 - 1.0) into a color.
  /// Used to visually differentiate routes based on their accessibility level.
  Color makeColor(double accessibilityScore) {
    if (accessibilityScore == 0) return Colors.blue;
    if (accessibilityScore < 0.4) return Colors.red;
    if (accessibilityScore < 0.7) return Colors.yellow;
    if (accessibilityScore >= 0.7) return Colors.green;
    return Colors.red;
  }
}
