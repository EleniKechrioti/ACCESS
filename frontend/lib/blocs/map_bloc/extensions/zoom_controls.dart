part of '../map_bloc.dart';

/// Extension on MapBloc for handling all tiny buttons on the map.
/// This includes zoom-in, zoom-out, find my location, start/stop independent mapping.
extension MapBlocZoom on MapBloc {

  /// Handles getting the current device location.
  /// Requests location permission if not granted.
  /// If navigating, toggles camera follow mode and compass listener.
  /// Otherwise, moves map camera to current position with zoom 16.
  Future<void> _onGetCurrentLocation(GetCurrentLocation event, Emitter<MapState> emit) async {
    try {
      var status = await Permission.locationWhenInUse.status;

      // Request permission if not granted
      if (!status.isGranted && !status.isLimited) {
        print("GetCurrentLocation: Permission not granted. Requesting...");
        status = await Permission.locationWhenInUse.request();

        if (!status.isGranted && !status.isLimited) {
          print("GetCurrentLocation: Permission denied after request.");
          emit(state.copyWith(
              errorMessageGetter: () => 'Απαιτείται άδεια τοποθεσίας.'));
          return;
        }
      }

      // Get current position using Geolocator
      final position = await _geolocator.getCurrentPosition();
      final point = mapbox.Point(
          coordinates: mapbox.Position(position.longitude, position.latitude));

      if (state.isNavigating) {
        // Toggle camera follow mode when navigating
        final bool nowFollowing = !state.isCameraFollowing;

        if (nowFollowing) {
          startCompassListener();
          _changeCamera(0, true);
        } else {
          _compassSubscription.cancel();
          _changeCamera(0, false);
        }

        emit(state.copyWith(isCameraFollowing: nowFollowing));
      } else {
        // Fly camera to current position with zoom 16
        state.mapController?.flyTo(
          mapbox.CameraOptions(center: point, zoom: 16.0),
          mapbox.MapAnimationOptions(duration: 1000),
        );
      }

      emit(state.copyWith(zoomLevel: 16.0));
    } catch (e) {
      print("Error getting current location: $e");
      emit(state.copyWith(
          errorMessageGetter: () => 'Αδυναμία λήψης τρέχουσας τοποθεσίας: $e'));
    }
  }

  /// Zooms in by increasing the current zoom level by 1.
  Future<void> _onZoomIn(ZoomIn event, Emitter<MapState> emit) async {
    final currentZoom = await state.mapController?.getCameraState();
    final newZoom = (currentZoom?.zoom ?? state.zoomLevel) + 1;

    state.mapController?.flyTo(
      mapbox.CameraOptions(zoom: newZoom),
      mapbox.MapAnimationOptions(duration: 500),
    );

    emit(state.copyWith(zoomLevel: newZoom));
  }

  /// Zooms out by decreasing the current zoom level by 1.
  Future<void> _onZoomOut(ZoomOut event, Emitter<MapState> emit) async {
    final currentZoom = await state.mapController?.getCameraState();
    final newZoom = (currentZoom?.zoom ?? state.zoomLevel) - 1;

    state.mapController?.flyTo(
      mapbox.CameraOptions(zoom: newZoom),
      mapbox.MapAnimationOptions(duration: 500),
    );

    emit(state.copyWith(zoomLevel: newZoom));
  }

  /// Starts tracking user location:
  /// - Clears any previous tracked route
  /// - Sets tracking flags
  /// - Starts listening to location updates
  Future<void> _onStartTrackingRequested(StartTrackingRequested event, Emitter<MapState> emit) async {
    emit(state.copyWith(
      trackedRoute: [],
      isTracking: true,
      trackingStatus: MapTrackingStatus.loading,
    ));

    await stopLocationListening();
    await startLocationListening(
      onPositionUpdate: (position) {
        if (!state.isTracking) return;
        add(_LocationUpdated(position));
      },
    );
    emit(state.copyWith(trackingStatus: MapTrackingStatus.tracking));
  }

  /// Stops tracking user location:
  /// - Calls internal logic to stop subscription
  /// - Updates state flags
  Future<void> _onStopTrackingRequested(StopTrackingRequested event, Emitter<MapState> emit) async {
    await _stopTrackingLogic();
    emit(state.copyWith(
      isTracking: false,
      trackingStatus: MapTrackingStatus.stopped,
    ));
    print("Tracking stopped (without rating). Final points: ${state.trackedRoute.length}");
  }

  /// Internal logic to cancel location subscription safely.
  Future<void> _stopTrackingLogic() async {
    print("Stopping location subscription...");
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
