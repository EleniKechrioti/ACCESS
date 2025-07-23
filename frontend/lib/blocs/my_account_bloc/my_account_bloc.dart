import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'my_account_event.dart';
part 'my_account_state.dart';

/// BLoC class for managing user account state and actions.
///
/// Handles:
/// - Loading the user's profile from Supabase.
/// - Updating user information (date of birth, disability type).
/// - Signing the user out.
class MyAccountBloc extends Bloc<MyAccountEvent, MyAccountState> {
  final supabase = Supabase.instance.client;

  /// Initializes the bloc with the [MyAccountInitial] state,
  /// and sets up event handlers.
  MyAccountBloc() : super(MyAccountInitial()) {
    on<LoadUserProfile>(_onLoadUserProfile);
    on<SignOutRequested>(_onSignOutRequested);
    on<UpdateUserInfo>(_onUpdateUserInfo);
  }

  /// Loads the authenticated user's profile from the 'users' table.
  ///
  /// If no user row is found, a new record is inserted automatically.
  /// Emits:
  /// - [MyAccountLoading] when starting.
  /// - [MyAccountLoaded] with user data on success.
  /// - [MyAccountError] on failure.
  Future<void> _onLoadUserProfile(
      LoadUserProfile event, Emitter<MyAccountState> emit) async {
    emit(MyAccountLoading());

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        emit(MyAccountError('User not logged in.'));
        return;
      }

      final response = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // If user row doesn't exist, insert a default one
      if (response == null) {
        await supabase.from('users').insert({
          'id': user.id,
          'email': user.email,
          'avatar_url': user.userMetadata?['avatar_url'] ?? '',
          'date_of_birth': null,
          'disability_type': null,
        });

        emit(MyAccountLoaded(
          email: user.email ?? '',
          photoUrl: '',
          dateOfBirth: null,
          disabilityType: null,
        ));
        return;
      }

      // Emit profile data
      emit(MyAccountLoaded(
        email: user.email ?? '',
        photoUrl: response['avatar_url'],
        dateOfBirth: response['date_of_birth'],
        disabilityType: response['disability_type'],
      ));
    } catch (e) {
      emit(MyAccountError('Failed to load user profile: $e'));
    }
  }

  /// Signs the current user out of Supabase Auth.
  ///
  /// Emits:
  /// - [MyAccountSignedOut] on success.
  /// - [MyAccountError] on failure.
  Future<void> _onSignOutRequested(
      SignOutRequested event, Emitter<MyAccountState> emit) async {
    try {
      await supabase.auth.signOut();
      emit(MyAccountSignedOut());
    } catch (e) {
      emit(MyAccountError('Sign out failed: $e'));
    }
  }

  /// Updates the user's additional profile information in the 'users' table.
  ///
  /// Emits:
  /// - Updated [MyAccountLoaded] state with new values.
  /// - [MyAccountError] on failure or if user is not logged in.
  Future<void> _onUpdateUserInfo(
      UpdateUserInfo event, Emitter<MyAccountState> emit) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      emit(MyAccountError('User not logged in.'));
      return;
    }

    try {
      await supabase.from('users').update({
        'date_of_birth': event.dateOfBirth,
        'disability_type': event.disabilityType,
      }).eq('id', user.id);

      if (state is MyAccountLoaded) {
        final current = state as MyAccountLoaded;

        emit(MyAccountLoaded(
          email: current.email,
          photoUrl: current.photoUrl,
          dateOfBirth: event.dateOfBirth,
          disabilityType: event.disabilityType,
        ));
      }
    } catch (e) {
      emit(MyAccountError('Failed to update user info: $e'));
    }
  }
}
