import 'package:access/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/navigation_step.dart';
import '../blocs/map_bloc/map_bloc.dart';

/// A horizontally scrolling card widget displaying a list of navigation steps.
/// Highlights the current step and automatically scrolls to it when changed.
class DirectionsCard extends StatefulWidget {
  /// The list of navigation steps to display.
  final List<NavigationStep> steps;

  const DirectionsCard({Key? key, required this.steps}) : super(key: key);

  @override
  _DirectionsCardState createState() => _DirectionsCardState();
}

class _DirectionsCardState extends State<DirectionsCard> {
  /// Controller to programmatically scroll the horizontal list.
  late ScrollController _scrollController;

  /// Index of the current active navigation step.
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the horizontal list so that the current step is visible.
  void _scrollToCurrentStep() {
    final double offset = _currentStep * (250 + 16);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MapBloc, MapState>(
      listenWhen: (previous, current) =>
      previous.currentStepIndex != current.currentStepIndex,
      listener: (context, state) {
        setState(() {
          _currentStep = state.currentStepIndex;
        });
        _scrollToCurrentStep();
      },
      child: SizedBox(
        height: 150,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: widget.steps.length,
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            final isActive = index == _currentStep;
            final step = widget.steps[index];
            return Container(
              width: 250,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                isActive ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isActive
                    ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getDirectionIcon(step.instruction),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        step.instruction,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Returns an icon widget representing the direction indicated in the instruction text.
  /// Checks for Greek direction keywords and defaults to a generic directions icon.
  Widget getDirectionIcon(String instruction) {
    final instr = instruction.toLowerCase();
    if (instr.contains('δεξιά') || instr.contains('δεξια')) {
      return const Icon(Icons.arrow_circle_right_outlined,
          size: 32, color: Colors.orange);
    } else if (instr.contains('αριστερά') || instr.contains('αριστερα')) {
      return const Icon(Icons.arrow_circle_left_outlined,
          size: 32, color: Colors.orange);
    } else if (instr.contains('ευθεία') || instr.contains('ευθεια')) {
      return const Icon(Icons.arrow_circle_up_outlined,
          size: 32, color: Colors.orange);
    } else if (instr.contains('πίσω') || instr.contains('πισω')) {
      return const Icon(Icons.arrow_circle_down_outlined,
          size: 32, color: Colors.orange);
    }
    return const Icon(Icons.directions, size: 32, color: Colors.white);
  }
}
