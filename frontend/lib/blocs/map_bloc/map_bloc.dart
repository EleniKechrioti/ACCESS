// Core Dart libraries
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// Third-party packages
import 'package:http/http.dart' as http;
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Internal models and utilities
import '../../models/mapbox_feature.dart';
import '../../models/navigation_step.dart';
import '../../services/map_service.dart';
import '../../utils/nearest_step.dart';
import '../../utils/point_annotation_click_listener.dart';

// Bloc-specific imports (split into parts for clarity)
part 'map_event.dart';
part 'map_state.dart';
part 'extensions/tracking_logic.dart';
part 'extensions/zoom_controls.dart';
part 'extensions/navigation_logic.dart';
part 'extensions/display_routes.dart';
part 'extensions/annotation_logic.dart';
part 'extensions/camera_controls.dart';
part 'extensions/rating_routes.dart';
part 'extensions/little_actions.dart';

/// Bloc responsible for managing map UI state and location-based logic.
class MapBloc extends Bloc<MapEvent, MapState> {
  // Annotation managers for different marker layers
  late mapbox.PointAnnotationManager? _annotationManager;
  late mapbox.PointAnnotationManager? _categoryAnnotationManager;
  late mapbox.PointAnnotationManager? _favoritesAnnotationManager;
  late mapbox.PointAnnotationManager? _clusterAnnotationManager;

  // List of annotations created on the map
  late List<mapbox.PointAnnotation?> createdAnnotations;

  // Stream subscriptions for location & compass updates
  StreamSubscription<geolocator.Position>? _positionSubscription;
  late StreamSubscription<CompassEvent> _compassSubscription;

  // Location and Firebase services
  final geolocator.GeolocatorPlatform _geolocator = geolocator.GeolocatorPlatform.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Store events that fire before map is initialized
  List<MapEvent> pendingEvents = [];

  // Text-to-speech engine for voice guidance
  final FlutterTts flutterTts = FlutterTts();

  // Custom service abstraction layer for map logic
  final mapService = MapService();

  /// Initialize the bloc and register all event handlers
  MapBloc() : super(MapState.initial()) {
    // Permissions & map setup
    on<RequestLocationPermission>(_onRequestLocationPermission);
    on<InitializeMap>(_onInitializeMap);

    // Location handling
    on<GetCurrentLocation>(_onGetCurrentLocation);
    on<StartTrackingRequested>(_onStartTrackingRequested);
    on<StopTrackingRequested>(_onStopTrackingRequested);
    on<_LocationUpdated>(_onLocationUpdated);

    // Camera & zoom controls
    on<ZoomIn>(_onZoomIn);
    on<ZoomOut>(_onZoomOut);
    on<FlyTo>(_onFlyTo);

    // Marker & annotation logic
    on<AddMarker>(_onAddMarker);
    on<DeleteMarker>(_onDeleteMarker);
    on<AddCategoryMarkers>(_onAddCategoryMarkers);
    on<_AnnotationClickedInternal>(_onAnnotationClickedInternal);
    on<RenderFavoriteAnnotations>(_onRenderFavoriteAnnotations);
    on<ClearCategoryMarkers>(_onClearCategoryMarkers);

    // Navigation & voice
    on<StartNavigationRequested>(_onStartNavigation);
    on<StopNavigationRequested>(_onStopNavigation);
    on<ToggleVoiceInstructions>((event, emit) {
      emit(state.copyWith(isVoiceEnabled: !state.isVoiceEnabled));
    });

    // UI feedback
    on<ShowedMessage>((event, emit){
      emit(state.copyWith(lastEvent: event));
    });

    // Navigation step updates
    on<NavigationPositionUpdated>(_onNavigationPositionUpdated);

    // Route rating & saving
    on<RateAndSaveRouteRequested>(_onRateAndSaveRouteRequested);
    on<ShowRouteRatingDialogRequested>(_onShowRouteRatingDialogRequested);
    on<DisplayAlternativeRoutes>(_onDisplayAlternativeRoutes);
    on<RemoveAlternativeRoutes>(_onRemoveAlternativeRoutes);

    // Sharing & emergency actions
    on<ShareLocationRequested>(_onShareLocation);
    on<LaunchPhoneDialerRequested>(_onLaunchPhoneDialer);

    // Cluster marker logic
    on<LoadClusters>(_onLoadClusters);
    on<ClusterMarkerClicked>(_onClusterMarkerClicked);
    on<HideClusterReports>(_onHideClusterReports);
  }

  /// Request location permission using permission_handler package
  Future<void> _onRequestLocationPermission(RequestLocationPermission event, Emitter<MapState> emit) async {
    await Permission.locationWhenInUse.request();
  }

  /// Init TTS engine for Greek voice navigation
  Future<void> initTTS() async {
    await flutterTts.setLanguage("el-GR");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);
  }

  /// Initialize the map and all managers + click listeners
  Future<void> _onInitializeMap(InitializeMap event, Emitter<MapState> emit) async {
    emit(state.copyWith(mapController: event.mapController));

    // Set up annotation managers per category
    _annotationManager = await state.mapController?.annotations.createPointAnnotationManager(id: 'tapped-layer');
    _categoryAnnotationManager = await state.mapController?.annotations.createPointAnnotationManager(id: 'categories-layer');
    _favoritesAnnotationManager = await state.mapController?.annotations.createPointAnnotationManager(id: 'favorites-layer');
    _clusterAnnotationManager = await state.mapController?.annotations.createPointAnnotationManager(id: 'clusters-layer');

    // Load existing clusters
    add(LoadClusters());

    // Replay events that fired before map was ready
    for (var e in pendingEvents) {
      add(e);
    }
    pendingEvents.clear();

    // Set up click listeners for category annotations
    if (_categoryAnnotationManager != null) {
      _categoryAnnotationManager!.addOnPointAnnotationClickListener(
        PointAnnotationClickListener(
          onAnnotationClick: (mapbox.PointAnnotation annotation) {
            final String internalId = annotation.id;
            final String? mapboxId = state.annotationIdMap[internalId];
            final MapboxFeature? feature = state.featureMap[mapboxId];
            if (mapboxId != null && mapboxId.isNotEmpty) {
              add(_AnnotationClickedInternal(mapboxId, feature!));
            } else {
              print("!!! MapBloc: mapboxId not found in map or is empty for internal ID $internalId, SKIPPING event add.");
            }
          },
        ),
      );
      print("[MapBloc] Annotation click listener added.");
    }

    // Set up click listeners for cluster annotations
    _clusterAnnotationManager!.addOnPointAnnotationClickListener(
      PointAnnotationClickListener(
        onAnnotationClick: (mapbox.PointAnnotation annotation) {
          final String internalId = annotation.id;
          final int? clusterIndex = state.clusterAnnotationIdMap[internalId];

          if (clusterIndex != null && clusterIndex >= 0 && clusterIndex < state.clusters.length) {
            add(ClusterMarkerClicked(state.clusters[clusterIndex]));
          } else {
            print("!!! MapBloc: Cluster index out of bounds for annotation ${annotation.id}, SKIPPING.");
          }
        },
      ),
    );

    print("[MapBloc] Cluster annotation click listener added.");

    emit(state.copyWith(isMapReady: true));

    // Trigger location fetch and init TTS after map is ready
    add(GetCurrentLocation());
    initTTS();
  }

  /// Cancel all subscriptions before Bloc is closed to prevent memory leaks
  @override
  Future<void> close() {
    print("Closing MapBloc, cancelling subscription...");
    _positionSubscription?.cancel();
    return super.close();
  }
}
