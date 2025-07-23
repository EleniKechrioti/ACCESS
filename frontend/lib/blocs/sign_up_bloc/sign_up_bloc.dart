import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:email_validator/email_validator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main_mobile.dart';

part 'sign_up_event.dart';
part 'sign_up_state.dart';

/// Bloc responsible for handling the sign-up logic and state management
class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  /// Initializes the bloc with the initial state and sets up event handlers
  SignUpBloc() : super(const SignUpState()) {
    on<SignUpEmailChanged>(_onEmailChanged);
    on<SignUpPasswordChanged>(_onPasswordChanged);
    on<SignUpConfirmPasswordChanged>(_onConfirmPasswordChanged);
    on<SignUpSubmitted>(_onSubmitted);
    on<SignUpWithGoogleRequested>(_onGoogleSignInRequested);
    on<SignUpSnackBarShow>(_onSignUpSnackBarShow);
  }

  /// Updates the state when the email is changed
  void _onEmailChanged(SignUpEmailChanged event, Emitter<SignUpState> emit) {
    emit(state.copyWith(email: event.email));
  }

  /// Updates the state when the password is changed
  void _onPasswordChanged(SignUpPasswordChanged event, Emitter<SignUpState> emit) {
    emit(state.copyWith(password: event.password));
  }

  /// Updates the state when the confirm password is changed
  void _onConfirmPasswordChanged(SignUpConfirmPasswordChanged event, Emitter<SignUpState> emit) {
    emit(state.copyWith(confirmPassword: event.confirmPassword));
  }

  /// Handles form submission with email and password
  Future<void> _onSubmitted(SignUpSubmitted event, Emitter<SignUpState> emit) async {
    if (state.isFormValid) {
      emit(state.copyWith(status: SignUpStatus.submitting));

      try {
        final response = await supabase.auth.signUp(
          email: state.email.trim(),
          password: state.password.trim(),
        );

        if (response.user == null) {
          emit(state.copyWith(
            status: SignUpStatus.failure,
            errorMessage: 'Sign up failed. No user returned.',
          ));
          return;
        }

        // If no error, proceed with success
        final user = response.user;
        await Supabase.instance.client.from('users').insert({
          'id': user!.id,
          'email': state.email.trim(),
          'avatar_url': '', // or some default URL
          'date_of_birth': null,
          'disability_type': null,
        });
        emit(state.copyWith(status: SignUpStatus.success));
      } catch (e) {
        emit(state.copyWith(
          status: SignUpStatus.failure,
          errorMessage: mapSupabaseSignUpError(e.toString()),
        ));
      }
    }
  }

  /// Handles Google sign-in flow
  Future<void> _onGoogleSignInRequested(
      SignUpWithGoogleRequested event,
      Emitter<SignUpState> emit,
      ) async {
    emit(state.copyWith(status: SignUpStatus.submitting));

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        emit(state.copyWith(status: SignUpStatus.initial)); // cancelled
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) {
        emit(state.copyWith(
          status: SignUpStatus.failure,
          errorMessage: 'Google sign-in failed.',
        ));
        return;
      }

      // Insert user into "users" table if needed
      await Supabase.instance.client.from('users').upsert({
        'id': response.user!.id,
        'email': response.user!.email,
        'avatar_url': response.user!.userMetadata?['avatar_url'] ?? '',
        'date_of_birth': null,
        'disability_type': null,
      });

      emit(state.copyWith(status: SignUpStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: SignUpStatus.failure,
        errorMessage: mapSupabaseSignUpError(e.toString()),
      ));
    }
  }

  /// Resets the sign-up status back to initial, used after showing a snackbar
  void _onSignUpSnackBarShow(SignUpSnackBarShow event, Emitter<SignUpState> emit) async {
    emit(state.copyWith(status: SignUpStatus.initial));
  }

  /// Maps Supabase error messages to user-friendly messages
  String mapSupabaseSignUpError(String errorMessage) {
    print(errorMessage);
    if (errorMessage.contains('password')) {
      return 'The password provided is too weak.';
    } else if (errorMessage.contains('already registered') ||
        errorMessage.contains('User already registered')) {
      return 'The account already exists for that email.';
    } else if (errorMessage.contains('email')) {
      return 'The email provided is not valid.';
    } else {
      return 'An error occurred during sign up.';
    }
  }
}
