import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:access/services/search_service.dart';
import '../../models/mapbox_feature.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:diacritic/diacritic.dart';

part 'search_event.dart';
part 'search_state.dart';

/// Bloc that handles search functionality for querying locations, coordinates, and filtering by category.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  /// The service responsible for performing search operations.
  final SearchService searchService;

  /// Creates a [SearchBloc] with a required [SearchService].
  SearchBloc({required this.searchService}) : super(SearchInitial()) {
    /// Event handlers registration
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<RetrieveCoordinatesEvent>(_onRetrieveCoordinates);
    on<RetrieveNameFromCoordinatesEvent>(_onRetrieveNameFromCoordinates);
    on<FilterByCategoryPressed>(_onFilterByCategoryPressed);
    on<SearchForPoiClicked>(_onSearchForPoiClicked);
  }

  /// Handles [SearchQueryChanged] by performing a text-based location search.
  ///
  /// Emits:
  /// - [SearchLoading] while the search is being performed.
  /// - [SearchLoaded] with results if successful.
  /// - [SearchError] if an exception occurs.
  Future<void> _onSearchQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit,) async {
    final query = event.query.trim();

    // If query is empty, reset to initial state
    if (query.isEmpty) {
      emit(SearchInitial());
      return;
    }

    emit(SearchLoading());

    try {
      final results = await searchService.search(query);
      emit(SearchLoaded(results));
    } catch (e) {
      emit(SearchError('An error occurred while searching: ${e.toString()}'));
    }
  }

  /// Handles [RetrieveCoordinatesEvent] by retrieving full location data based on a Mapbox ID.
  ///
  /// Emits:
  /// - [CoordinatesLoading] before the request.
  /// - [CoordinatesLoaded] with the retrieved feature.
  /// - [CoordinatesError] if an exception occurs.
  Future<void> _onRetrieveCoordinates(RetrieveCoordinatesEvent event, Emitter<SearchState> emit,) async {
    emit(CoordinatesLoading());

    try {
      final feature = await searchService.retrieveCoordinates(event.mapboxId);
      emit(CoordinatesLoaded(feature));
    } catch (e) {
      emit(CoordinatesError('Failed to retrieve coordinates: ${e.toString()}'));
    }
  }

  /// Handles [RetrieveNameFromCoordinatesEvent] by reverse geocoding coordinates into a name.
  ///
  /// Emits:
  /// - [NameLoading] while the name is being retrieved.
  /// - [NameLoaded] with the feature containing the name.
  /// - [NameError] if an error occurs.
  Future<void> _onRetrieveNameFromCoordinates(RetrieveNameFromCoordinatesEvent event, Emitter<SearchState> emit,) async {
    emit(NameLoading());

    try {
      final feature = await searchService.retrieveNameFromCoordinates(
        event.latitude,
        event.longitude,
      );
      emit(NameLoaded(feature));
    } catch (e) {
      emit(NameError('Failed to retrieve coordinates: ${e.toString()}'));
    }
  }

  /// Handles [FilterByCategoryPressed] by querying features based on a selected category.
  ///
  /// Emits:
  /// - [SearchLoading] while searching.
  /// - [CategoryResultsLoaded] if successful.
  /// - [SearchError] if an error occurs.
  Future<void> _onFilterByCategoryPressed(FilterByCategoryPressed event, Emitter<SearchState> emit,) async {

    try {
      final results = await searchService.searchByCategory(event.category, event.bbox);
      emit(CategoryResultsLoaded(results));
    } catch (e) {
      emit(SearchError('An error occurred while filtering by category: ${e.toString()}'));
    }
  }

  Future<void> _onSearchForPoiClicked(SearchForPoiClicked event, Emitter<SearchState> emit,) async {

    final properties = event.properties;
    print(properties['name']);
    final q = '${event.coordinates[0]},${event.coordinates[1]}';
    try {
      final results = await searchService.searchForPoi(properties['name'], q, properties['iso_3166_1'], event.bbox, properties['category_en'].toLowerCase());
      for (final feature in results) {

        if (areSimilar(properties['name'], feature.name)){
          final f = await searchService.retrieveCoordinates(feature.id);
          emit(PoiFound(f, feature));
        }
      }
    } catch (e) {
      emit(SearchError('An error occurred while filtering by category: ${e.toString()}'));
    }
  }

  bool areSimilar(String a, String b, {int threshold = 85}) {
    final normA = removeDiacritics(a).toLowerCase();
    final normB = removeDiacritics(b).toLowerCase();

    final ratio = partialRatio(normA, normB); // ή tokenSortRatio, tokenSetRatio
    return ratio >= threshold;
  }

}