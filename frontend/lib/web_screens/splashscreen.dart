// splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:html' as html;

/// Stateless widget that handles splash screen logic on web.
/// Checks for an auth token in localStorage and redirects users
/// to the appropriate route: profile, home, or login.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve the stored authentication token from browser localStorage
    final authToken = html.window.localStorage['authToken'];
    // Get current URL path
    final currentPath = html.window.location.pathname;

    // Run redirection logic asynchronously after build
    Future.microtask(() {
      if (authToken != null) {
        // If logged in and already on profile, replace history and navigate there
        if (currentPath == '/profile') {
          html.window.history.replaceState({}, '', '/profile');
          Navigator.pushReplacementNamed(context, '/profile');
        } else {
          // Otherwise, redirect to webhome
          html.window.history.replaceState({}, '', '/webhome');
          Navigator.pushReplacementNamed(context, '/webhome');
        }
      } else {
        // If no auth token, redirect to login page
        html.window.history.replaceState({}, '', '/login');
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    // Show a loading spinner while redirection happens
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}