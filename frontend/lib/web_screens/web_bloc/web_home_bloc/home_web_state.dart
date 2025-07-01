part of 'home_web_bloc.dart';

/// State class for HomeWebBloc.
/// Tracks whether the report dialog is currently open or closed.
/// Uses Equatable to enable efficient state comparisons.
class HomeWebState extends Equatable {
  // Flag indicating if the report dialog is open
  final bool isReportDialogOpen;

  const HomeWebState({required this.isReportDialogOpen});

  // Returns a copy of this state with optional new values
  HomeWebState copyWith({bool? isReportDialogOpen}) {
    return HomeWebState(
      isReportDialogOpen: isReportDialogOpen ?? this.isReportDialogOpen,
    );
  }

  @override
  List<Object> get props => [isReportDialogOpen];
}
