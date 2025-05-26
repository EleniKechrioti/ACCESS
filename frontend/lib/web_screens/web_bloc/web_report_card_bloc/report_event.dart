part of 'report_bloc.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class SubmitReport extends ReportEvent {
  final String? accessibility;
  final DateTime startDate;
  final DateTime endDate;
  final List<double>? coordinates;
  final String locationDescription;
  final bool needsUpdate;
  final bool needsImprove;
  final String obstacleType;
  final DateTime timestamp;
  final String userEmail;
  final String userId;
  final String description;

  const SubmitReport({
    required this.accessibility,
    required this.startDate,
    required this.endDate,
    required this.coordinates,
    required this.locationDescription,
    required this.needsUpdate,
    required this.needsImprove,
    required this.obstacleType,
    required this.timestamp,
    required this.userEmail,
    required this.userId,
    required this.description,
  });

  @override
  List<Object?> get props => [
    accessibility,
    startDate,
    endDate,
    coordinates,
    locationDescription,
    needsUpdate,
    needsImprove,
    obstacleType,
    timestamp,
    userEmail,
    userId,
    description,
  ];
}
