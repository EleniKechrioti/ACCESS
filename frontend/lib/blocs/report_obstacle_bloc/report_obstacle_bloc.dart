import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart'; // For Location
import 'package:geocoding/geocoding.dart'; // For address from coordinates

import 'package:supabase_flutter/supabase_flutter.dart';

part 'report_obstacle_event.dart';
part 'report_obstacle_state.dart';

/// Manages the business logic for the obstacle reporting feature.
///
/// Handles user input (description, type, rating, image, location),
/// interacts with device services (location, permissions, image picker),
/// and communicates with Firebase services (Auth, Supabase, Storage)
/// to submit the final report.
class ReportObstacleBloc extends Bloc<ReportObstacleEvent, ReportObstacleState> {
  /// Service for picking images from the device's gallery or camera.
  final ImagePicker _imagePicker = ImagePicker();
  /// Supabase database service instance. Used to save the report data.
  final supabase = Supabase.instance.client;

  /// Initializes the BLoC with the initial state and registers event handlers.
  ReportObstacleBloc() : super(ReportObstacleState.initial()) {
    // Register handlers for each event type
    on<LoadInitialDataRequested>(_onLoadInitialData);
    on<DescriptionChanged>(_onDescriptionChanged);
    on<ObstacleTypeSelected>(_onObstacleTypeSelected);
    on<AccessibilityRatingSelected>(_onAccessibilityRatingSelected);
    on<PickImageRequested>(_onPickImageRequested);
    on<RemoveImageRequested>(_onRemoveImageRequested);
    on<SelectLocationOnMapRequested>(_onSelectLocationOnMapRequested);
    on<LocationUpdated>(_onLocationUpdated);
    on<SubmitReportRequested>(_onSubmitReportRequested);
    on<ErrorHandler>(_onErrorHandler); // Changed name in Event file, adjust if needed
  }


  /// Handles the [LoadInitialDataRequested] event.
  ///
  /// Attempts to get the user's current location automatically upon screen load.
  /// Requests location permission, fetches coordinates, converts them to an address (geocoding),
  /// and updates the state with the location details or an error message.
  Future<void> _onLoadInitialData(LoadInitialDataRequested event, Emitter<ReportObstacleState> emit) async {
    // Set loading state and clear any previous location data
    emit(state.copyWith(
        locationStatus: LocationStatus.loading,
        userLocationGetter: () => null, // Clear previous location string
        latitudeGetter: () => null,      // Clear previous latitude
        longitudeGetter: () => null     // Clear previous longitude
    ));
    try {
      // 1. Check and request 'location when in use' permission
      PermissionStatus locationPermission = await Permission.locationWhenInUse.request();

      // Proceed if permission is granted or limited (sufficient for foreground use)
      if (locationPermission.isGranted || locationPermission.isLimited) {
        // 2. Get current device location coordinates
        // Using high accuracy and a timeout to prevent indefinite waiting
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 15));

        // 3. Convert coordinates to a human-readable address (Geocoding)
        String locationString;
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
              position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first; // Get the most relevant placemark
            // Construct address string from placemark details
            locationString = "${place.street ?? ''} ${place.locality ?? ''}, ${place.postalCode ?? ''} ${place.country ?? ''}".trim();
            // Fallback if geocoding result is not useful (empty or just separators)
            if (locationString.isEmpty || locationString == ',') {
              locationString = "Lat: ${position.latitude.toStringAsFixed(5)}, Lon: ${position.longitude.toStringAsFixed(5)}";
            }
          } else {
            // Fallback if no placemarks are found
            locationString = "Lat: ${position.latitude.toStringAsFixed(5)}, Lon: ${position.longitude.toStringAsFixed(5)}";
          }
        } catch (e) {
          // Handle potential geocoding errors (e.g., network issues)
          print("Geocoding error: $e");
          locationString = "Lat: ${position.latitude.toStringAsFixed(5)}, Lon: ${position.longitude.toStringAsFixed(5)}"; // Fallback to coordinates
        }

        // 4. Update state with the obtained location string AND coordinates
        emit(state.copyWith(
          userLocationGetter: () => locationString, // Update location string
          latitudeGetter: () => position.latitude,  // Store latitude
          longitudeGetter: () => position.longitude,// Store longitude
          locationStatus: LocationStatus.loaded,    // Set status to loaded
        ));
      } else {
        // User denied the location permission
        emit(state.copyWith(
          locationStatus: LocationStatus.error,
          errorMessageGetter: () => 'Location permission is required.', // Error message
        ));
      }
    } on TimeoutException catch (_) {
      // Handle timeout error during location fetching
      emit(state.copyWith(
          locationStatus: LocationStatus.error,
          errorMessageGetter: () => 'Could not get location in time.'));
    } catch (e) {
      // Handle other potential errors (e.g., GPS disabled, platform exceptions)
      print("Error getting location: $e");
      emit(state.copyWith(
        locationStatus: LocationStatus.error,
        errorMessageGetter: () => 'Could not get location: ${e.toString()}',
      ));
    }
  }

  /// Handles the [DescriptionChanged] event.
  /// Updates the description field in the state with the new value from the event.
  void _onDescriptionChanged(DescriptionChanged event, Emitter<ReportObstacleState> emit) {
    emit(state.copyWith(description: event.description));
  }

  /// Handles the [ObstacleTypeSelected] event.
  /// Updates the selected obstacle type in the state.
  void _onObstacleTypeSelected(ObstacleTypeSelected event, Emitter<ReportObstacleState> emit) {
    emit(state.copyWith(selectedObstacleType: event.type));
  }

  /// Handles the [AccessibilityRatingSelected] event.
  /// Updates the selected accessibility rating in the state.
  void _onAccessibilityRatingSelected(AccessibilityRatingSelected event, Emitter<ReportObstacleState> emit) {
    emit(state.copyWith(accessibilityRating: event.rating));
  }

  /// Handles the [PickImageRequested] event.
  ///
  /// Requests necessary permissions (camera or photos/storage) based on the source.
  /// Uses [ImagePicker] to let the user select an image.
  /// Updates the state with the picked image file or an error message.
  Future<void> _onPickImageRequested(PickImageRequested event, Emitter<ReportObstacleState> emit) async {
    // Determine the required permission based on the image source
    Permission? permission;
    if (event.source == ImageSource.camera) {
      permission = Permission.camera;
    } else { // ImageSource.gallery
      // Use Photos permission for newer Android (API 33+) and iOS
      permission = Permission.photos;
      // Handle older Android versions that require Storage permission
      if (Platform.isAndroid) {
        try {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          final sdkInt = androidInfo.version.sdkInt;
          print("Android SDK Version: $sdkInt"); // Debug log
          if (sdkInt < 33) {
            permission = Permission.storage; // Request storage for older Android
            print("Android SDK < 33 detected. Requesting Permission.storage instead of Photos."); // Debug log
          } else {
            print("Android SDK >= 33. Using Permission.photos."); // Debug log
          }
        } catch (e) {
          print("Error getting Android device info: $e. Proceeding with Permission.photos."); // Debug log
          // Fallback to photos permission if device info fails
          permission = Permission.photos;
        }
      }
    }

    // Request the determined permission
    PermissionStatus status = await permission.request();
    print("--- _onPickImageRequested started for source: ${event.source} ---"); // DEBUG
    // Proceed if permission is granted or limited (e.g., iOS limited photo access)
    if (status.isGranted || status.isLimited) {
      print("Permission granted. Trying to pick image..."); // DEBUG
      try {
        // Use ImagePicker to pick an image from the specified source
        final pickedFile = await _imagePicker.pickImage(source: event.source);

        if (pickedFile != null) {
          // If an image was successfully picked, update the state
          print("Image picked successfully. Path: ${pickedFile.path}"); // DEBUG
          emit(state.copyWith(
              pickedImageGetter: () => File(pickedFile.path), // Store the File object
              errorMessageGetter: () => null // Clear any previous image-related error
          ));
        } else {
          // User canceled the image picker
          print("User canceled image picking"); // Debug log
          emit(state.copyWith(errorMessageGetter: () => null)); // Ensure no error message persists
        }
      } catch (e) {
        // Handle errors during image picking
        print("Error picking image: $e"); // Debug log
        emit(state.copyWith(
            errorMessageGetter: () => 'Error picking image: ${e.toString()}'));
      }
    } else {
      // User denied the required permission
      print("Permission denied for ${event.source}"); // Debug log
      emit(state.copyWith(
          errorMessageGetter: () => 'Permission required for ${event.source == ImageSource.camera ? "camera" : "gallery"}.'));
      // Consider suggesting opening app settings
      // openAppSettings();
    }
  }

  /// Handles the [RemoveImageRequested] event.
  /// Clears the currently selected image from the state.
  void _onRemoveImageRequested(RemoveImageRequested event, Emitter<ReportObstacleState> emit) {
    emit(state.copyWith(
        pickedImageGetter: () => null, // Set pickedImage to null
        errorMessageGetter: () => null // Clear any potential image error
    ));
  }

  /// Handles the [SelectLocationOnMapRequested] event.
  ///
  /// This method should trigger navigation to a map screen where the user
  /// can pinpoint a location. The map screen should return the selected
  /// location details (address string, latitude, longitude).
  /// **Note:** The actual navigation logic needs to be implemented in the UI layer
  /// listening to state changes. This handler currently simulates the process.
  Future<void> _onSelectLocationOnMapRequested(SelectLocationOnMapRequested event, Emitter<ReportObstacleState> emit) async {
    // ---- TODO: Implement Navigation Logic to Map Screen in UI Layer ----
    // This typically involves:
    // 1. Emitting a specific state change that the UI listens for.
    // 2. The UI listener triggers navigation (e.g., Navigator.push).
    // 3. The map screen returns the selected location data.
    // 4. The UI listener adds a LocationUpdated event with the returned data.

    // Temporary simulation for demonstration purposes:
    print("⚠️ TODO: Navigate to Map Selection Screen and await result (address, lat, lon).");
    // Indicate loading while waiting for map selection (simulated)
    emit(state.copyWith(
        locationStatus: LocationStatus.loading
    ));
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate user interaction time

    // Simulate receiving data back from the map screen
    const simulatedLocationString = "Location from Map (Simulation)";
    const simulatedLat = 37.9715; // Example Coordinates (Athens)
    const simulatedLon = 23.7257;

    // Add the LocationUpdated event with the simulated data
    add(const LocationUpdated(simulatedLocationString, simulatedLat, simulatedLon));
  }

  /// Handles the [LocationUpdated] event.
  /// Updates the location details (string, latitude, longitude) and status in the state.
  /// This is typically called after automatic location fetching or manual map selection.
  void _onLocationUpdated(LocationUpdated event, Emitter<ReportObstacleState> emit) {
    emit(state.copyWith(
        userLocationGetter: () => event.locationString, // Update location string
        latitudeGetter: () => event.latitude,         // Update latitude
        longitudeGetter: () => event.longitude,       // Update longitude
        locationStatus: LocationStatus.loaded         // Set status to loaded
    ));
  }

  /// Handles the [SubmitReportRequested] event.
  ///
  /// Performs validation, uploads the image to Firebase Storage (if present),
  /// and saves the report data (including image URL, location, user details)
  /// to Firestore. Updates the state to reflect submission progress (submitting, success, failure).
  Future<void> _onSubmitReportRequested( SubmitReportRequested event, Emitter<ReportObstacleState> emit) async {

    // --- Step 1: Validate mandatory fields ---
    final user = supabase.auth.currentUser;

    // Check if user is logged in
    if (user == null) {
      // Greek message: 'You must be logged in to submit a report.'
      emit(state.copyWith(submissionStatus: SubmissionStatus.failure, errorMessageGetter: () => 'Πρέπει να είστε συνδεδεμένος για να υποβάλετε αναφορά.'));
      return;
    }
    // Check if location (specifically coordinates) is set
    if (state.latitude == null || state.longitude == null) {
      // Greek message: 'Please set a location (current or from map).'
      emit(state.copyWith(submissionStatus: SubmissionStatus.failure, errorMessageGetter: () => 'Παρακαλώ ορίστε τοποθεσία (τρέχουσα ή από χάρτη).'));
      return;
    }
    // Check if obstacle type is selected
    if (state.selectedObstacleType == null) {
      // Greek message: 'Please select an obstacle type.'
      emit(state.copyWith(submissionStatus: SubmissionStatus.failure, errorMessageGetter: () => 'Παρακαλώ επιλέξτε τύπο εμποδίου.'));
      return;
    }
    // Check if accessibility rating is selected
    if (state.accessibilityRating == null) {
      // Greek message: 'Please select an accessibility rating.'
      emit(state.copyWith(submissionStatus: SubmissionStatus.failure, errorMessageGetter: () => 'Παρακαλώ επιλέξτε βαθμό προσβασιμότητας.'));
      return;
    }
    // Check if an image is picked
    if (state.pickedImage == null) {
      // Greek message: 'Please add a photo of the obstacle.'
      emit(state.copyWith(submissionStatus: SubmissionStatus.failure, errorMessageGetter: () => 'Παρακαλώ προσθέστε μια φωτογραφία του εμποδίου.'));
      return;
    }

    // If validation passes, set state to submitting and clear previous errors
    emit(state.copyWith(
        submissionStatus: SubmissionStatus.submitting,
        errorMessageGetter: () => null
    ));

    String? imageUrl; // Variable to store the uploaded image URL

    try {
      // --- Step 2: Upload image to Supabase Storage ---
      final imageFile = state.pickedImage;
      // Check if an image file exists and the file path is valid
      if (imageFile != null && imageFile.existsSync()) {
        // Create a unique file name using timestamp
        final String imageId = DateTime.now().millisecondsSinceEpoch.toString();
        // Define the storage path (using user ID for organization)
        final String storagePath = '${user.id}/$imageId.jpg';
        // Get a reference to the storage location
        final storageResponse = await supabase.storage
            .from('report-images')
            .upload(storagePath, imageFile);
        if (storageResponse.isEmpty) {
          throw Exception("Αποτυχία αποθήκευσης εικόνας.");
        }
        // Start the upload task
        ///signed url for the image, with duration of 1 hour
        final signedUrlResponse = await supabase.storage
            .from('report-images')
            .createSignedUrl(storagePath, 3600);
        imageUrl = signedUrlResponse ;
        print("Image uploaded successfully: $imageUrl"); // Debug log
      } else {
        // This case should theoretically not be reached due to validation, but good to handle.
        print("Image file is null or does not exist, skipping upload.");
      }

      // --- Step 3: Prepare data entry for Supabase ---
      // Create a map containing all the report data
      final Map<String, dynamic> reportData = {
        'userid': user.id, // ID of the user submitting the report
        'useremail': user.email, // Email of the user
        'locationdescription': state.userLocation ?? "Δεν δόθηκε περιγραφή", // Location string or default Greek message: 'No description provided'
        'latitude': state.latitude,
        'longitude': state.longitude, // Location coordinates
        'obstacletype': state.selectedObstacleType!, // Selected obstacle type
        'accessibility': state.accessibilityRating!, // Selected accessibility rating
        'description': state.description.isNotEmpty ? state.description : null, // User's description (null if empty)
        'imageurl': imageUrl, // URL of the uploaded image (null if upload failed or no image)
        'timestamp': DateTime.now().toIso8601String(), // Server-side timestamp for creation time
        'needsupdate': true, // Backend checks if update is needed
      };

      // --- Step 4: Store data in Supabase ---
      print("Saving report data to Supabase..."); // Debug log
      // Add the report data as a new document in the 'reports' collection
      await supabase.from('reports').insert(reportData);

      print("Report saved successfully!"); // Debug log
      // Set state to success
      emit(state.copyWith(
        submissionStatus: SubmissionStatus.success,
        // Optionally clear form fields after successful submission:
        // description: '',
        // pickedImageGetter: () => null,
        // selectedObstacleType: null, // Need ValueGetter if clearing nullable fields
        // accessibilityRating: null, // Need ValueGetter if clearing nullable fields
      ));
      // Reset status to initial after a short delay (allows UI to show success message)
      await Future.delayed(const Duration(seconds: 1));
      emit(state.copyWith(submissionStatus: SubmissionStatus.initial));


    } on TimeoutException catch (_) {
      // Handle timeout errors during image upload or Supabase save
      // Greek message: 'The action took too long to complete (timeout).'
      emit(state.copyWith(submissionStatus: SubmissionStatus.failure, errorMessageGetter: () => 'Η ενέργεια άργησε να ολοκληρωθεί (timeout).'));
    } catch (e) {
      // Handle any other unexpected errors during the submission process
      print("Error submitting report: $e"); // Debug log
      emit(state.copyWith(
        submissionStatus: SubmissionStatus.failure,
        // Greek message: 'An error occurred: '
        errorMessageGetter: () => 'Παρουσιάστηκε ένα σφάλμα: ${e.toString()}',
      ));
    }
  }

  /// Handles the [ErrorHandler] event (or potentially [ErrorHandled] if renamed).
  /// Resets the submission status, typically used to clear error states manually
  /// or after an error message has been shown to the user.
  void _onErrorHandler(ErrorHandler event, Emitter<ReportObstacleState> emit) {
    // Reset submission status, often used to allow user to retry or dismiss error
    emit(state.copyWith(submissionStatus: SubmissionStatus.initial));
  }
}