part of 'login_bloc.dart';

/// Abstract base class for all login-related events.
/// Extends Equatable for value equality.
abstract class LoginEvent extends Equatable {
  @override
  List<Object> get props => [];
}

/// Event triggered when a login is requested with email and password.
class LoginRequested extends LoginEvent {
  final String email;
  final String password;

  LoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}
