part of '../map_bloc.dart';

/// Extension on MapBloc for handling user's rating of self-mapped routes and navigation.
extension MapBlocRatings on MapBloc {

  /// Handles saving a rated route to Firestore.
  /// Stops current tracking, checks if user is logged in,
  /// then uploads the route data and rating to the database.
  Future<void> _onRateAndSaveRouteRequested(RateAndSaveRouteRequested event,
      Emitter<MapState> emit) async {
    // Stop any ongoing tracking logic first
    await _stopTrackingLogic();

    // Check if user is authenticated
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print("User not logged in, cannot save rated route.");
      // Emit error state if no user logged in
      emit(state.copyWith(
        isTracking: false,
        trackingStatus: MapTrackingStatus.error,
        errorMessageGetter: () => 'User not logged in to save route.',
      ));
      return;
    }

    try {
      print("Saving rated route to Firestore for user ${currentUser.uid}...");

      // Prepare the route points data for Firestore
      final List<Map<String, dynamic>> routeForFirestore = event.route.map((
          pos) =>
      {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'altitude': pos.altitude,
        'accuracy': pos.accuracy,
        'speed': pos.speed,
        'timestamp': pos.timestamp?.toIso8601String(),
      }).toList();

      // Compose the data object to save
      final Map<String, dynamic> ratedRouteData = {
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'rating': event.rating,
        'routePoints': routeForFirestore,
        'pointCount': event.route.length,
        'createdAt': FieldValue.serverTimestamp(),
        'needsUpdate': true,
      };

      // Save to Firestore collection 'rated_routes'
      await _firestore.collection('rated_routes').add(ratedRouteData);
      print("Rated route saved successfully!");

      // Emit success state to clear errors and stop tracking
      emit(state.copyWith(
        isTracking: false,
        trackingStatus: MapTrackingStatus.stopped,
        errorMessageGetter: () => null,
        lastEvent: null,
      ));
    } catch (e) {
      print("Error saving rated route: $e");
      // Emit error state if saving fails
      emit(state.copyWith(
        isTracking: false,
        trackingStatus: MapTrackingStatus.error,
        errorMessageGetter: () => 'Failed to save rated route: $e',
      ));
    }
  }

  /// Emits the state to trigger showing the route rating dialog.
  Future<void> _onShowRouteRatingDialogRequested(ShowRouteRatingDialogRequested event, Emitter<MapState> emit,) async {
    emit(state.copyWith(lastEvent: event));
  }

}
