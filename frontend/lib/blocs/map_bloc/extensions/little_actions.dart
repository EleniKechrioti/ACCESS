part of '../map_bloc.dart';

/// Extension on MapBloc to handle quick user actions like sharing location or launching the phone dialer.
extension MapBlocActions on MapBloc {

  /// Opens Google Maps with a search query for the provided location string.
  /// Emits [ActionCompleted] on success or [ActionFailed] on failure.
  Future<void> _onShareLocation(ShareLocationRequested event, Emitter<MapState> emit,) async {
    try {
      // Encode the location for safe use in a URL
      final encodedLocation = Uri.encodeComponent(event.location);
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedLocation';

      // Open the URL in the user's default browser or maps app
      await launchUrl(Uri.parse(googleMapsUrl));

      // Emit success state
      emit(ActionCompleted());
    } catch (e) {
      // Emit failure state with a user-friendly message
      emit(ActionFailed("Αποτυχία διαμοιρασμού τοποθεσίας"));
    }
  }

  /// Launches the phone dialer with the provided phone number.
  /// Emits [ActionCompleted] on success or [ActionFailed] on failure.
  Future<void> _onLaunchPhoneDialer(LaunchPhoneDialerRequested event, Emitter<MapState> emit,) async {
    try {
      // Format the phone number into a tel: URI
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: event.phoneNumber,
      );

      // Launch the dialer app with the number pre-filled
      await launchUrl(launchUri);

      // Emit success state
      emit(ActionCompleted());
    } catch (e) {
      // Emit failure state with a user-friendly message
      emit(ActionFailed("Αποτυχία κλήσης τηλεφώνου"));
    }
  }
}
