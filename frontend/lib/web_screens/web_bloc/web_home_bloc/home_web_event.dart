part of 'home_web_bloc.dart';

/// Base abstract class for all HomeWebBloc events.
/// Extends Equatable for easy comparison in Bloc.
///
/// Events represent user actions or UI triggers like opening dialogs or navigation.
abstract class HomeWebEvent extends Equatable {
  const HomeWebEvent();

  @override
  List<Object> get props => [];
}

/// Event to trigger opening the user profile view.
class OpenProfile extends HomeWebEvent {}

/// Event to open the report dialog on the home screen.
class OpenReportDialog extends HomeWebEvent {}

/// Event to close the report dialog on the home screen.
class CloseReportDialog extends HomeWebEvent {}

/// Event to open the settings view or panel.
class OpenSettings extends HomeWebEvent {}
