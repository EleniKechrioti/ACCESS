part of 'location_review_cubit.dart';

// Base abstract state for location comments
abstract class LocationCommentsState {}

// Initial state before loading anything
class LocationCommentsInitial extends LocationCommentsState {}

// State while comments are loading
class LocationCommentsLoading extends LocationCommentsState {}

// State when comments successfully loaded
// Holds the list of Comment objects
class LocationCommentsLoaded extends LocationCommentsState {
  final List<Comment> comments;

  LocationCommentsLoaded(this.comments);
}

// State when an error occurs during loading or adding comments
class LocationCommentsError extends LocationCommentsState {
  final String error;

  LocationCommentsError(this.error);
}
