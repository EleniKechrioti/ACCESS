part of 'favourites_cubit.dart';

@immutable
abstract class FavoritesState {}

// Initial state before anything happens
class FavoritesInitial extends FavoritesState {}

// State when favorites are being loaded from Firestore
class FavoritesLoading extends FavoritesState {}

// State when favorites have successfully loaded
// Contains a map of favorite place IDs to their data
class FavoritesLoaded extends FavoritesState {
  final Map<String, dynamic> favorites;

  FavoritesLoaded(this.favorites);
}

// State when an error occurs while loading or updating favorites
class FavoritesError extends FavoritesState {
  final String message;

  FavoritesError(this.message);
}
