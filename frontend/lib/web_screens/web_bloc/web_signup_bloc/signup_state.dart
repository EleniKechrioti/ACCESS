part of 'signup_bloc.dart';

/// Base abstract class for all signup states.
/// Extends Equatable for value equality.
abstract class SignupState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Initial state before signup process starts.
class SignupInitial extends SignupState {}

/// State emitted when signup is in progress/loading.
class SignupLoading extends SignupState {}

/// State emitted when signup completes successfully.
class SignupSuccess extends SignupState {}

/// State emitted when signup fails.
/// Contains an error message describing the failure.
class SignupFailure extends SignupState {
  final String message;

  SignupFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
