import 'package:email_validator/email_validator.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'login_event.dart';
part 'login_state.dart';

/// The BLoC class that manages the login logic and state
class LoginBloc extends Bloc<LoginEvent, LoginState> {

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Constructor to set up event handlers
  LoginBloc() : super(const LoginState()) {
    // Handle login form submission
    on<LoginSubmitted>(_onLoginSubmitted);
    // Handle Google login submission
    on<LoginWithGoogleSubmitted>(_onLoginWithGoogleSubmitted);
  }

  /// Handles the login form submission with email and password
  Future<void> _onLoginSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    // Set the state to loading while login is in progress
    emit(state.copyWith(status: LoginStatus.loading));
    try {
      final supabase = Supabase.instance.client;
      // Attempt to sign in using email and password
      final response = await supabase.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      if (response.user == null || response.session == null) {
        emit(state.copyWith(
          status: LoginStatus.failure,
          error: 'Login failed. No user or session returned.',
        ));
        return;
      }
      // If successful, update the state to success
      emit(state.copyWith(status: LoginStatus.success));
    } catch (e) {
      // If an error occurs, update the state to failure and show error message
      emit(state.copyWith(status: LoginStatus.failure, error: e.toString()));
    }
  }

  /// Handles the Google login submission
  Future<void> _onLoginWithGoogleSubmitted(
      LoginWithGoogleSubmitted event,
      Emitter<LoginState> emit,
      ) async {
    emit(state.copyWith(status: LoginStatus.loading));

    try {
      // Step 1: Google Sign-In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        emit(state.copyWith(status: LoginStatus.initial)); // canceled
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Step 2: Sign in to Supabase with the Google tokens
      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) {
        emit(state.copyWith(
          status: LoginStatus.failure,
          error: 'Google sign-in failed.',
        ));
        return;
      }

      if (response.user != null) {
        await supabase.from('users').upsert({
          'id': response.user!.id,
          'email': response.user!.email,
          'avatar_url': response.user!.userMetadata?['avatar_url'] ?? '',
          'date_of_birth': null,
          'disability_type': null,
        });
      }

      emit(state.copyWith(status: LoginStatus.success));

    } catch (e) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        error: e.toString(),
      ));
    }
  }
}
