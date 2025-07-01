part of 'map_bloc.dart';

/// Base abstract class for all map-related events.
/// Extends Equatable for value equality.
abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object> get props => [];
}

/// Event to trigger loading the map widget.
class LoadMap extends MapEvent {
  const LoadMap();
}

/// Event to add a custom marker at given coordinates on the map.
/// Coordinates must be a list of two doubles: [longitude, latitude].
class AddCustomMarker extends MapEvent {
  final List<double> coordinates;
  const AddCustomMarker(this.coordinates);
}

/// Event to load clusters of markers onto the map.
/// Clusters is a list of lists, structure depends on implementation.
class LoadClusters extends MapEvent {
  final List<List<dynamic>> clusters;
  const LoadClusters(this.clusters);
}
