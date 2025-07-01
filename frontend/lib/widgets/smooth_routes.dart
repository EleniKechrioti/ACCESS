import 'package:flutter/material.dart';

// Custom page route with a smooth slide-in transition from right to left
class SmoothPageRoute extends PageRouteBuilder {
  final Widget child; // The page/screen to show

  SmoothPageRoute({required this.child})
      : super(
    // Duration of the forward and reverse transition animations
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    // The actual page to build when this route is pushed
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );

  // Override to define the transition animation widget
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // Slide the new page in from right (offset x=1) to its normal position (offset 0)
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0), // start off-screen right
        end: Offset.zero, // end at original position
      ).animate(animation),
      child: child,
    );
  }
}