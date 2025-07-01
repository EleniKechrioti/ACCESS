part of '../map_bloc.dart';

/// Extension on MapBloc for listening to location changes.
extension MapBlocLocation on MapBloc {

  /// Starts listening to location updates.
  /// Requests location permission first, then subscribes to position stream.
  /// Calls the provided callback `onPositionUpdate` for each new position.
  Future<void> startLocationListening({required Function(geolocator.Position) onPositionUpdate}) async {
    // Request location permission
    final permissionStatus = await Permission.locationWhenInUse.request();

    // If permission granted or limited, start streaming location updates
    if (permissionStatus.isGranted || permissionStatus.isLimited) {
      const locationSettings = geolocator.LocationSettings(
        accuracy: geolocator.LocationAccuracy.high,
        distanceFilter: 5, // Update only when moved at least 5 meters
      );
      try {
        // Subscribe to the position stream with error handling
        _positionSubscription = geolocator.Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).handleError((error) {
          print("Error in location stream: $error");
          _positionSubscription?.cancel();
        }).listen((position) {
          // Trigger callback with new position
          onPositionUpdate(position);
        });
        print("Location listening started...");
      } catch (e) {
        print("Error starting location stream: $e");
        _positionSubscription?.cancel();
      }
    } else {
      print("Location permission denied");
    }
  }

  /// Stops listening to location updates by cancelling the subscription.
  Future<void> stopLocationListening() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Handles incoming location update events.
  /// Updates the tracked route list and current tracked position in state.
  void _onLocationUpdated(_LocationUpdated event, Emitter<MapState> emit) {
    if (!state.isTracking) return;

    // Create a new list from existing trackedRoute and append new position
    final updatedRoute = List<geolocator.Position>.from(state.trackedRoute)
      ..add(event.newPosition);

    // Emit updated state with new current position and extended tracked route
    emit(state.copyWith(
      currentTrackedPositionGetter: () => event.newPosition,
      trackedRoute: updatedRoute,
    ));
  }
}
