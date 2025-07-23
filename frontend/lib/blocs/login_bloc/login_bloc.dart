import 'package:email_validator/email_validator.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'login_event.dart';
part 'login_state.dart';

/// The BLoC class that manages the login logic and state
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  // Firebase authentication instance
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

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
  Future<void> _onLoginWithGoogleSubmitted(LoginWithGoogleSubmitted event, Emitter<LoginState> emit) async {
    // Set the state to loading while Google login is in progress
    emit(state.copyWith(status: LoginStatus.loading));
    try {
      // Attempt to sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If the user cancels the Google sign-in, revert the state to initial
      if (googleUser == null) {
        emit(state.copyWith(status: LoginStatus.initial)); // canceled
        return;
      }

      // Retrieve the authentication credentials from Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Use the Google credentials to authenticate with Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credentials
      await _firebaseAuth.signInWithCredential(credential);
      // If successful, update the state to success
      emit(state.copyWith(status: LoginStatus.success));
    } catch (e) {
      // If an error occurs, update the state to failure and show error message
      emit(state.copyWith(status: LoginStatus.failure, error: e.toString()));
    }
  }
}
