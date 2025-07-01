import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/comment.dart';
part 'location_review_state.dart';

class LocationCommentsCubit extends Cubit<LocationCommentsState> {

  final _firestore = FirebaseFirestore.instance;

  LocationCommentsCubit(): super(LocationCommentsInitial());

  /// Fetches comments for a given location from Firestore, ordered newest first.
  /// Emits loading, loaded, or error states accordingly.
  Future<void> fetchComments(String locationId) async {
    emit(LocationCommentsLoading());
    try {
      final snapshot = await _firestore
          .collection('locations')
          .doc(locationId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      final comments = snapshot.docs
          .map((doc) => Comment.fromMap(doc.data(), doc.id))
          .toList();

      emit(LocationCommentsLoaded(comments));
    } catch (e) {
      emit(LocationCommentsError(e.toString()));
    }
  }

  /// Adds a new comment to Firestore under the specified location.
  /// Refreshes comments after adding.
  Future<void> addComment(String locationId, Comment comment) async {
    try {
      await _firestore
          .collection('locations')
          .doc(locationId)
          .collection('comments')
          .add(comment.toMap());
      fetchComments(locationId); // refresh the list after adding
    } catch (e) {
      emit(LocationCommentsError(e.toString()));
    }
  }
}
