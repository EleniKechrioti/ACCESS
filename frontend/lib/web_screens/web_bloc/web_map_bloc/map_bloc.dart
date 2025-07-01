import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:html' as html;

part 'map_event.dart';
part 'map_state.dart';

/// Bloc that manages the state of a map widget.
/// Handles loading the map, adding custom markers via JavaScript
/// injection into an iframe, and loading marker clusters.
class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc() : super(const MapInitial()) {
    // Event handler to load the map asynchronously
    on<LoadMap>((event, emit) async {
      emit(const MapLoading());
      try {
        // Simulate map loading delay
        await Future.delayed(const Duration(milliseconds: 100));
        emit(const MapLoaded());
      } catch (e) {
        emit(MapError("Failed to load map: $e"));
      }
    });

    // Event handler to add a custom marker on the map via JS
    on<AddCustomMarker>((event, emit) {
      // Validate coordinates length
      if (event.coordinates.length != 2) {
        emit(MapError("Invalid coordinates"));
        return;
      }

      // JavaScript code to create and add a Mapbox marker
      final markerJs = '''
        new mapboxgl.Marker()
          .setLngLat([${event.coordinates[0]}, ${event.coordinates[1]}])
          .addTo(map);
      ''';

      // Find the iframe with id 'map-iframe' and send JS code to execute
      final iframe = html.document.getElementById('map-iframe') as html.IFrameElement?;
      iframe?.contentWindow?.postMessage({
        'type': 'executeCode',
        'code': markerJs
      }, '*');
    });

    // Event handler to load clusters of markers on the map
    on<LoadClusters>((event, emit) {
      emit(MapClustersLoaded(event.clusters));
    });
  }
}
