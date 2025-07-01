import 'package:access/models/mapbox_feature.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

part 'favourites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {

  /// Firebase Auth instance for current user info.
  final FirebaseAuth _auth = FirebaseAuth.instance;
  /// Firestore instance for reading/writing favorites data.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FavoritesCubit() : super(FavoritesInitial()) {
    loadFavorites(); // Load favorites right when Cubit starts
  }

  /// Loads user's favorite places from Firestore.
  /// Emits loading state, then loaded or error.
  void loadFavorites() async {
    final currentUser = _auth.currentUser;
    emit(FavoritesLoading());
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser?.uid)
          .collection('favorites')
          .get();

      // Map doc IDs to their data
      final favs = {
        for (var doc in snapshot.docs)
          doc.id: doc.data()
      };

      emit(FavoritesLoaded(favs));
    } catch (e) {
      emit(FavoritesError(e.toString()));
    }
  }

  /// Toggles favorite status of a feature:
  /// - If already favorite, deletes it from Firestore and local map
  /// - If not favorite, adds it in Firestore and local map
  void toggleFavorite({required feature}) async {
    if (state is! FavoritesLoaded) return;

    // Copy current favorites map to update
    final current = Map<String, dynamic>.from((state as FavoritesLoaded).favorites);

    final currentUser = _auth.currentUser;
    final ref = _firestore
        .collection('users')
        .doc(currentUser?.uid)
        .collection('favorites')
        .doc(feature.id);

    if (current.containsKey(feature.id)) {
      await ref.delete();
      current.remove(feature.id);
    } else {
      await ref.set({
        'name': feature.name,
        'location': {'lat': feature.latitude, 'lng': feature.longitude},
      });
      current[feature.id] = {
        'name': feature.name,
        'location': {'lat': feature.latitude, 'lng': feature.longitude},
      };
    }
    emit(FavoritesLoaded(current));
  }

  /// Checks if a place is marked as favorite.
  bool isFavorite(String placeId) {
    if (state is FavoritesLoaded) {
      return (state as FavoritesLoaded).favorites.containsKey(placeId);
    }
    return false;
  }
}
