import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../blocs/map_bloc/map_bloc.dart';
import '../blocs/report_obstacle_bloc/report_obstacle_bloc.dart';
import '../blocs/search_bloc/search_bloc.dart';
import '../screens/home_screen.dart';
import '../screens/report_obstacle_screen.dart';
import '../services/search_service.dart';
import '../utils/auth_gate.dart';

/// Custom bottom navigation bar widget handling core app navigation
///
/// Provides:
/// - Home navigation
/// - Obstacle reporting (for authenticated users)
/// - Profile/auth navigation
///
/// Maintains route awareness and state management through BLoCs
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  /// Handles navigation logic between screens
  ///
  /// Parameters:
  /// - [context]: Current build context
  /// - [screen]: Target screen widget
  /// - [routeName]: Unique route identifier
  ///
  /// Features:
  /// - Prevents duplicate navigation
  /// - Automatically wraps with BLoCs
  /// - Maintains route history
  void _navigateToScreen(BuildContext context, Widget screen, String routeName) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute != routeName) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _wrapWithBlocs(routeName, screen),
          settings: RouteSettings(name: routeName),
        ),
      );
    }
  }

  /// Wraps screens with required BLoC providers
  ///
  /// Parameters:
  /// - [routeName]: Determines needed providers
  /// - [screen]: Widget to wrap
  ///
  /// Returns:
  /// MultiBlocProvider widget with:
  /// - MapBloc for home route
  /// - SearchBloc for home route
  /// - No wrapping for other routes
  Widget _wrapWithBlocs(String routeName, Widget screen) {
    switch (routeName) {
      case '/home':
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => MapBloc()..add(RequestLocationPermission())),
            BlocProvider(create: (_) => SearchBloc(searchService: SearchService())),
          ],
          child: screen,
        );
      default:
        return screen;
    }
  }

  /// Opens obstacle reporting camera dialog
  ///
  /// Parameters:
  /// - [context]: Build context for dialog display
  ///
  /// Throws:
  /// - PlatformException if camera access fails
  /// - PermissionDeniedException if user denies access
  Future<void> _openCamera(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: MediaQuery.of(dialogContext).size.height * 0.9,
            child: BlocProvider(
              create: (context) => ReportObstacleBloc(),
              child: const ReportObstacleScreen(),
            ),
          ),
        );
      },
    );
  }

  /// Builds the bottom navigation bar UI
  ///
  /// Returns:
  /// Container with:
  /// - Fixed height (55px)
  /// - Top border
  /// - Drop shadow
  /// - Row of navigation icons
  ///
  /// Handles:
  /// - Authentication state changes
  /// - Responsive layout
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, -1),
          )
        ],
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.15),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () => _navigateToScreen(context, const HomePage(), '/home'),
            icon: const Icon(Icons.home, size: 30),
          ),
          if (user != null)
            IconButton(
              onPressed: () => _openCamera(context),
              icon: const Icon(Icons.add_box_rounded, size: 30),
            ),
          IconButton(
            onPressed: () {
              final currentRoute = ModalRoute.of(context)?.settings.name;
              if (currentRoute != '/signup' && currentRoute != '/login') {
                _navigateToScreen(context, const AuthGate(), '/profile');
              }
            },
            icon: const Icon(Icons.person, size: 30),
          ),
        ],
      ),
    );
  }
}