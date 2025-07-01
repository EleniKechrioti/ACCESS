import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'home_web_event.dart';
part 'home_web_state.dart';

/// Bloc to manage UI state for the web home screen.
/// Controls opening and closing of the report dialog,
/// and includes placeholders for profile and settings navigation events.
class HomeWebBloc extends Bloc<HomeWebEvent, HomeWebState> {
  HomeWebBloc() : super(const HomeWebState(isReportDialogOpen: false)) {
    // Event handler to open the report dialog
    on<OpenReportDialog>((event, emit) {
      emit(state.copyWith(isReportDialogOpen: true));
    });

    // Event handler to close the report dialog
    on<CloseReportDialog>((event, emit) {
      emit(state.copyWith(isReportDialogOpen: false));
    });

    // Placeholder event handler for opening profile
    on<OpenProfile>((event, emit) {
      // Handle profile open logic if needed
    });

    // Placeholder event handler for opening settings
    on<OpenSettings>((event, emit) {
      // Handle settings open logic if needed
    });
  }
}
