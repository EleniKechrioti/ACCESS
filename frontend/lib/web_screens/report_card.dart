// Import required packages and dependencies
import 'package:access/web_screens/web_bloc/web_report_card_bloc/report_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/search_bloc/search_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:access/theme/app_colors.dart';
import 'package:access/blocs/search_bloc/search_bloc.dart' as search;

/// A form widget that allows users to submit municipal project reports,
/// including location, timeframe, project type, accessibility level, and optional notes.
/// Coordinates can be pre-filled if provided.
class ReportCard extends StatefulWidget {

  // Optional coordinates to initialize the location field
  final List<double>? coordinates;
  const ReportCard({Key? key, this.coordinates}) : super(key: key);

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {

  @override
  void initState() {
    super.initState();
    selectedCoordinates = widget.coordinates;

    // If coordinates are provided, fill location field and trigger reverse geocoding
    if (widget.coordinates != null) {
      _locationController.text =
      "Συντεταγμένες: ${widget.coordinates![0].toStringAsFixed(5)}, ${widget.coordinates![1].toStringAsFixed(5)}";

      BlocProvider.of<SearchBloc>(context).add(
        search.RetrieveNameFromCoordinatesEvent(widget.coordinates![0], widget.coordinates![1]),
      );
    }
  }

  // Controllers and form state variables
  final TextEditingController _damageReportController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  List<double>? selectedCoordinates;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedProjectType;
  String? _accessibility;

  // List of project types for dropdown
  final List<String> _projectTypes = [
    'Ανακαίνιση πεζοδρομίου',
    'Αποκατάσταση οδοστρώματος',
    'Εργασίες φωτισμού',
    'Διαμόρφωση πάρκου',
    'Άλλο',
  ];

  // Accessibility levels for dropdown
  final List<String> _accessibilityType = [
    'Καθόλου Προσβάσιμο',
    'Δύσκολα Προσβάσιμο',
    'Μέτρια Προσβάσιμο',
  ];

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _damageReportController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Show date picker with custom theme
  Future<DateTime?> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
            dialogTheme: DialogTheme(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }

  // Handle picking the project start date
  Future<void> _pickStartDate() async {
    final picked = await _pickDate();
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  // Handle picking the project end date
  Future<void> _pickEndDate() async {
    final picked = await _pickDate();
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  // Submit the filled form and trigger Bloc event
  void _submitForm() {
    final location = _locationController.text.trim();

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "Άγνωστο email";
    final userId = user?.uid ?? "Άγνωστο ID";

    // Validate required fields
    if (_startDate == null || _endDate == null || _selectedProjectType == null || location.isEmpty || selectedCoordinates?[0] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Συμπλήρωσε όλα τα απαιτούμενα πεδία.")),
      );
      return;
    } else {
      // Trigger report submission through ReportBloc
      context.read<ReportBloc>().add(
        SubmitReport(
          locationDescription: _locationController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          obstacleType: _selectedProjectType!,
          description: _damageReportController.text.trim(),
          accessibility: _accessibility,
          coordinates: selectedCoordinates,
          needsUpdate: true,
          needsImprove: true,
          timestamp: DateTime.now(),
          userEmail: email,
          userId: userId,
        ),
      );
    }
  }

  // Handle different search states and UI updates
  void _handleSearchResult(BuildContext context, SearchState state) {
    if (state is SearchLoaded) {
      if (state.results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Δεν βρέθηκε τοποθεσία. Δοκίμασε ξανά.")),
        );
      }
    } else if (state is SearchError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Σφάλμα αναζήτησης: ${state.message}")),
      );
    } else if (state is CoordinatesNameLoaded) {
      // Autofill address from coordinates
      final loadedState = state as CoordinatesNameLoaded;
      _locationController.text = loadedState.address;
    } else if (state is CoordinatesLoaded) {
      // Store coordinates when selected from search
      selectedCoordinates = [state.feature.longitude, state.feature.latitude];
    }
  }

  // Handle different report submission outcomes
  void _handleReportResult(BuildContext context, ReportState state) {
    if (state is ReportSuccess) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Η αναφορά υποβλήθηκε επιτυχώς!")),
      );
    } else if (state is ReportFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Σφάλμα: ${state.error}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Report form UI wrapped in BlocListeners
    return BlocListener<SearchBloc, SearchState>(
      listener: _handleSearchResult,
      child: BlocListener<ReportBloc, ReportState>(
        listener: _handleReportResult,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Header
                Text("Αναφορά έργου δήμου:", style: theme.textTheme.titleLarge),
                const SizedBox(height: 20),

                // Location input
                const Text("Τοποθεσία έργου", style: TextStyle(fontSize:16)),
                const SizedBox(height: 6),
                TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(hintText: 'Πληκτρολόγησε διεύθυνση'),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty){
                        context.read<SearchBloc>().add(SearchQueryChanged(value));
                      }
                    }
                ),

                // Show search results
                BlocBuilder<SearchBloc, SearchState>(
                  builder: (context, state) {
                    if (state is SearchLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (state is SearchLoaded) {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.results.length,
                        itemBuilder: (context, index) {
                          final feature = state.results[index];
                          return ListTile(
                            title: Text(feature.fullAddress),
                            onTap: () {
                              _locationController.text = feature.fullAddress;
                              context.read<SearchBloc>().add(SearchQueryChanged(""));
                              context.read<SearchBloc>().add(RetrieveCoordinatesEvent(feature.id));
                            },
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 16),

                // Date range section
                const Text("Περίοδος εκτέλεσης έργου", style: TextStyle(fontSize:16)),
                const SizedBox(height: 6),
                Row(
                  children: [

                    // Start date button
                    Expanded(
                      child: OutlinedButton(
                        style: ButtonStyle(
                          side: WidgetStateProperty.resolveWith<BorderSide>((states){
                            if (states.contains(WidgetState.hovered)) {
                              return BorderSide(color: AppColors.grey, width: 1);
                            }
                            return BorderSide(color: AppColors.grey, width: 1);
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith<Color>((states){
                            if (states.contains(WidgetState.hovered)) {
                              return AppColors.primary;
                            }
                            return AppColors.blackAccent[700]!;
                          }),
                          overlayColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.1)),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        onPressed: _pickStartDate,
                        child: Text(_startDate != null
                            ? "Από: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}"
                            : "Ημερομηνία έναρξης", style: TextStyle(fontSize:14)),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // End date button
                    Expanded(
                      child: OutlinedButton(
                        style: ButtonStyle(
                          side: WidgetStateProperty.resolveWith<BorderSide>((states){
                            if (states.contains(WidgetState.hovered)) {
                              return BorderSide(color: AppColors.grey, width: 1);
                            }
                            return BorderSide(color: AppColors.grey, width: 1);
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith<Color>((states){
                            if (states.contains(WidgetState.hovered)) {
                              return AppColors.primary;
                            }
                            return AppColors.blackAccent[700]!;
                          }),
                          overlayColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.1)),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        onPressed: _pickEndDate,
                        child: Text(_endDate != null
                            ? "Έως: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}"
                            : "Ημερομηνία λήξης", style: TextStyle(fontSize:14)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Project type dropdown
                const Text("Τύπος έργου", style: TextStyle(fontSize:16)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedProjectType,
                  items: _projectTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedProjectType = value),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                const SizedBox(height: 16),

                // Optional damage description
                const Text("Αναφορά έργου (προαιρετικά)", style: TextStyle(fontSize:16)),
                const SizedBox(height: 6),
                TextField(
                  controller: _damageReportController,
                  decoration: InputDecoration(
                    hintText: "Περιγράψτε τυχόν ενέργειες",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 20),

                // Accessibility level dropdown
                const Text("Βαθμός Δυσκολίας", style: TextStyle(fontSize:16)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _accessibility,
                  items: _accessibilityType
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) => setState(() => _accessibility = value),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                const SizedBox(height: 16),

                // Submit and close buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [

                    // Close button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Κλείσιμο"),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return Colors.red;
                          }
                          return AppColors.black;
                        }),
                        textStyle: WidgetStateProperty.all(
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Submit button with loading state
                    BlocBuilder<ReportBloc, ReportState>(
                      builder: (context, state) {
                        return ElevatedButton(
                          onPressed: state is ReportLoading ? null : _submitForm,
                          child: state is ReportLoading
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Text("Υποβολή"),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
