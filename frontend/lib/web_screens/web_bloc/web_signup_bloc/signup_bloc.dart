import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;

part 'signup_event.dart';
part 'signup_state.dart';

/// Bloc to handle the signup flow for municipality users.
/// Manages user creation in Firebase Auth and stores additional user data in Firestore.
/// Also handles basic password confirmation check.
class SignupBloc extends Bloc<SignupEvent, SignupState> {
  final FirebaseAuth _auth;

  SignupBloc({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        super(SignupInitial()) {
    // Register handler for signup requests
    on<SignupRequested>(_onSignupRequested);
  }

  /// Handles SignupRequested event:
  /// - Checks if passwords match, else emits failure
  /// - Creates Firebase user account
  /// - Stores municipality info in Firestore
  /// - Saves auth token in localStorage for web session
  Future<void> _onSignupRequested(SignupRequested event, Emitter<SignupState> emit) async {
    if (event.password != event.confirmPassword) {
      emit(SignupFailure(message: 'Οι κωδικοί δεν ταιριάζουν'));
      return;
    }
    emit(SignupLoading());
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: event.email.trim(),
        password: event.password,
      );

      await FirebaseFirestore.instance
          .collection('municipality')
          .doc(userCredential.user!.uid)
          .set({
        'email': event.email.trim(),
        'dimosName': event.dimosName,
        'dimosTK': event.dimosTK,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user!.uid,
      });

      // Save auth token in browser localStorage to keep user logged in
      html.window.localStorage['authToken'] = 'user_authenticated';
      emit(SignupSuccess());
    } catch (e) {
      emit(SignupFailure(message: 'Αποτυχία εγγραφής: ${e.toString()}'));
    }
  }
}
