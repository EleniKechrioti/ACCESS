part of '../map_bloc.dart';

/// Extension on MapBloc for handling all navigation-related logic.
 /// This starting, stopping, progress tracking and redirection.
extension MapBlocNavigation on MapBloc {

  /// Handles starting navigation to a selected feature.
  /// Fetches the route, sets up the map with the route line, resets tracking,
  /// starts listening for location updates and compass changes.
  Future<void> _onStartNavigation(StartNavigationRequested event, Emitter<MapState> emit,) async {
    print("got inn");

    // Fetch route data including alternatives if requested
    final responseJson = await _fetchRoute(event.feature, event.alternatives);

    // Extract main route object from response
    final routeObject = responseJson?['route'];
    final route = getRoute(routeObject);

    // Extract navigation steps from route
    final List<NavigationStep> routeSteps = route!['routeSteps'];

    // Clear any existing route lines on the map
    await _remove();

    // Add new route line to the map
    final fixedLineCoordinates = route['coordinates'];
    await _addLine(fixedLineCoordinates, 0, 0);

    // Update state to reflect navigation started
    emit(state.copyWith(
      isNavigating: true,
      currentStepIndex: 0,
      isCameraFollowing: true,
      isOffRoute: false,
      trackedRoute: [],
      routeSteps: routeSteps,
    ));

    // Reset location listeners and start new ones for navigation
    await stopLocationListening();
    startCompassListener();
    await startLocationListening(onPositionUpdate: (position) => add(NavigationPositionUpdated(position, event.feature)));
  }


  /// Updates the current navigation step index.
  /// Speaks the instruction aloud if voice instructions are enabled.
  Future<void> _updateNavigationStep(int newStepIndex, Emitter<MapState> emit) async {
    print("Trying to update step: $newStepIndex");
    print("Current step in state: ${state.currentStepIndex}");

    // Ignore if not navigating or step hasn't changed
    if (!state.isNavigating || newStepIndex == state.currentStepIndex) return;

    // Update the step index in state
    emit(state.copyWith(currentStepIndex: newStepIndex));
    print("Updated step to: $newStepIndex");

    // Speak instruction aloud if voice is enabled
    if (state.isVoiceEnabled && newStepIndex < state.routeSteps.length) {
      await flutterTts.speak(state.routeSteps[newStepIndex].instruction);
    }
  }

  /// Stops navigation.
  /// Shows route rating dialog, clears route data, stops camera follow,
  /// removes alternative routes and stops compass subscription.
  Future<void> _onStopNavigation(StopNavigationRequested event, Emitter<MapState> emit,) async {
    add(ShowRouteRatingDialogRequested(state.trackedRoute));
    emit(state.copyWith(
        isNavigating: false,
        routeSteps: [],
        currentStepIndex: 0,
        isCameraFollowing: false,
        lastEvent: null
    ));
    add(RemoveAlternativeRoutes());
    _changeCamera(0, false);
    _compassSubscription.cancel();
  }

  /// Called when user position updates during navigation.
  /// Finds the closest navigation step and updates current step.
  /// Detects if user is off-route and attempts to reroute.
  /// Detects if user reached destination and stops navigation.
  Future<void> _onNavigationPositionUpdated(NavigationPositionUpdated event, Emitter<MapState> emit,) async {
    // Ignore if not navigating or no steps
    if (!state.isNavigating || state.routeSteps.isEmpty) return;

    // Convert current position to Mapbox Point
    final currentPosition = mapbox.Point(
      coordinates: mapbox.Position(
        event.position.longitude,
        event.position.latitude,
      ),
    );

    // Find closest navigation step by distance
    int closestStepIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < state.routeSteps.length; i++) {
      final stepPoint = state.routeSteps[i].location;
      final dist = distanceBetweenPoints(currentPosition, stepPoint);
      if (dist < minDistance) {
        minDistance = dist;
        closestStepIndex = i;
      }
    }

    const double offRouteThreshold = 10.0;

    // Handle off-route detection and rerouting
    if (minDistance > offRouteThreshold) {
      if(!state.isOffRoute) {
        emit(state.copyWith(isOffRoute: true));
        print("User is off-route! $minDistance meters away");

        // Try fetching a new route from current position
        final responsejson = await _fetchRoute(event.feature, false);

        if (responsejson != null) {
          const sourceId = 'route-source';
          const layerId = 'route-layer';

          // Remove old route layers and sources gracefully
          await state.mapController?.style
              .removeStyleLayer(layerId)
              .catchError((_) {});
          await state.mapController?.style
              .removeStyleSource(sourceId)
              .catchError((_) {});

          // Add the new route line
          final routeObject = responsejson['route'];
          final route = getRoute(routeObject);
          final List<NavigationStep> routeSteps = route!['routeSteps'];
          await _remove();
          final fixedLineCoordinates = route['coordinates'];
          await _addLine(fixedLineCoordinates, 0, 0);

          // Notify user that rerouting is happening
          final instruction = "Έχετε αφήσει την πορεία σας. Επιστρέφω σε"
              "${state.routeSteps[closestStepIndex].instruction}";

          if (state.isVoiceEnabled) {
            await flutterTts.speak(instruction);
          }
        } else {
          print("Αδυναμία εύρεσης νέας διαδρομής.");
          if (state.isVoiceEnabled) {
            await flutterTts.speak(
                "Αδυναμία να βρεθεί μια νέα διαδρομή. Προσπαθήστε να επιστρέψετε στην προηγούμενη κατεύθυνση.");
          }
        }
      }
      return;
    } else {
      // User is back on route, clear off-route flag and stop any voice prompts
      if (state.isOffRoute) {
        emit(state.copyWith(isOffRoute: false));
        if (state.isVoiceEnabled) {
          await flutterTts.speak("");
        }
      }
    }

    // Check if user is close enough to the destination to stop navigation
    final lastStep = state.routeSteps.last;
    final destinationDistance = distanceBetweenPoints(currentPosition, lastStep.location);
    const double destinationThreshold = 5.0;

    if (destinationDistance <= destinationThreshold) {
      print("User reached destination, stopping navigation...");

      // Trigger navigation stop event
      add(StopNavigationRequested());

      // Speak confirmation if voice enabled
      if (state.isVoiceEnabled) {
        await flutterTts.speak("Έχετε φτάσει στον προορισμό σας.");
      }
    }

    // Update current navigation step based on closest step
    await _updateNavigationStep(closestStepIndex, emit);

    // Add current position to tracked route list
    final updatedTrackedRoute = List<geolocator.Position>.from(state.trackedRoute)
      ..add(event.position);

    // Emit updated state with new tracked route
    emit(state.copyWith(trackedRoute: updatedTrackedRoute));
  }
}
