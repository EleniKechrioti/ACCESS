import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;

part 'signup_event.dart';
part 'signup_state.dart';

class SignupBloc extends Bloc<SignupEvent, SignupState> {
  final FirebaseAuth _auth;

  SignupBloc({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        super(SignupInitial()) {
    on<SignupRequested>(_onSignupRequested);
  }


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

      html.window.localStorage['authToken'] = 'user_authenticated';
      emit(SignupSuccess());
    } catch (e) {
      emit(SignupFailure(message: 'Αποτυχία εγγραφής: ${e.toString()}'));
    }
  }
}
