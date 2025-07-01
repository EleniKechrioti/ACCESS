part of 'map_bloc.dart';

/// Base class for all events handled by the MapBloc.
/// Every interaction or system update related to the map triggers one of these.
abstract class MapEvent {}

/// Requests location permission from the user at runtime.
class RequestLocationPermission extends MapEvent {}

/// Retrieves the current geolocation of the user.
class GetCurrentLocation extends MapEvent {}

/// Zooms in on the map.
class ZoomIn extends MapEvent {}

/// Zooms out on the map.
class ZoomOut extends MapEvent {}

/// Initializes the map with a provided Mapbox controller.
/// This sets up annotation managers, click listeners, and more.
class InitializeMap extends MapEvent {
  final mapbox.MapboxMap mapController;
  InitializeMap(this.mapController);
}

/// Moves the camera to a specific latitude and longitude using fly-to animation.
class FlyTo extends MapEvent {
  final double latitude;
  final double longitude;
  FlyTo(this.latitude, this.longitude);
}

/// Adds a marker to the map at the specified location.
class AddMarker extends MapEvent {
  final double latitude;
  final double longitude;
  AddMarker(this.latitude, this.longitude);
}

/// Deletes all user-added markers from the map.
class DeleteMarker extends MapEvent {}

/// Adds a set of markers based on a list of Mapbox features.
/// Optionally zooms to fit all the added markers in view.
class AddCategoryMarkers extends MapEvent {
  final List<MapboxFeature> features;
  final bool shouldZoomToBounds;
  AddCategoryMarkers(this.features, {this.shouldZoomToBounds = false});
}

/// Internal event triggered when a category marker is clicked.
/// Used to differentiate between different annotations on the map.
class _AnnotationClickedInternal extends MapEvent {
  final String mapboxId;
  final MapboxFeature feature;

  _AnnotationClickedInternal(this.mapboxId, this.feature);

  @override
  List<Object> get props => [mapboxId];
}

/// Clears all category-related markers from the map.
class ClearCategoryMarkers extends MapEvent {}

/// Starts tracking the user's real-time location.
class StartTrackingRequested extends MapEvent {}

/// Stops real-time location tracking.
class StopTrackingRequested extends MapEvent {}

/// Saves the completed route along with a user-provided rating.
class RateAndSaveRouteRequested extends MapEvent {
  final double rating;
  final List<geolocator.Position> route;
  RateAndSaveRouteRequested({required this.rating, required this.route});

  @override
  List<Object?> get props => [rating, route];
}

/// Internal event triggered when the user's location is updated.
class _LocationUpdated extends MapEvent {
  final geolocator.Position newPosition;
  _LocationUpdated(this.newPosition);
}

/// Displays alternative routes for a selected destination feature.
class DisplayAlternativeRoutes extends MapEvent {
  final MapboxFeature feature;
  DisplayAlternativeRoutes(this.feature);

  @override
  List<Object?> get props => [feature];
}

/// Removes any currently displayed alternative routes from the map.
class RemoveAlternativeRoutes extends MapEvent {}

/// Triggers sharing of a specific location as a string (e.g., coordinates or URL).
class ShareLocationRequested extends MapEvent {
  final String location;
  ShareLocationRequested(this.location);
}

/// Launches the phone dialer with the provided number.
class LaunchPhoneDialerRequested extends MapEvent {
  final String? phoneNumber;
  LaunchPhoneDialerRequested(this.phoneNumber);
}

/// Starts navigation for a selected feature.
/// Optionally includes alternative routes.
class StartNavigationRequested extends MapEvent {
  final MapboxFeature feature;
  final bool alternatives;

  StartNavigationRequested(this.feature, this.alternatives);

  @override
  List<Object> get props => [feature, alternatives];
}

/// Updates the current step index in the navigation flow.
class UpdateNavigationStep extends MapEvent {
  final int currentStepIndex;
  UpdateNavigationStep(this.currentStepIndex);
}

/// Stops the current navigation session.
class StopNavigationRequested extends MapEvent {}

/// Toggles voice navigation instructions on or off.
class ToggleVoiceInstructions extends MapEvent {}

/// Updates the navigation position with the current user location.
class NavigationPositionUpdated extends MapEvent {
  final geolocator.Position position;
  final MapboxFeature feature;
  NavigationPositionUpdated(this.position, this.feature);
}

/// Triggers the UI to display the route rating dialog after navigation ends.
class ShowRouteRatingDialogRequested extends MapEvent {
  final List<geolocator.Position> trackedRoute;
  ShowRouteRatingDialogRequested(this.trackedRoute);
}

/// Renders favorite annotations on the map using stored favorites data.
class RenderFavoriteAnnotations extends MapEvent {
  final Map<String, dynamic> favorites;
  RenderFavoriteAnnotations(this.favorites);
}

/// Flags that a one-time message has been shown to the user.
class ShowedMessage extends MapEvent {}

/// Loads cluster data to be rendered on the map.
class LoadClusters extends MapEvent {}

/// Triggered when a cluster marker is clicked, passing its associated reports.
class ClusterMarkerClicked extends MapEvent {
  final List<Map<String, dynamic>> reports;
  ClusterMarkerClicked(this.reports);
}

/// Hides the currently visible cluster reports from the UI.
class HideClusterReports extends MapEvent {}
