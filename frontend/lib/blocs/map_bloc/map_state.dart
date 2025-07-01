part of 'map_bloc.dart';

/// Enum that represents the status of tracking functionality.
enum MapTrackingStatus { initial, loading, tracking, stopped, error }

/// The state class used by the MapBloc.
/// Holds all data required to render and manage the map UI, including navigation, tracking, clusters, and annotations.
class MapState extends Equatable {
  /// The active Mapbox controller for controlling camera, annotations, etc.
  final mapbox.MapboxMap? mapController;

  /// Current zoom level of the map.
  final double zoomLevel;

  /// The main route currently displayed (list of lat/lng pairs).
  final List<List<double>> mainRoute;

  /// Alternative route options (as raw geometry or decoded polyline).
  final List<dynamic> alternativeRoutes;

  /// Annotations shown as category-specific markers (e.g., POIs).
  final Set<mapbox.PointAnnotation> categoryAnnotations;

  /// Maps internal annotation IDs to their Mapbox IDs.
  final Map<String, String> annotationIdMap;

  /// Maps Mapbox IDs to their corresponding feature metadata.
  final Map<String, MapboxFeature> featureMap;

  // --- Navigation-specific state ---

  /// Navigation steps along the current route.
  final List<NavigationStep> routeSteps;

  /// Whether navigation mode is currently active.
  final bool isNavigating;

  /// Index of the current step in the navigation sequence.
  final int currentStepIndex;

  /// Whether voice instructions are currently enabled.
  final bool isVoiceEnabled;

  /// Whether alternative routes are being displayed.
  final bool showAlternatives;

  // --- Tracking-specific state ---

  /// Whether location tracking is currently active.
  final bool isTracking;

  /// The path of positions tracked so far.
  final List<geolocator.Position> trackedRoute;

  /// The most recent tracked position (null if not available).
  final geolocator.Position? currentTrackedPosition;

  /// The status of tracking (e.g., tracking, stopped, error).
  final MapTrackingStatus trackingStatus;

  /// Error message in case tracking fails.
  final String? errorMessage;

  /// Whether the camera should follow the user’s location.
  final bool isCameraFollowing;

  /// Whether the user is currently considered off-route during navigation.
  final bool isOffRoute;

  /// The last event that triggered a state change (used for diagnostics or feedback).
  final MapEvent? lastEvent;

  /// Whether the map has finished initializing and is ready to interact with.
  final bool isMapReady;

  // --- Cluster-related state ---

  /// List of clusters, where each cluster is a list of report maps.
  final List<List<Map<String, dynamic>>> clusters;

  /// Whether to show reports for a selected cluster.
  final bool showClusterReports;

  /// Reports for the currently selected cluster.
  final List<Map<String, dynamic>>? clusterReports;

  /// Maps annotation IDs to their corresponding index in the cluster list.
  final Map<String, int> clusterAnnotationIdMap;

  /// Constructor for MapState. Most fields have sensible defaults to allow incremental updates.
  const MapState({
    this.mapController,
    this.zoomLevel = 14.0,
    this.mainRoute = const [],
    this.alternativeRoutes = const [],
    this.categoryAnnotations = const {},
    this.annotationIdMap = const {},
    this.featureMap = const {},
    this.isTracking = false,
    this.trackedRoute = const [],
    this.currentTrackedPosition,
    this.trackingStatus = MapTrackingStatus.initial,
    this.errorMessage,
    this.routeSteps = const [],
    this.isNavigating = false,
    this.currentStepIndex = 0,
    this.isVoiceEnabled = true,
    this.showAlternatives = false,
    this.isCameraFollowing = false,
    this.isOffRoute = false,
    this.lastEvent,
    this.isMapReady = false,
    this.clusters = const [],
    this.showClusterReports = false,
    this.clusterReports,
    this.clusterAnnotationIdMap = const {},
  });

  /// Creates the default initial state.
  factory MapState.initial() => const MapState();

  /// Creates a modified copy of the current state, updating only the specified fields.
  MapState copyWith({
    mapbox.MapboxMap? mapController,
    double? zoomLevel,
    List<List<double>>? mainRoute,
    List<dynamic>? alternativeRoutes,
    Set<mapbox.PointAnnotation>? categoryAnnotations,
    Map<String, String>? annotationIdMap,
    Map<String, MapboxFeature>? featureMap,
    bool? isTracking,
    List<geolocator.Position>? trackedRoute,
    ValueGetter<geolocator.Position?>? currentTrackedPositionGetter,
    MapTrackingStatus? trackingStatus,
    ValueGetter<String?>? errorMessageGetter,
    List<NavigationStep>? routeSteps,
    bool? isNavigating,
    int? currentStepIndex,
    bool? isVoiceEnabled,
    bool? showAlternatives,
    bool? isCameraFollowing,
    bool? isOffRoute,
    MapEvent? lastEvent,
    bool? isMapReady,
    List<List<Map<String, dynamic>>>? clusters,
    bool? showClusterReports,
    List<Map<String, dynamic>>? clusterReports,
    Map<String, int>? clusterAnnotationIdMap,
  }) {
    return MapState(
      mapController: mapController ?? this.mapController,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      mainRoute: mainRoute ?? this.mainRoute,
      alternativeRoutes: alternativeRoutes ?? this.alternativeRoutes,
      categoryAnnotations: categoryAnnotations ?? this.categoryAnnotations,
      annotationIdMap: annotationIdMap ?? this.annotationIdMap,
      featureMap: featureMap ?? this.featureMap,
      isTracking: isTracking ?? this.isTracking,
      trackedRoute: trackedRoute ?? this.trackedRoute,
      currentTrackedPosition: currentTrackedPositionGetter != null
          ? currentTrackedPositionGetter()
          : this.currentTrackedPosition,
      trackingStatus: trackingStatus ?? this.trackingStatus,
      errorMessage: errorMessageGetter != null
          ? errorMessageGetter()
          : this.errorMessage,
      routeSteps: routeSteps ?? this.routeSteps,
      isNavigating: isNavigating ?? this.isNavigating,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isVoiceEnabled: isVoiceEnabled ?? this.isVoiceEnabled,
      showAlternatives: showAlternatives ?? this.showAlternatives,
      isCameraFollowing: isCameraFollowing ?? this.isCameraFollowing,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      lastEvent: lastEvent ?? this.lastEvent,
      isMapReady: isMapReady ?? this.isMapReady,
      clusters: clusters ?? this.clusters,
      showClusterReports: showClusterReports ?? this.showClusterReports,
      clusterReports: clusterReports ?? this.clusterReports,
      clusterAnnotationIdMap: clusterAnnotationIdMap ?? this.clusterAnnotationIdMap,
    );
  }

  @override
  List<Object?> get props => [
    mapController,
    zoomLevel,
    mainRoute,
    alternativeRoutes,
    categoryAnnotations,
    annotationIdMap,
    featureMap,
    isTracking,
    trackedRoute,
    currentTrackedPosition,
    trackingStatus,
    errorMessage,
    routeSteps,
    isNavigating,
    currentStepIndex,
    isVoiceEnabled,
    showAlternatives,
    isCameraFollowing,
    isOffRoute,
    lastEvent,
    isMapReady,
    clusters,
    showClusterReports,
    clusterReports,
    clusterAnnotationIdMap,
  ];
}

/// State emitted when a specific annotation (marker) is tapped.
/// This subclass allows special handling of the clicked marker via [mapboxId] and [feature].
class MapAnnotationClicked extends MapState {
  final String mapboxId;
  final MapboxFeature feature;

  MapAnnotationClicked(this.mapboxId, this.feature, MapState previousState) : super(
    mapController: previousState.mapController,
    zoomLevel: previousState.zoomLevel,
    trackedRoute: previousState.trackedRoute,
    isTracking: previousState.isTracking,
    trackingStatus: previousState.trackingStatus,
    currentTrackedPosition: previousState.currentTrackedPosition,
    categoryAnnotations: previousState.categoryAnnotations,
    annotationIdMap: previousState.annotationIdMap,
    featureMap: previousState.featureMap,
    mainRoute: previousState.mainRoute,
    alternativeRoutes: previousState.alternativeRoutes,
    errorMessage: previousState.errorMessage,
  );

  @override
  List<Object?> get props => [mapboxId, feature];
}

/// State emitted when an action (e.g., saving route, stopping nav) completes successfully.
class ActionCompleted extends MapState {}

/// State emitted when an action fails.
/// Contains a descriptive error [message] for display or logging.
class ActionFailed extends MapState {
  final String message;
  ActionFailed(this.message);
}

/// State emitted when a cluster marker is clicked.
/// Carries the reports associated with that cluster.
class ClusterAnnotationClicked extends MapState {
  final List<Map<String, dynamic>> clusterId;

  ClusterAnnotationClicked(this.clusterId, MapState previousState) : super(
    mapController: previousState.mapController,
    zoomLevel: previousState.zoomLevel,
    trackedRoute: previousState.trackedRoute,
    isTracking: previousState.isTracking,
    trackingStatus: previousState.trackingStatus,
    currentTrackedPosition: previousState.currentTrackedPosition,
    categoryAnnotations: previousState.categoryAnnotations,
    annotationIdMap: previousState.annotationIdMap,
    featureMap: previousState.featureMap,
    mainRoute: previousState.mainRoute,
    alternativeRoutes: previousState.alternativeRoutes,
    errorMessage: previousState.errorMessage,
  );

  @override
  List<Object?> get props => [clusterId];
}
