import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'report_event.dart';
part 'report_state.dart';

/// Bloc to manage submitting municipal reports to Firestore.
/// Handles submission flow with loading, success, and failure states.
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc() : super(ReportInitial()) {
    // Registers event handler for submitting a report
    on<SubmitReport>(_onSubmitReport);
  }

  /// Handles the SubmitReport event.
  /// Adds a new document to Firestore with all report details.
  Future<void> _onSubmitReport(SubmitReport event,
      Emitter<ReportState> emit) async {
    emit(ReportLoading()); // Emit loading state while submitting

    try {
      // Add the report data to Firestore collection 'municipal_reports'
      await FirebaseFirestore.instance.collection('municipal_reports').add({
        'accessibility': event.accessibility,
        'coordinates': GeoPoint(event.coordinates![0], event.coordinates![1]),
        'locationDescription': event.locationDescription,
        'startDate': event.startDate,
        'endDate': event.endDate,
        'needsUpdate': event.needsUpdate,
        'obstacleType': event.obstacleType,
        'needsImprove': event.needsImprove,
        'timestamp': Timestamp.fromDate(event.timestamp),
        'userEmail': event.userEmail,
        'userId': event.userId,
        'description': event.description,
      });

      emit(ReportSuccess()); // Emit success state on completion
    } catch (e) {
      emit(ReportFailure(e.toString())); // Emit failure state with error message
    }
  }
}

/// State representing that a human-readable address from coordinates has been loaded.
class CoordinatesNameLoaded extends ReportState {
  final String address;

  CoordinatesNameLoaded(this.address);
}
