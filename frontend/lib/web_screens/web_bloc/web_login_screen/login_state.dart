part of 'login_bloc.dart';

/// Base abstract class for all login states.
/// Extends Equatable for value equality.
abstract class LoginState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Initial state before any login action occurs.
class LoginInitial extends LoginState {}

/// State while login request is being processed.
class LoginLoading extends LoginState {}

/// State when login is successful.
class LoginSuccess extends LoginState {}

/// State when login fails, includes an error message.
class LoginFailure extends LoginState {
  final String message;

  LoginFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
