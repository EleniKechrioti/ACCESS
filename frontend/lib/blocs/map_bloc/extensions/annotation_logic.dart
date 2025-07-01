part of '../map_bloc.dart';

/// Extension on MapBloc for handling all annotation-related logic.
/// This includes markers for user input, category features, favorites, and clustered reports.
extension MapBlocAnnotations on MapBloc {
  /// Handles the AddMarker event by placing a single marker at the given lat/lng.
  /// Deletes previous user-added markers before adding a new one.
  Future<void> _onAddMarker(AddMarker event, Emitter<MapState> emit) async {
    final map = state.mapController;
    if (map == null || _annotationManager == null) return;
    if (state is! MapAnnotationClicked) {
      try {
        final bytes = await rootBundle.load('assets/images/pin.png');
        final imageData = bytes.buffer.asUint8List();
        final point = mapbox.Point(
          coordinates: mapbox.Position(event.longitude, event.latitude),
        );

        await _annotationManager!.deleteAll();
        await _annotationManager!.create(
          mapbox.PointAnnotationOptions(
            geometry: point,
            iconSize: 0.5,
            image: imageData,
            iconAnchor: mapbox.IconAnchor.BOTTOM,
          ),
        );
      } catch (e) {
        print("Error adding marker: $e");
      }
    }
  }

  /// Deletes all user-added markers (from long tap).
  Future<void> _onDeleteMarker(DeleteMarker event, Emitter<MapState> emit) async {
    await _annotationManager?.deleteAll();
  }

  /// Handles adding multiple category markers (POIs) to the map.
  /// Optionally zooms to fit all markers in view.
  Future<void> _onAddCategoryMarkers(AddCategoryMarkers event, Emitter<MapState> emit) async {
    final map = state.mapController;
    if (map == null || _categoryAnnotationManager == null) return;

    try {
      final bytes = await rootBundle.load('assets/images/pin.png');
      final imageData = bytes.buffer.asUint8List();
      List<mapbox.PointAnnotationOptions> optionsList = [];

      double? minLat, maxLat, minLng, maxLng;

      for (final feature in event.features) {
        final point = mapbox.Point(
          coordinates: mapbox.Position(feature.longitude, feature.latitude),
        );
        optionsList.add(
          mapbox.PointAnnotationOptions(
            geometry: point,
            iconSize: 0.4,
            image: imageData,
            iconAnchor: mapbox.IconAnchor.BOTTOM,
            textField: feature.name,
            textSize: 10,
            textMaxWidth: 15,
          ),
        );

        // Update bounds for auto-zoom
        final lat = feature.latitude;
        final lng = feature.longitude;
        minLat = minLat == null ? lat : min(minLat, lat);
        maxLat = maxLat == null ? lat : max(maxLat, lat);
        minLng = minLng == null ? lng : min(minLng, lng);
        maxLng = maxLng == null ? lng : max(maxLng, lng);
      }

      await _categoryAnnotationManager!.deleteAll();
      createdAnnotations = await _categoryAnnotationManager!.createMulti(optionsList);

      // Map annotation IDs to features
      final Map<String, String> idMap = {};
      final Map<String, MapboxFeature> featureMap = {};
      if (createdAnnotations.length == event.features.length) {
        for (int i = 0; i < createdAnnotations.length; i++) {
          final internalId = createdAnnotations[i]!.id;
          final correctMapboxId = event.features[i].id;
          final feature = event.features[i];
          if (correctMapboxId.isNotEmpty) {
            idMap[internalId] = correctMapboxId;
            featureMap[correctMapboxId] = feature;
          }
        }
      } else {
        print("Mismatch between annotations and features.");
      }

      emit(state.copyWith(
        categoryAnnotations: Set.from(createdAnnotations),
        annotationIdMap: idMap,
        featureMap: featureMap,
      ));


      if (event.shouldZoomToBounds && minLat != null && maxLat != null &&
          minLng != null && maxLng != null) {
        final southwest = mapbox.Point(
            coordinates: mapbox.Position(minLng, minLat));
        final northeast = mapbox.Point(
            coordinates: mapbox.Position(maxLng, maxLat));
        final bounds = mapbox.CoordinateBounds(
            southwest: southwest, northeast: northeast, infiniteBounds: false);

        final cameraOptions = await map.cameraForCoordinateBounds(
          bounds,
          mapbox.MbxEdgeInsets(top: 50.0, left: 50.0, bottom: 50.0, right: 50.0),
          0.0, 0.0, null, null,
        );

        if (cameraOptions != null) {
          map.flyTo(cameraOptions, mapbox.MapAnimationOptions(duration: 1000));
        }
      }
    } catch (e) {
      print("Error adding category markers: $e");
    }
  }

  /// Emits the event when an internal annotation is clicked (e.g. category marker).
  void _onAnnotationClickedInternal(_AnnotationClickedInternal event, Emitter<MapState> emit) {
    emit(MapAnnotationClicked(event.mapboxId, event.feature, state));
  }

  /// Clears all category annotations from the map and state.
  Future<void> _onClearCategoryMarkers(ClearCategoryMarkers event, Emitter<MapState> emit) async {
    await _categoryAnnotationManager?.deleteAll();
    emit(state.copyWith(categoryAnnotations: {}));
  }

  /// Loads and displays favorite annotations based on saved user data (e.g., from Firestore).
  Future<void> _onRenderFavoriteAnnotations(RenderFavoriteAnnotations event, Emitter<MapState> emit) async {
    while (_favoritesAnnotationManager == null) {
      if (state.mapController == null) {
        await Future.delayed(Duration(milliseconds: 100));
        continue;
      }
      _favoritesAnnotationManager = await state.mapController!.annotations
          .createPointAnnotationManager(id: 'favorites-layer');
    }
    if (_favoritesAnnotationManager == null) return;

    final bytes = await rootBundle.load('assets/images/star.png');
    final imageData = bytes.buffer.asUint8List();

    final annotations = event.favorites.entries.map((entry) {
      final data = entry.value as Map<String, dynamic>;
      final lat = data['location']['lat'] as double;
      final lng = data['location']['lng'] as double;

      return mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
        iconSize: 0.1,
        image: imageData,
        iconAnchor: mapbox.IconAnchor.CENTER,
      );
    }).toList();

    await _favoritesAnnotationManager!.deleteAll();
    await _favoritesAnnotationManager!.createMulti(annotations);
  }

  /// Loads clusters from the backend and places markers for each cluster on the map.
  Future<void> _onLoadClusters(LoadClusters event, Emitter<MapState> emit) async {
    try {
      final url = 'http://192.168.1.69:9090/setreport';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final rawData = json.decode(response.body);
        final clusters = _processClusters(rawData);

        if (clusters.isNotEmpty) {
          final idMap = await _addClusterMarkers(clusters);
          emit(state.copyWith(clusters: clusters, clusterAnnotationIdMap: idMap));
        } else {
          debugPrint('No clusters found.');
        }
      } else {
        debugPrint('Server error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error: $e');
    } on TimeoutException {
      debugPrint('Timeout - no response from server.');
    } catch (e) {
      debugPrint('Unexpected error: $e');
    }
  }

  /// Parses raw JSON from the backend into a list of report clusters.
  List<List<Map<String, dynamic>>> _processClusters(dynamic rawClusters) {
    try {
      final List clustersList = rawClusters as List;
      return clustersList.map<List<Map<String, dynamic>>>((cluster) {
        return (cluster as List).map<Map<String, dynamic>>((report) {
          final data = report as Map<String, dynamic>;
          return {
            'id': data['id'] ?? '',
            'timestamp': _formatTimestamp(data['timestamp'] ?? ''),
            'latitude': (data['latitude'] as num?)?.toDouble() ?? 0.0,
            'longitude': (data['longitude'] as num?)?.toDouble() ?? 0.0,
            'obstacleType': data['obstacleType'] ?? '',
            'locationDescription': data['locationDescription'] ?? '',
            'imageUrl': data['imageUrl'] ?? '',
            'accessibility': data['accessibility'] ?? '',
            'description': data['description'] ?? '',
            'userId': data['userId'] ?? '',
            'userEmail': data['userEmail'] ?? '',
          };
        }).toList();
      }).toList();
    } catch (e) {
      debugPrint('Error processing cluster data: $e');
      return [];
    }
  }

  /// Formats ISO timestamps into a readable DD/MM/YYYY HH:MM format.
  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    } catch (_) {
      return timestamp;
    }
  }

  /// Places cluster markers on the map and returns a map of annotation ID to cluster index.
  Future<Map<String, int>?> _addClusterMarkers(List<List<Map<String, dynamic>>> clusters) async {
    if (_clusterAnnotationManager == null) {
      if (state.mapController == null) return null;
      _clusterAnnotationManager = await state.mapController!.annotations
          .createPointAnnotationManager(id: 'clusters-layer');
    }
    if (_clusterAnnotationManager == null) return null;

    final bytes = await rootBundle.load('assets/images/report_pin.png');
    final imageData = bytes.buffer.asUint8List();

    final optionsList = clusters.map((cluster) {
      final first = cluster.first;
      return mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position(first['longitude'], first['latitude']),
        ),
        iconSize: 0.2,
        image: imageData,
        iconAnchor: mapbox.IconAnchor.BOTTOM,
      );
    }).toList();

    await _clusterAnnotationManager!.deleteAll();
    final annotations = await _clusterAnnotationManager!.createMulti(optionsList);

    final Map<String, int> idMap = {};
    for (int i = 0; i < annotations.length; i++) {
      idMap[annotations[i]!.id] = i;
    }
    return idMap;
  }

  /// Emits state to show reports for a clicked cluster.
  void _onClusterMarkerClicked(ClusterMarkerClicked event, Emitter<MapState> emit) {
    emit(ClusterAnnotationClicked(event.reports, state));
    emit(state.copyWith(
      showClusterReports: true,
      clusterReports: event.reports,
      lastEvent: event,
    ));
  }

  /// Hides the cluster report view and clears data from state.
  void _onHideClusterReports(HideClusterReports event, Emitter<MapState> emit) {
    emit(state.copyWith(
      showClusterReports: false,
      clusterReports: null,
    ));
  }
}
