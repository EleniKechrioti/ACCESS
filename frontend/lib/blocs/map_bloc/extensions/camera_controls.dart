part of '../map_bloc.dart';

/// Extension on MapBloc to handle camera movement and orientation logic.
extension MapBlocCamera on MapBloc {

  /// Handles the FlyTo event by animating the camera to a specific location.
  /// Used when the user selects a location or initiates a navigation.
  Future<void> _onFlyTo(FlyTo event, Emitter<MapState> emit) async {
    final point = mapbox.Point(
        coordinates: mapbox.Position(event.longitude, event.latitude));
    state.mapController?.flyTo(
      mapbox.CameraOptions(center: point, zoom: 16.0),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  /// Changes the camera view based on the user's current location and heading.
  /// If followMode is true, the camera follows the user's direction.
  /// Pitch and zoom are adjusted depending on whether navigation is active.
  Future<void> _changeCamera(double heading, bool? followMode) async {
    final point = await geolocator.Geolocator.getCurrentPosition();
    final bool isFollowing = followMode ?? state.isCameraFollowing;
    final pitch = state.isNavigating && isFollowing ? 60.0 : 0.0;
    final zoom = state.isNavigating && isFollowing ? 20.0 : 16.0;
    state.mapController?.easeTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
            coordinates: mapbox.Position(point.longitude, point.latitude)),
        bearing: isFollowing ? heading : 0,
        zoom: zoom,
        pitch: pitch,
      ),
      mapbox.MapAnimationOptions(duration: 300),
    );
  }

  /// Starts listening to compass heading updates.
  /// If camera following is enabled, updates the camera bearing based on heading.
  void startCompassListener() {
    _compassSubscription = FlutterCompass.events!.listen((event) {
      final double? heading = event.heading;
      if (heading == null || !state.isCameraFollowing) return;
      _changeCamera(heading, true);
    });
  }
}
