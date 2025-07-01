part of 'report_bloc.dart';

/// Base abstract class for all report states.
/// Extends Equatable for value equality.
abstract class ReportState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Initial state before any report submission has started.
class ReportInitial extends ReportState {}

/// State indicating a report submission is in progress.
class ReportLoading extends ReportState {}

/// State indicating a report was successfully submitted.
class ReportSuccess extends ReportState {}

/// State indicating an error occurred during report submission.
/// Contains the error message.
class ReportFailure extends ReportState {
  final String error;

  ReportFailure(this.error);

  @override
  List<Object?> get props => [error];
}
