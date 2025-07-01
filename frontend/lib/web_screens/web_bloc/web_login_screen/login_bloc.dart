import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:equatable/equatable.dart';

part 'login_event.dart';
part 'login_state.dart';

/// Bloc responsible for handling login-related events and states.
/// Uses FirebaseAuth for authentication.
/// Emits states based on the login process (initial, loading, success, failure).
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  // FirebaseAuth instance for signing in users
  final FirebaseAuth _auth;

  // Constructor allows dependency injection for easier testing
  LoginBloc({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        super(LoginInitial()) {
    // Register event handler for login requests
    on<LoginRequested>(_onLoginRequested);
  }

  // Handles the login request event
  Future<void> _onLoginRequested(LoginRequested event, Emitter<LoginState> emit) async {
    emit(LoginLoading()); // Show loading state
    try {
      // Attempt to sign in with email and password
      await _auth.signInWithEmailAndPassword(
        email: event.email.trim(),
        password: event.password,
      );
      emit(LoginSuccess()); // Emit success on successful login
    } catch (e) {
      // Emit failure state with error message on exception
      emit(LoginFailure(message: 'Αποτυχία σύνδεσης. Έλεγξε τα στοιχεία σου.'));
    }
  }
}
