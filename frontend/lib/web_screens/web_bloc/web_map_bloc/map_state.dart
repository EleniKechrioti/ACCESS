part of 'map_bloc.dart';

/// Base abstract class for all map states.
/// Extends Equatable for value equality.
abstract class MapState extends Equatable {
  const MapState();

  @override
  List<Object> get props => [];
}

/// Initial state before any map action has occurred.
class MapInitial extends MapState {
  const MapInitial();
}

/// State indicating the map is currently loading.
class MapLoading extends MapState {
  const MapLoading();
}

/// State indicating the map has successfully loaded.
class MapLoaded extends MapState {
  const MapLoaded();
}

/// State representing an error occurred while handling the map.
/// Contains an error message describing the failure.
class MapError extends MapState {
  final String message;
  const MapError(this.message);

  @override
  List<Object> get props => [message];
}

/// State representing that clusters of markers have been loaded on the map.
/// Holds a list of clusters; the structure depends on the map implementation.
class MapClustersLoaded extends MapState {
  final List<List<dynamic>> clusters;
  const MapClustersLoaded(this.clusters);

  @override
  List<Object> get props => [clusters];
}
